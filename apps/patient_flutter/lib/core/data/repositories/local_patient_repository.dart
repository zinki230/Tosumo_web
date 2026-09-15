import '../../domain/repositories/patient_repository.dart';
import '../../database/local_database.dart';
import '../../../shared/models/patient.dart';
import '../../../shared/models/card_model.dart';
import '../../../shared/models/booklet_entry.dart';
import '../../../shared/models/access_grant.dart';
import '../../../shared/models/audit_event.dart';
import '../../../shared/models/health_journey_entry.dart';
import '../../../shared/models/doctor_profile.dart';
import '../../../shared/models/hospital_info.dart';
import '../../../shared/models/chat_conversation.dart';
import '../../../shared/models/notification_model.dart';

class LocalPatientRepository implements PatientRepository {
  final LocalDatabase _db;

  LocalPatientRepository(this._db);

  @override
  Future<Patient?> getPatientProfile(String patientId) async {
    return _db.getById('medicard_patient', patientId, Patient.fromJson);
  }

  @override
  Future<CardModel?> getCard(String patientId) async {
    final cards = await _db.getAll('medicard_card', CardModel.fromJson);
    try {
      return cards.firstWhere((c) => c.patientId == patientId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<BookletEntry>> getMedicalBooklet(String patientId) async {
    return _db.getAll('medicard_booklet', BookletEntry.fromJson);
  }

  @override
  Future<List<AccessGrant>> getAccessGrants(String patientId) async {
    return _db.getAll('medicard_access', AccessGrant.fromJson);
  }

  @override
  Future<List<AuditEvent>> getAuditLog(String patientId) async {
    return _db.getAll('medicard_audit', AuditEvent.fromJson);
  }

  @override
  Future<List<HealthJourneyEntry>> getHealthJourney(String patientId) async {
    return _db.getAll('medicard_journey', HealthJourneyEntry.fromJson);
  }

  @override
  Future<List<DoctorProfile>> getDoctors() async {
    return _db.getAll('medicard_doctors', DoctorProfile.fromJson);
  }

  @override
  Future<DoctorProfile?> getDoctorById(String doctorId) async {
    return _db.getById('medicard_doctors', doctorId, DoctorProfile.fromJson);
  }

  @override
  Future<List<HospitalInfo>> getHospitals() async {
    return _db.getAll('medicard_hospitals', HospitalInfo.fromJson);
  }

  @override
  Future<List<ChatConversation>> getChats(String patientId) async {
    return _db.getAll('medicard_chats', ChatConversation.fromJson);
  }

  @override
  Future<ChatConversation?> getChatById(String chatId) async {
    return _db.getById('medicard_chats', chatId, ChatConversation.fromJson);
  }

  @override
  Future<List<NotificationModel>> getNotifications(String patientId) async {
    return _db.getAll('medicard_notifications', NotificationModel.fromJson);
  }

  @override
  Future<List<NotificationModel>> getUnreadNotifications(String patientId) async {
    final all = await getNotifications(patientId);
    return all.where((n) => !n.read).toList();
  }

  @override
  Future<AccessGrant> approveAccessRequest(String grantId) async {
    final grant = await _db.getById('medicard_access', grantId, AccessGrant.fromJson);
    if (grant == null) throw Exception('Access grant not found: $grantId');
    final updated = AccessGrant(
      id: grant.id,
      patientId: grant.patientId,
      institutionId: grant.institutionId,
      institutionName: grant.institutionName,
      mode: grant.mode,
      scope: grant.scope,
      grantedAt: grant.grantedAt,
      expiresAt: grant.expiresAt,
      status: 'ACTIVE',
    );
    await _db.putById('medicard_access', grantId, updated, (g) => g.toJson());
    return updated;
  }

  @override
  Future<void> revokeAccess(String grantId) async {
    await _db.deleteById('medicard_access', grantId);
  }

  @override
  Future<CardModel> requestCardReissue(String patientId) async {
    final card = CardModel(
      patientId: patientId,
      token: 'MC-CM-${DateTime.now().millisecondsSinceEpoch}',
      status: 'ACTIVE',
      issuedAt: DateTime.now().toIso8601String(),
    );
    await _db.putAll('medicard_card', [card], (c) => c.toJson());
    return card;
  }

  @override
  Future<Patient> registerPatient({
    required String name,
    required String gender,
    required String dateOfBirth,
    required String city,
  }) async {
    // The real patient record is created by the backend during onboarding
    // (POST /patients/onboard) and keyed by its MongoDB id. We must NEVER
    // fabricate a local patient id (e.g. `patient-<timestamp>`) here, since
    // that would desync from the backend and violate data-isolation rules.
    // Registration requires connectivity; offline registration is unsupported.
    throw UnsupportedError(
      'Local patient registration is not supported; the patient record is '
      'created by the backend during onboarding.',
    );
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    final all = await _db.getAll('medicard_notifications', NotificationModel.fromJson);
    final updated = all.map((n) {
      if (n.id == notificationId) {
        return NotificationModel(
          id: n.id,
          type: n.type,
          title: n.title,
          message: n.message,
          time: n.time,
          read: true,
        );
      }
      return n;
    }).toList();
    await _db.putAll('medicard_notifications', updated, (n) => n.toJson());
  }

  @override
  Future<void> markAllNotificationsRead() async {
    final all = await _db.getAll('medicard_notifications', NotificationModel.fromJson);
    final updated = all.map((n) {
      return NotificationModel(
        id: n.id,
        type: n.type,
        title: n.title,
        message: n.message,
        time: n.time,
        read: true,
      );
    }).toList();
    await _db.putAll('medicard_notifications', updated, (n) => n.toJson());
  }

  @override
  Future<Map<String, dynamic>> bookAppointment({
    required String patientId,
    required String doctorName,
    required String specialty,
    required String location,
    required String date,
    required String doctorId,
    String startTime = '',
    String endTime = '',
    String reason = '',
  }) async {
    final now = DateTime.now();
    final result = {
      'id': 'appt-${now.millisecondsSinceEpoch}',
      'patientId': patientId,
      'doctorName': doctorName,
      'specialty': specialty,
      'location': location,
      'date': date,
      'doctorId': doctorId,
      'startTime': startTime,
      'endTime': endTime,
      'reason': reason,
      'status': 'confirmed',
      'synced': false,
    };
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> getAppointments(String patientId) async {
    final all = await _db.getAll('medicard_appointments', (m) => m);
    return all;
  }

  @override
  Future<List<Map<String, dynamic>>> getPatientMedicalRecords(String patientId) async {
    return [];
  }

  Future<void> saveAppointments(List<Map<String, dynamic>> items) async {
    if (items.isNotEmpty) {
      await _db.putAll('medicard_appointments', items, (a) => a);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAvailableSlots(String doctorId, String date) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getPrescriptions(String patientId) async {
    final all = await _db.getAll('medicard_prescriptions', (m) => m);
    return all;
  }

  @override
  Future<Map<String, dynamic>> sendMessage({
    required String chatId,
    required String content,
    String? messageType,
  }) async {
    final msg = <String, dynamic>{
      'id': 'msg-${DateTime.now().millisecondsSinceEpoch}',
      'chatId': chatId,
      'content': content,
      'messageType': messageType ?? 'text',
      'senderRole': 'patient',
      'createdAt': DateTime.now().toIso8601String(),
      'isRead': false,
    };
    return msg;
  }

  @override
  Future<void> markChatAsRead(String chatId) async {}

  @override
  Future<void> updatePatient(Map<String, dynamic> data) async {}

  @override
  Future<Map<String, dynamic>> triggerSos({
    String? location,
    String? type,
    String? notes,
  }) async {
    return {
      'id': 'sos-${DateTime.now().millisecondsSinceEpoch}',
      'status': 'active',
      'startedAt': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> getCriticalInfo() async {
    return {};
  }

  @override
  Future<List<HospitalInfo>> getNearbyHospitals() async {
    return [];
  }

  @override
  Future<AccessGrant> grantAccess({
    required String doctorId,
    required String accessLevel,
    String? reason,
    String? expiresAt,
  }) async {
    throw Exception('Offline: cannot grant access');
  }

  Future<void> savePatient(Patient patient) async {
    await _db.putById('medicard_patient', patient.id, patient, (p) => p.toJson());
  }

  Future<void> saveCard(CardModel card) async {
    await _db.putById('medicard_card', card.patientId, card, (c) => c.toJson(), idField: 'patientId');
  }

  Future<void> saveMedicalBooklet(List<BookletEntry> entries) async {
    if (entries.isNotEmpty) {
      await _db.putAll('medicard_booklet', entries, (e) => e.toJson());
    }
  }

  Future<void> saveAccessGrants(List<AccessGrant> grants) async {
    if (grants.isNotEmpty) {
      await _db.putAll('medicard_access', grants, (g) => g.toJson());
    }
  }

  Future<void> saveDoctorList(List<DoctorProfile> doctors) async {
    if (doctors.isNotEmpty) {
      await _db.putAll('medicard_doctors', doctors, (d) => d.toJson());
    }
  }

  Future<void> saveDoctor(DoctorProfile doctor) async {
    await _db.putById('medicard_doctors', doctor.id, doctor, (d) => d.toJson());
  }

  Future<void> saveNotifications(List<NotificationModel> notifications) async {
    if (notifications.isNotEmpty) {
      await _db.putAll('medicard_notifications', notifications, (n) => n.toJson());
    }
  }

  Future<void> saveChatList(List<ChatConversation> chats) async {
    if (chats.isNotEmpty) {
      await _db.putAll('medicard_chats', chats, (c) => c.toJson());
    }
  }

  Future<void> saveChat(ChatConversation chat) async {
    await _db.putById('medicard_chats', chat.id, chat, (c) => c.toJson());
  }

  @override
  Future<void> cancelAppointment(String appointmentId, {String? reason}) async {
    final all = await _db.getAll('medicard_appointments', (m) => Map<String, dynamic>.from(m));
    final updated = all.map((a) {
      if (a['id'] == appointmentId) {
        a['status'] = 'cancelled';
        if (reason != null) a['cancellationReason'] = reason;
      }
      return a;
    }).toList();
    await _db.putAll('medicard_appointments', updated, (a) => a);
  }

  @override
  Future<void> rescheduleAppointment(String appointmentId, {
    required String date,
    required String startTime,
    required String endTime,
    String? reason,
  }) async {
    final all = await _db.getAll('medicard_appointments', (m) => Map<String, dynamic>.from(m));
    final updated = all.map((a) {
      if (a['id'] == appointmentId) {
        a['appointmentDate'] = date;
        a['startTime'] = startTime;
        a['endTime'] = endTime;
        a['status'] = 'rescheduled';
      }
      return a;
    }).toList();
    await _db.putAll('medicard_appointments', updated, (a) => a);
  }

  @override
  Future<void> confirmAppointment(String appointmentId) async {
    final all = await _db.getAll('medicard_appointments', (m) => Map<String, dynamic>.from(m));
    final updated = all.map((a) {
      if (a['id'] == appointmentId) {
        a['status'] = 'confirmed';
      }
      return a;
    }).toList();
    await _db.putAll('medicard_appointments', updated, (a) => a);
  }

  @override
  Future<String?> uploadAvatar(String filePath, {String? patientId}) async {
    return null;
  }

  @override
  Future<bool> sendOtp({required String phone, String? email}) async {
    return true;
  }

  @override
  Future<bool> verifyOtp({required String phone, required String otp, String? email}) async {
    return true;
  }
}
