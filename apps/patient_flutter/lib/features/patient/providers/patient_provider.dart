import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../shared/models/patient.dart';
import '../../../shared/models/card_model.dart';
import '../../../shared/models/booklet_entry.dart';
import '../../../shared/models/audit_event.dart';
import '../../../shared/models/health_journey_entry.dart';
import '../../../shared/models/notification_model.dart';
import '../../../shared/models/access_grant.dart';
import '../../../shared/models/doctor_profile.dart';
import '../../../shared/models/hospital_info.dart';
import '../../../shared/models/chat_conversation.dart';
import '../../../../core/data/response_mapper.dart';
import '../../../core/database/local_database.dart';
import '../../../core/domain/repositories/patient_repository.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_providers.dart';
import '../../auth/providers/auth_provider.dart';

/// The active patient id is persisted into the `medicard` session box as a
/// `String`. It is read through `LocalDatabase.getActivePatientId`, which
/// always opens the box with a single canonical type (`Box<String>`). Never
/// open the session box directly here — doing so with an untyped
/// `Hive.box('medicard')` races the canonical `Box<String>` open and surfaces
/// `HiveError: box "medicard" is already open and of type Box<dynamic>`.
final activePatientIdProvider = Provider<AsyncValue<String>>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return AsyncData(db.currentActivePatientId);
});

extension on LocalDatabase {
  /// Synchronous view of the active patient id for the session box, which is
  /// only ever read here from an already-open box (no re-open → no type race).
  String get currentActivePatientId {
    try {
      if (Hive.isBoxOpen(LocalDatabase.sessionBoxName)) {
        return Hive.box<String>(LocalDatabase.sessionBoxName)
                .get(LocalDatabase.activePatientIdKey, defaultValue: '') ??
            '';
      }
    } catch (_) {}
    return '';
  }
}

class PatientState {
  final String? patientId;
  final Patient? patient;
  final CardModel? card;
  final List<BookletEntry> bookletEntries;
  final List<AuditEvent> auditLogs;
  final List<NotificationModel> notifications;
  final List<HealthJourneyEntry> healthJourney;
  final List<AccessGrant> accessGrants;
  final List<DoctorProfile> doctors;
  final List<HospitalInfo> hospitals;
  final List<ChatConversation> chats;
  final List<Appointment> appointments;
  final List<PrescribedMedication> prescriptions;
  final List<BookletEntry> consultations;
  final bool loading;
  final String? error;

  const PatientState({
    this.patientId,
    this.patient,
    this.card,
    this.bookletEntries = const [],
    this.auditLogs = const [],
    this.notifications = const [],
    this.healthJourney = const [],
    this.accessGrants = const [],
    this.doctors = const [],
    this.hospitals = const [],
    this.chats = const [],
    this.appointments = const [],
    this.prescriptions = const [],
    this.consultations = const [],
    this.loading = false,
    this.error,
  });

  PatientState copyWith({
    String? patientId,
    Patient? patient,
    CardModel? card,
    List<BookletEntry>? bookletEntries,
    List<AuditEvent>? auditLogs,
    List<NotificationModel>? notifications,
    List<HealthJourneyEntry>? healthJourney,
    List<AccessGrant>? accessGrants,
    List<DoctorProfile>? doctors,
    List<HospitalInfo>? hospitals,
    List<ChatConversation>? chats,
    List<Appointment>? appointments,
    List<PrescribedMedication>? prescriptions,
    List<BookletEntry>? consultations,
    bool? loading,
    String? error,
  }) {
    return PatientState(
      patientId: patientId ?? this.patientId,
      patient: patient ?? this.patient,
      card: card ?? this.card,
      bookletEntries: bookletEntries ?? this.bookletEntries,
      auditLogs: auditLogs ?? this.auditLogs,
      notifications: notifications ?? this.notifications,
      healthJourney: healthJourney ?? this.healthJourney,
      accessGrants: accessGrants ?? this.accessGrants,
      doctors: doctors ?? this.doctors,
      hospitals: hospitals ?? this.hospitals,
      chats: chats ?? this.chats,
      appointments: appointments ?? this.appointments,
        prescriptions: prescriptions ?? this.prescriptions,
        consultations: consultations ?? this.consultations,
        loading: loading ?? this.loading,
      error: error ?? this.error,
    );
  }
}

class PatientNotifier extends Notifier<PatientState> {
  @override
  PatientState build() => const PatientState();

  PatientRepository get _repo => ref.read(patientRepositoryProvider);

  Future<void> loadPatientData(String patientId) async {
    if (patientId.isEmpty) return;
    // Set the patient id up front so Retry works even if the network fetch
    // later fails (the error path keeps this id intact).
    state = state.copyWith(patientId: patientId, loading: true, error: null);
    try {
      final results = await Future.wait([
        _repo.getPatientProfile(patientId).catchError((_) => null),
        _repo.getCard(patientId).catchError((_) => null),
        _repo.getMedicalBooklet(patientId).catchError((_) => <BookletEntry>[]),
        _repo.getAuditLog(patientId).catchError((_) => <AuditEvent>[]),
        _repo.getNotifications(patientId).catchError((_) => <NotificationModel>[]),
        _repo.getHealthJourney(patientId).catchError((_) => <HealthJourneyEntry>[]),
        _repo.getAccessGrants(patientId).catchError((_) => <AccessGrant>[]),
        _repo.getDoctors().catchError((_) => <DoctorProfile>[]),
        _repo.getHospitals().catchError((_) => <HospitalInfo>[]),
        _repo.getChats(patientId).catchError((_) => <ChatConversation>[]),
        _loadAppointments(patientId),
      ]).timeout(const Duration(seconds: 12));
      List<PrescribedMedication> prescriptions = [];
      try {
        prescriptions = (await _repo.getPrescriptions(patientId).timeout(const Duration(seconds: 6)))
            .map((e) => ResponseMapper.prescriptionFromBackend(e))
            .toList();
      } catch (_) {}
      List<BookletEntry> consultations = [];
      try {
        final records = (await _repo.getPatientMedicalRecords(patientId).timeout(const Duration(seconds: 6)))
            .map((e) => ResponseMapper.consultationToBooklet(e))
            .toList();
        consultations = records;
      } catch (_) {}
      Patient? resolvedPatient = results[0] is Patient ? results[0] as Patient? : null;
      // The backend auto-creates an empty "stub" patient when none exists, so a
      // user who reached home without completing onboarding (sign-in, or an
      // aborted registration) gets a blank profile. Materialize the real profile
      // from the auth session's known identity so the medical record + card are
      // created and the UI shows a name.
      if (resolvedPatient == null || resolvedPatient.name.isEmpty) {
        resolvedPatient = await _materializeProfile(resolvedPatient, patientId);
      }
      final resolvedPatientId = (resolvedPatient?.id.isNotEmpty ?? false)
          ? resolvedPatient!.id
          : patientId;
      // Only persist a patient id that was actually resolved from the backend
      // (or local cache). Never overwrite the active id with a fabricated one.
      if (resolvedPatient != null && resolvedPatient.id.isNotEmpty) {
        try {
          await ref.read(localDatabaseProvider).setActivePatientId(resolvedPatient.id);
        } catch (_) {}
      }
      state = state.copyWith(
        patientId: resolvedPatientId,
        patient: resolvedPatient,
        card: results[1] is CardModel ? results[1] as CardModel? : null,
        bookletEntries: results[2] is List ? results[2] as List<BookletEntry> : [],
        auditLogs: results[3] is List ? results[3] as List<AuditEvent> : [],
        notifications: results[4] is List ? results[4] as List<NotificationModel> : [],
        healthJourney: results[5] is List ? results[5] as List<HealthJourneyEntry> : [],
        accessGrants: results[6] is List ? results[6] as List<AccessGrant> : [],
        doctors: results[7] is List ? results[7] as List<DoctorProfile> : [],
        hospitals: results[8] is List ? results[8] as List<HospitalInfo> : [],
        chats: results[9] is List ? results[9] as List<ChatConversation> : [],
        appointments: results[10] is List ? results[10] as List<Appointment> : [],
        prescriptions: prescriptions,
        consultations: consultations,
        loading: false,
        error: resolvedPatient == null ? 'Impossible de charger le profil' : null,
      );
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Impossible de charger votre profil. Vérifiez votre connexion.');
    }
  }

  /// Ensures a real patient profile exists. When the backend returned a stub
  /// (no name), onboards using the auth session's known first/last name, then
  /// reloads. Falls back to showing the auth name locally if the network call
  /// fails, so the UI is never blank.
  Future<Patient?> _materializeProfile(Patient? current, String patientId) async {
    final authName = (ref.read(authProvider).patient?.name ?? '').trim();
    if (authName.isEmpty) return current;
    final parts = authName.split(' ');
    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    try {
      await ref.read(apiClientProvider).post(ApiEndpoints.patientOnboard, data: {
        'firstName': firstName,
        'lastName': lastName,
      });
      final reloaded = await _repo.getPatientProfile(patientId).catchError((_) => null);
      if (reloaded != null && reloaded.name.isNotEmpty) return reloaded;
    } catch (_) {
      // best-effort: continue to the local fallback below
    }
    final base = current ??
        Patient(
          id: patientId,
          name: '',
          dateOfBirth: '',
          nationalId: '',
          contactInfo: const ContactInfo(phone: '', email: ''),
          bloodType: '',
          emergencyContact: const EmergencyContact(name: '', relationship: '', phone: ''),
        );
    return base.copyWith(name: authName);
  }

  Future<List<Appointment>> _loadAppointments(String patientId) async {
    try {
      final list = await _repo.getAppointments(patientId);
      return list
          .map((e) => ResponseMapper.appointmentFromBackend(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> loadAppointments() async {
    final id = state.patientId;
    if (id == null || id.isEmpty) return;
    final appointments = await _loadAppointments(id);
    state = state.copyWith(appointments: appointments);
  }

  Future<void> registerPatient({
    required String name,
    required String gender,
    required String dateOfBirth,
    required String city,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final patient = await _repo.registerPatient(
        name: name,
        gender: gender,
        dateOfBirth: dateOfBirth,
        city: city,
      );
      state = state.copyWith(
        patientId: patient.id,
        patient: patient,
        loading: false,
      );
      try {
        await ref.read(localDatabaseProvider).setActivePatientId(patient.id);
      } catch (_) {}
      if (patient.id.isNotEmpty) {
        await loadPatientData(patient.id);
      }
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Failed to register patient');
    }
  }

  Future<void> bookAppointment({
    required String doctorName,
    required String specialty,
    required String location,
    required String date,
    required String doctorId,
    String startTime = '',
    String endTime = '',
    String reason = '',
  }) async {
    if (state.patientId == null || state.patientId!.isEmpty) {
      state = state.copyWith(error: 'Cannot book: no patient ID');
      return;
    }
    try {
      await _repo.bookAppointment(
        patientId: state.patientId!,
        doctorName: doctorName,
        specialty: specialty,
        location: location,
        date: date,
        doctorId: doctorId,
        startTime: startTime,
        endTime: endTime,
        reason: reason,
      );
      await loadPatientData(state.patientId!);
    } catch (e) {
      state = state.copyWith(error: 'Failed to book appointment');
      rethrow;
    }
  }

  Future<void> cancelAppointment(String appointmentId, {String? reason}) async {
    try {
      await _repo.cancelAppointment(appointmentId, reason: reason);
      if (state.patientId != null) {
        await loadPatientData(state.patientId!);
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to cancel appointment');
    }
  }

  Future<void> rescheduleAppointment(String appointmentId, {
    required String date,
    required String startTime,
    required String endTime,
    String? reason,
  }) async {
    try {
      await _repo.rescheduleAppointment(appointmentId, date: date, startTime: startTime, endTime: endTime, reason: reason);
      if (state.patientId != null) {
        await loadPatientData(state.patientId!);
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to reschedule appointment');
    }
  }

  Future<void> confirmAppointment(String appointmentId) async {
    try {
      await _repo.confirmAppointment(appointmentId);
      if (state.patientId != null) {
        await loadPatientData(state.patientId!);
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to confirm appointment');
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await _repo.markAllNotificationsRead();
    } catch (_) {}
    state = state.copyWith(
      notifications: state.notifications.map((n) {
        return NotificationModel(
          id: n.id, type: n.type, title: n.title,
          message: n.message, time: n.time, read: true,
        );
      }).toList(),
    );
  }

  Future<void> markNotificationRead(String id) async {
    try {
      await _repo.markNotificationRead(id);
    } catch (_) {}
    state = state.copyWith(
      notifications: state.notifications.map((n) {
        if (n.id == id) {
          return NotificationModel(
            id: n.id, type: n.type, title: n.title,
            message: n.message, time: n.time, read: true,
          );
        }
        return n;
      }).toList(),
    );
  }

  Future<void> revokeAccess(String grantId) async {
    try {
      await _repo.revokeAccess(grantId);
    } catch (_) {}
    state = state.copyWith(
      accessGrants: state.accessGrants.map((g) {
        if (g.id == grantId) {
          return AccessGrant(
            id: g.id, patientId: g.patientId,
            institutionId: g.institutionId, institutionName: g.institutionName,
            mode: g.mode, scope: g.scope, grantedAt: g.grantedAt,
            expiresAt: g.expiresAt, status: 'REVOKED',
          );
        }
        return g;
      }).toList(),
    );
  }

  Future<void> approveAccess(String grantId) async {
    try {
      await _repo.approveAccessRequest(grantId);
    } catch (_) {}
    state = state.copyWith(
      accessGrants: state.accessGrants.map((g) {
        if (g.id == grantId) {
          return AccessGrant(
            id: g.id, patientId: g.patientId,
            institutionId: g.institutionId, institutionName: g.institutionName,
            mode: g.mode, scope: g.scope, grantedAt: g.grantedAt,
            expiresAt: g.expiresAt, status: 'ACTIVE',
          );
        }
        return g;
      }).toList(),
    );
  }

  Future<void> reissueCard() async {
    if (state.patientId == null || state.patientId!.isEmpty) return;
    try {
      await _repo.requestCardReissue(state.patientId!);
      await loadPatientData(state.patientId!);
    } catch (_) {}
  }

  Future<bool> updateEmergencyContact({
    required String name,
    required String relationship,
    required String phone,
  }) async {
    try {
      await _repo.updatePatient({
        'emergencyContactName': name,
        'emergencyContactRelationship': relationship,
        'emergencyContactPhone': phone,
      });
      if (state.patient != null) {
        state = state.copyWith(
          patient: state.patient!.copyWith(
            emergencyContact: EmergencyContact(
              name: name,
              relationship: relationship,
              phone: phone,
            ),
          ),
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> triggerSos({String? notes}) async {
    try {
      return await _repo.triggerSos(
        location: '',
        type: 'emergency',
        notes: notes,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> refreshPatientData() async {
    if (state.patientId == null || state.patientId!.isEmpty) return;
    await loadPatientData(state.patientId!);
  }

  Future<ChatConversation?> refreshChat(String chatId) async {
    try {
      final chat = await _repo.getChatById(chatId);
      if (chat != null) {
        final chats = state.chats.map((c) => c.id == chatId ? chat : c).toList();
        state = state.copyWith(chats: chats);
      }
      return chat;
    } catch (_) {
      return null;
    }
  }

  Future<void> sendChatMessage(String chatId, String content) async {
    final result = await _repo.sendMessage(chatId: chatId, content: content);
    final sent = ResponseMapper.messageFromBackend(result);
    final chats = state.chats.map((c) {
      if (c.id == chatId) {
        return c.copyWith(
          id: c.id,
          participantName: c.participantName,
          participantRole: c.participantRole,
          participantInitials: c.participantInitials,
          lastMessage: sent.text,
          lastMessageDate: sent.timestamp,
          unread: 0,
          online: c.online,
          messages: [...c.messages, sent],
        );
      }
      return c;
    }).toList();
    state = state.copyWith(chats: chats);
  }

  Future<void> appendIncomingMessage(String chatId, ChatMessage message) async {
    final chats = state.chats.map((c) {
      if (c.id == chatId && !c.messages.any((m) => m.id == message.id)) {
        return c.copyWith(
          id: c.id,
          participantName: c.participantName,
          participantRole: c.participantRole,
          participantInitials: c.participantInitials,
          lastMessage: message.text,
          lastMessageDate: message.timestamp,
          unread: c.unread + 1,
          online: c.online,
          messages: [...c.messages, message],
        );
      }
      return c;
    }).toList();
    state = state.copyWith(chats: chats);
  }

  Future<void> markChatAsRead(String chatId) async {
    try {
      await _repo.markChatAsRead(chatId);
    } catch (_) {}
    state = state.copyWith(
      chats: state.chats.map((c) => c.id == chatId ? c.copyWith(unread: 0) : c).toList(),
    );
  }

  Future<String?> uploadAvatar(String filePath) async {
    return _repo.uploadAvatar(filePath, patientId: state.patientId);
  }

  void resetState() {
    state = const PatientState();
  }
}

final patientProvider = NotifierProvider<PatientNotifier, PatientState>(
  PatientNotifier.new,
);
