// ignore_for_file: duplicate_import

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../domain/repositories/doctor_repository.dart';
import '../../../domain/repositories/patient_repository.dart';
import '../../../domain/repositories/appointment_repository.dart';
import '../../../domain/repositories/consultation_repository.dart';
import '../../../domain/repositories/prescription_repository.dart';
import '../../../domain/repositories/laboratory_repository.dart';
import '../../../domain/repositories/imaging_repository.dart';
import '../../../domain/repositories/chat_repository.dart';
import '../../../domain/repositories/notification_repository.dart';
import '../../../domain/repositories/emergency_repository.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../domain/models/doctor.dart';
import '../../../domain/models/dashboard_stats.dart';
import '../../../domain/models/appointment.dart';
import '../../../domain/models/patient_summary.dart';
import '../../../domain/models/patient_detail.dart';
import '../../../domain/models/patient_vitals_update.dart';
import '../../../domain/models/consultation.dart';
import '../../../domain/models/vital_signs.dart';
import '../../../domain/models/prescription.dart';
import '../../../domain/models/lab_request.dart';
import '../../../domain/models/imaging_request.dart';
import '../../../domain/models/chat_conversation.dart';
import '../../../domain/models/chat_message.dart';
import '../../../domain/models/notification_item.dart';
import '../../../domain/models/emergency_session.dart';
import '../../../domain/models/working_hour.dart';
import '../../../domain/models/vital_signs.dart';
import '../../../domain/models/emergency_contact_info.dart';
import '../../../domain/models/message_metadata.dart';
import '../../database/local_database.dart';

const _boxDoctor = 'doctor_profile';
const _boxPatients = 'doctor_patients';
const _boxAppointments = 'doctor_appointments';
const _boxConsultations = 'doctor_consultations';
const _boxPrescriptions = 'doctor_prescriptions';
const _boxLabs = 'doctor_labs';
const _boxImaging = 'doctor_imaging';
const _boxChats = 'doctor_chats';
const _boxNotifications = 'doctor_notifications';
const _boxEmergency = 'doctor_emergency';
const _boxSettings = 'doctor_settings';
const _boxAnalytics = 'doctor_analytics';

class LocalDoctorRepository implements
    DoctorRepository, PatientRepository, AppointmentRepository,
    ConsultationRepository, PrescriptionRepository, LaboratoryRepository,
    ImagingRepository, ChatRepository, NotificationRepository,
    EmergencyRepository, AnalyticsRepository, SettingsRepository, AuthRepository {
  final LocalDatabase _db;
  final FlutterSecureStorage _secureStorage;

  LocalDoctorRepository(this._db, this._secureStorage);

  @override
  Future<Doctor> getProfile(String doctorId) async {
    final result = await _db.getById(_boxDoctor, doctorId, Doctor.fromJson);
    if (result == null) throw Exception('Doctor not found: $doctorId');
    return result;
  }

  @override
  Future<Doctor> updateProfile(Doctor doctor) async {
    await _db.putById(_boxDoctor, doctor.id, doctor, (d) => d.toJson());
    return doctor;
  }

  @override
  Future<DashboardStats> getDashboardStats(String doctorId) async {
    final appointments = await _db.getAll(_boxAppointments, Appointment.fromJson);
    final doctorAppts = appointments.where((a) => a.doctorId == doctorId).toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DashboardStats(
      totalAppointments: doctorAppts.length,
      todayAppointments: doctorAppts.where((a) =>
        a.date.isAfter(today) && a.date.isBefore(today.add(const Duration(days: 1))) &&
        a.status != 'cancelled'
      ).length,
      pendingApprovals: doctorAppts.where((a) => a.status == 'pending').length,
      totalPatients: doctorAppts.map((a) => a.patientId).toSet().length,
      recentAppointments: doctorAppts.take(5).toList(),
      upcomingAppointments: doctorAppts
          .where((a) => a.status == 'approved' || a.status == 'confirmed')
          .toList(),
    );
  }

  @override
  Future<List<Appointment>> getTodayAppointments(String doctorId) async {
    final all = await _db.getAll(_boxAppointments, Appointment.fromJson);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return all.where((a) =>
      a.doctorId == doctorId &&
      a.date.isAfter(today) &&
      a.date.isBefore(today.add(const Duration(days: 1)))
    ).toList();
  }

  @override
  Future<List<Appointment>> getWeeklyAppointments(String doctorId) async {
    final all = await _db.getAll(_boxAppointments, Appointment.fromJson);
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    return all.where((a) =>
      a.doctorId == doctorId &&
      a.date.isAfter(weekStart) &&
      a.date.isBefore(weekEnd)
    ).toList();
  }

  @override
  Future<List<PatientSummary>> searchPatients(String query) async {
    final all = await _db.getAll(_boxPatients, PatientSummary.fromJson);
    final q = query.toLowerCase();
    return all.where((p) =>
      p.name.toLowerCase().contains(q) ||
      p.nationalId.toLowerCase().contains(q)
    ).toList();
  }

  @override
  Future<List<PatientSummary>> searchByFilters({
    String? name, String? nationalId, String? phone, String? medicalId,
  }) async {
    final all = await _db.getAll(_boxPatients, PatientSummary.fromJson);
    return all.where((p) {
      if (name != null && !p.name.toLowerCase().contains(name.toLowerCase())) return false;
      if (nationalId != null && !p.nationalId.toLowerCase().contains(nationalId.toLowerCase())) return false;
      return true;
    }).toList();
  }

  @override
  Future<PatientDetail> getPatientById(String patientId) async {
    final result = await _db.getById(_boxPatients, patientId, PatientDetail.fromJson);
    if (result == null) throw Exception('Patient not found: $patientId');
    return result;
  }

  @override
  Future<PatientDetail> getPatientByQrCode(String qrData) async {
    final all = await _db.getAll(_boxPatients, PatientDetail.fromJson);
    final found = all.where((p) => p.nationalId == qrData || p.id == qrData).firstOrNull;
    if (found == null) throw Exception('Patient not found for QR: $qrData');
    return found;
  }

  @override
  Future<void> grantPatientAccess(String patientId, String doctorUserId) async {}

  @override
  Future<PatientDetail> updatePatientVitals(String patientId, PatientVitalsUpdate update) {
    throw UnimplementedError('Local patient vitals update is not supported');
  }

  @override
  Future<List<PatientSummary>> getRecentPatients(String doctorId) async {
    final all = await _db.getAll(_boxPatients, PatientSummary.fromJson);
    return all.take(10).toList();
  }

  @override
  Future<void> toggleFavorite(String patientId, bool favorite) async {
    final patient = await _db.getById(_boxPatients, patientId, PatientSummary.fromJson);
    if (patient != null) {
      final updated = PatientSummary(
        id: patient.id,
        name: patient.name,
        nationalId: patient.nationalId,
        dateOfBirth: patient.dateOfBirth,
        bloodType: patient.bloodType,
        gender: patient.gender,
        photoUrl: patient.photoUrl,
        lastVisit: patient.lastVisit,
        isFavorite: favorite,
      );
      await _db.putById(_boxPatients, patientId, updated, (p) => p.toJson());
    }
  }

  @override
  Future<List<Appointment>> getAppointments(String doctorId, {String? status, int? page, int? limit}) async {
    var all = await _db.getAll(_boxAppointments, Appointment.fromJson);
    all = all.where((a) => a.doctorId == doctorId).toList();
    if (status != null) all = all.where((a) => a.status == status).toList();
    if (page != null && limit != null) {
      final start = page * limit;
      all = all.skip(start).take(limit).toList();
    }
    return all;
  }

  @override
  Future<Appointment> getAppointment(String id) async {
    final result = await _db.getById(_boxAppointments, id, Appointment.fromJson);
    if (result == null) throw Exception('Appointment not found: $id');
    return result;
  }

  @override
  Future<void> approveAppointment(String id) async {
    final appt = await getAppointment(id);
    final updated = Appointment(
      id: appt.id, patientId: appt.patientId, patientName: appt.patientName,
      doctorId: appt.doctorId, date: appt.date, timeSlot: appt.timeSlot,
      type: appt.type, status: 'confirmed', reason: appt.reason,
      notes: appt.notes, isUrgent: appt.isUrgent, createdAt: appt.createdAt,
    );
    await _db.putById(_boxAppointments, id, updated, (a) => a.toJson());
  }

  @override
  Future<void> rejectAppointment(String id, {String? reason}) async {
    final appt = await getAppointment(id);
    final updated = Appointment(
      id: appt.id, patientId: appt.patientId, patientName: appt.patientName,
      doctorId: appt.doctorId, date: appt.date, timeSlot: appt.timeSlot,
      type: appt.type, status: 'cancelled', reason: appt.reason,
      notes: reason ?? appt.notes, isUrgent: appt.isUrgent, createdAt: appt.createdAt,
    );
    await _db.putById(_boxAppointments, id, updated, (a) => a.toJson());
  }

  @override
  Future<void> rescheduleAppointment(String id, DateTime newDate, String newTimeSlot) async {
    final appt = await getAppointment(id);
    final updated = Appointment(
      id: appt.id, patientId: appt.patientId, patientName: appt.patientName,
      doctorId: appt.doctorId, date: newDate, timeSlot: newTimeSlot,
      type: appt.type, status: 'rescheduled', reason: appt.reason,
      notes: appt.notes, isUrgent: appt.isUrgent, createdAt: appt.createdAt,
    );
    await _db.putById(_boxAppointments, id, updated, (a) => a.toJson());
  }

  @override
  Future<void> completeAppointment(String id) async {
    final appt = await getAppointment(id);
    final updated = Appointment(
      id: appt.id, patientId: appt.patientId, patientName: appt.patientName,
      doctorId: appt.doctorId, date: appt.date, timeSlot: appt.timeSlot,
      type: appt.type, status: 'completed', reason: appt.reason,
      notes: appt.notes, isUrgent: appt.isUrgent, createdAt: appt.createdAt,
    );
    await _db.putById(_boxAppointments, id, updated, (a) => a.toJson());
  }

  @override
  Future<void> cancelAppointment(String id, {String? reason}) async {
    final appt = await getAppointment(id);
    final updated = Appointment(
      id: appt.id, patientId: appt.patientId, patientName: appt.patientName,
      doctorId: appt.doctorId, date: appt.date, timeSlot: appt.timeSlot,
      type: appt.type, status: 'cancelled', reason: appt.reason,
      notes: reason ?? appt.notes, isUrgent: appt.isUrgent, createdAt: appt.createdAt,
    );
    await _db.putById(_boxAppointments, id, updated, (a) => a.toJson());
  }

  @override
  Future<void> markNoShow(String id) async {
    final appt = await getAppointment(id);
    final updated = Appointment(
      id: appt.id, patientId: appt.patientId, patientName: appt.patientName,
      doctorId: appt.doctorId, date: appt.date, timeSlot: appt.timeSlot,
      type: appt.type, status: 'no-show', reason: appt.reason,
      notes: appt.notes, isUrgent: appt.isUrgent, createdAt: appt.createdAt,
    );
    await _db.putById(_boxAppointments, id, updated, (a) => a.toJson());
  }

  @override
  Future<Appointment> bookAppointment(
    String patientId, String doctorId, DateTime date, String timeSlot, String type,
  ) async {
    final appt = Appointment(
      id: 'appt-${DateTime.now().millisecondsSinceEpoch}',
      patientId: patientId,
      patientName: '',
      doctorId: doctorId,
      date: date,
      timeSlot: timeSlot,
      type: type,
      status: 'scheduled',
      reason: '',
      notes: '',
      isUrgent: false,
      createdAt: DateTime.now(),
    );
    await _db.putById(_boxAppointments, appt.id, appt, (a) => a.toJson());
    return appt;
  }

  @override
  Future<Consultation> createConsultation(Consultation consultation) async {
    await _db.putById(_boxConsultations, consultation.id, consultation, (c) => c.toJson());
    return consultation;
  }

  @override
  Future<Consultation> getConsultation(String id) async {
    final result = await _db.getById(_boxConsultations, id, Consultation.fromJson);
    if (result == null) throw Exception('Consultation not found: $id');
    return result;
  }

  @override
  Future<List<Consultation>> getPatientConsultations(String patientId) async {
    final all = await _db.getAll(_boxConsultations, Consultation.fromJson);
    return all.where((c) => c.patientId == patientId).toList();
  }

  @override
  Future<List<Consultation>> getMyConsultations() async {
    return _db.getAll(_boxConsultations, Consultation.fromJson);
  }

  @override
  Future<Consultation> updateDraft(String id, Consultation consultation) async {
    await _db.putById(_boxConsultations, id, consultation, (c) => c.toJson());
    return consultation;
  }

  @override
  Future<Consultation> finalizeConsultation(String id) async {
    final c = await getConsultation(id);
    final updated = Consultation(
      id: c.id, patientId: c.patientId, doctorId: c.doctorId,
      appointmentId: c.appointmentId, date: c.date,
      symptoms: c.symptoms, diagnosis: c.diagnosis,
      clinicalNotes: c.clinicalNotes, vitals: c.vitals,
      physicalExamination: c.physicalExamination,
      treatment: c.treatment, followUpPlan: c.followUpPlan,
      severity: c.severity, status: 'finalized',
      signedAt: c.signedAt, createdAt: c.createdAt,
    );
    await _db.putById(_boxConsultations, id, updated, (c) => c.toJson());
    return updated;
  }

  @override
  Future<Consultation> signConsultation(String id) async {
    final c = await getConsultation(id);
    final updated = Consultation(
      id: c.id, patientId: c.patientId, doctorId: c.doctorId,
      appointmentId: c.appointmentId, date: c.date,
      symptoms: c.symptoms, diagnosis: c.diagnosis,
      clinicalNotes: c.clinicalNotes, vitals: c.vitals,
      physicalExamination: c.physicalExamination,
      treatment: c.treatment, followUpPlan: c.followUpPlan,
      severity: c.severity, status: 'signed',
      signedAt: DateTime.now(), createdAt: c.createdAt,
    );
    await _db.putById(_boxConsultations, id, updated, (c) => c.toJson());
    return updated;
  }

  @override
  Future<String> generatePdf(String id) async {
    return '/reports/consultation_$id.pdf';
  }

  @override
  Future<void> saveVitalSigns(String consultationId, VitalSigns vitals) async {
    final c = await getConsultation(consultationId);
    final updated = Consultation(
      id: c.id, patientId: c.patientId, doctorId: c.doctorId,
      appointmentId: c.appointmentId, date: c.date,
      symptoms: c.symptoms, diagnosis: c.diagnosis,
      clinicalNotes: c.clinicalNotes, vitals: vitals,
      physicalExamination: c.physicalExamination,
      treatment: c.treatment, followUpPlan: c.followUpPlan,
      severity: c.severity, status: c.status,
      signedAt: c.signedAt, createdAt: c.createdAt,
    );
    await _db.putById(_boxConsultations, consultationId, updated, (c) => c.toJson());
  }

  @override
  Future<Prescription> createPrescription(Prescription prescription) async {
    await _db.putById(_boxPrescriptions, prescription.id, prescription, (p) => p.toJson());
    return prescription;
  }

  @override
  Future<Prescription> getPrescription(String id) async {
    final result = await _db.getById(_boxPrescriptions, id, Prescription.fromJson);
    if (result == null) throw Exception('Prescription not found: $id');
    return result;
  }

  @override
  Future<List<Prescription>> getPatientPrescriptions(String patientId) async {
    final all = await _db.getAll(_boxPrescriptions, Prescription.fromJson);
    return all.where((p) => p.patientId == patientId).toList();
  }

  @override
  Future<Prescription> renewPrescription(String id) async {
    final p = await getPrescription(id);
    final renewed = Prescription(
      id: '${p.id}-renewed',
      patientId: p.patientId,
      doctorId: p.doctorId,
      consultationId: p.consultationId,
      medications: p.medications,
      notes: p.notes,
      issueDate: DateTime.now(),
      expiryDate: DateTime.now().add(const Duration(days: 90)),
      isRenewed: true,
      status: 'active',
      createdAt: DateTime.now(),
    );
    await _db.putById(_boxPrescriptions, renewed.id, renewed, (p) => p.toJson());
    return renewed;
  }

  @override
  Future<void> cancelPrescription(String id) async {
    final p = await getPrescription(id);
    final updated = Prescription(
      id: p.id, patientId: p.patientId, doctorId: p.doctorId,
      consultationId: p.consultationId, medications: p.medications,
      notes: p.notes, issueDate: p.issueDate, expiryDate: p.expiryDate,
      isRenewed: p.isRenewed, status: 'cancelled', createdAt: p.createdAt,
    );
    await _db.putById(_boxPrescriptions, id, updated, (p) => p.toJson());
  }

  @override
  Future<LabRequest> createLabRequest(LabRequest request) async {
    await _db.putById(_boxLabs, request.id, request, (l) => l.toJson());
    return request;
  }

  @override
  Future<LabRequest> getLabRequest(String id) async {
    final result = await _db.getById(_boxLabs, id, LabRequest.fromJson);
    if (result == null) throw Exception('Lab request not found: $id');
    return result;
  }

  @override
  Future<List<LabRequest>> getPatientLabRequests(String patientId) async {
    final all = await _db.getAll(_boxLabs, LabRequest.fromJson);
    return all.where((l) => l.patientId == patientId).toList();
  }

  @override
  Future<List<LabRequest>> getPendingRequests(String doctorId) async {
    final all = await getAllLabRequests(doctorId);
    return all.where((l) => l.status == 'pending').toList();
  }

  @override
  Future<List<LabRequest>> getAllLabRequests(String doctorId) async {
    final all = await _db.getAll(_boxLabs, LabRequest.fromJson);
    return all.where((l) => l.doctorId == doctorId).toList();
  }

  @override
  Future<void> updateLabResults(String id, {String? resultValue, String? interpretation, String? status}) async {
    final l = await getLabRequest(id);
    final updated = LabRequest(
      id: l.id, patientId: l.patientId, doctorId: l.doctorId,
      consultationId: l.consultationId, testName: l.testName,
      testType: l.testType,
      status: status ?? l.status,
      resultValue: resultValue ?? l.resultValue,
      referenceRange: l.referenceRange,
      interpretation: interpretation ?? l.interpretation,
      attachments: l.attachments, orderedAt: l.orderedAt,
      completedAt: status == 'completed' ? DateTime.now() : l.completedAt,
      notes: l.notes,
    );
    await _db.putById(_boxLabs, id, updated, (l) => l.toJson());
  }

  @override
  Future<ImagingRequest> createImagingRequest(ImagingRequest request) async {
    await _db.putById(_boxImaging, request.id, request, (i) => i.toJson());
    return request;
  }

  @override
  Future<ImagingRequest> getImagingRequest(String id) async {
    final result = await _db.getById(_boxImaging, id, ImagingRequest.fromJson);
    if (result == null) throw Exception('Imaging request not found: $id');
    return result;
  }

  @override
  Future<List<ImagingRequest>> getPatientImagingRequests(String patientId) async {
    final all = await _db.getAll(_boxImaging, ImagingRequest.fromJson);
    return all.where((i) => i.patientId == patientId).toList();
  }

  @override
  Future<List<ImagingRequest>> getPendingImagingRequests(String doctorId) async {
    final all = await getAllImagingRequests(doctorId);
    return all.where((i) => i.status == 'pending').toList();
  }

  @override
  Future<List<ImagingRequest>> getAllImagingRequests(String doctorId) async {
    final all = await _db.getAll(_boxImaging, ImagingRequest.fromJson);
    return all.where((i) => i.doctorId == doctorId).toList();
  }

  @override
  Future<void> updateImagingResults(String id, {String? findings, String? impression, String? status}) async {
    final i = await getImagingRequest(id);
    final updated = ImagingRequest(
      id: i.id, patientId: i.patientId, doctorId: i.doctorId,
      consultationId: i.consultationId, imagingType: i.imagingType,
      bodyPart: i.bodyPart,
      status: status ?? i.status,
      findings: findings ?? i.findings,
      impression: impression ?? i.impression,
      attachments: i.attachments, orderedAt: i.orderedAt,
      completedAt: status == 'completed' ? DateTime.now() : i.completedAt,
      notes: i.notes,
    );
    await _db.putById(_boxImaging, id, updated, (i) => i.toJson());
  }

  @override
  Future<List<ChatConversation>> getConversations(String doctorId) async {
    return _db.getAll(_boxChats, ChatConversation.fromJson);
  }

  @override
  Future<List<ChatMessage>> getMessages(String conversationId, {int? page, int? limit}) async {
    final conv = await _db.getById(_boxChats, conversationId, ChatConversation.fromJson);
    if (conv == null) return [];
    var messages = conv.messages;
    if (page != null && limit != null) {
      final start = page * limit;
      messages = messages.skip(start).take(limit).toList();
    }
    return messages;
  }

  @override
  Future<ChatMessage> sendMessage(String conversationId, String text, {String? type, Map<String, dynamic>? metadata}) async {
    final conv = await _db.getById(_boxChats, conversationId, ChatConversation.fromJson);
    final message = ChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: '',
      senderName: '',
      senderRole: 'doctor',
      text: text,
      type: type ?? 'text',
      metadata: metadata != null ? MessageMetadata.fromJson(metadata) : null,
      status: 'sent',
      timestamp: DateTime.now(),
    );
    if (conv != null) {
      final updated = ChatConversation(
        id: conv.id, participantName: conv.participantName,
        participantRole: conv.participantRole,
        participantInitials: conv.participantInitials,
        lastMessage: text, lastMessageDate: DateTime.now(),
        unread: 0, online: conv.online,
        messages: [...conv.messages, message],
      );
      await _db.putById(_boxChats, conversationId, updated, (c) => c.toJson());
    }
    return message;
  }

  @override
  Future<void> markChatRead(String id) async {
    final n = await _db.getById(_boxNotifications, id, NotificationItem.fromJson);
    if (n != null) {
      final updated = NotificationItem(
        id: n.id, type: n.type, title: n.title, message: n.message,
        data: n.data, read: true, createdAt: n.createdAt,
      );
      await _db.putById(_boxNotifications, id, updated, (n) => n.toJson());
      return;
    }
    final conv = await _db.getById(_boxChats, id, ChatConversation.fromJson);
    if (conv != null) {
      final updated = ChatConversation(
        id: conv.id, participantName: conv.participantName,
        participantRole: conv.participantRole,
        participantInitials: conv.participantInitials,
        lastMessage: conv.lastMessage, lastMessageDate: conv.lastMessageDate,
        unread: 0, online: conv.online, messages: conv.messages,
      );
      await _db.putById(_boxChats, id, updated, (c) => c.toJson());
    }
  }

  @override
  Future<void> markMessageDelivered(String messageId) async {
    final allConvs = await _db.getAll(_boxChats, ChatConversation.fromJson);
    for (final conv in allConvs) {
      final idx = conv.messages.indexWhere((m) => m.id == messageId);
      if (idx >= 0) {
        final updatedMsg = ChatMessage(
          id: conv.messages[idx].id,
          conversationId: conv.messages[idx].conversationId,
          senderId: conv.messages[idx].senderId,
          senderName: conv.messages[idx].senderName,
          senderRole: conv.messages[idx].senderRole,
          text: conv.messages[idx].text,
          type: conv.messages[idx].type,
          metadata: conv.messages[idx].metadata,
          status: 'delivered',
          timestamp: conv.messages[idx].timestamp,
        );
        final updatedMessages = [...conv.messages];
        updatedMessages[idx] = updatedMsg;
        final updated = ChatConversation(
          id: conv.id, participantName: conv.participantName,
          participantRole: conv.participantRole,
          participantInitials: conv.participantInitials,
          lastMessage: conv.lastMessage, lastMessageDate: conv.lastMessageDate,
          unread: conv.unread, online: conv.online, messages: updatedMessages,
        );
        await _db.putById(_boxChats, conv.id, updated, (c) => c.toJson());
        break;
      }
    }
  }

  @override
  Future<List<NotificationItem>> getNotifications(String doctorId) async {
    return _db.getAll(_boxNotifications, NotificationItem.fromJson);
  }

  @override
  Future<List<NotificationItem>> getUnreadNotifications(String doctorId) async {
    final all = await _db.getAll(_boxNotifications, NotificationItem.fromJson);
    return all.where((n) => !n.read).toList();
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    final all = await _db.getAll(_boxNotifications, NotificationItem.fromJson);
    final updated = all.map((n) {
      if (n.id != notificationId) return n;
      return NotificationItem(
        id: n.id, type: n.type, title: n.title, message: n.message,
        data: n.data, read: true, createdAt: n.createdAt,
      );
    }).toList();
    await _db.putAll(_boxNotifications, updated, (n) => n.toJson());
  }

  @override
  Future<void> markAllAsRead() async {
    final all = await _db.getAll(_boxNotifications, NotificationItem.fromJson);
    final updated = all.map((n) => NotificationItem(
      id: n.id, type: n.type, title: n.title, message: n.message,
      data: n.data, read: true, createdAt: n.createdAt,
    )).toList();
    await _db.putAll(_boxNotifications, updated, (n) => n.toJson());
  }

  @override
  Future<EmergencySession?> getActiveSession(String doctorId) async {
    final all = await _db.getAll(_boxEmergency, EmergencySession.fromJson);
    try {
      return all.firstWhere((s) => s.doctorId == doctorId && s.status == 'active');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<EmergencySession>> getEmergencyHistory(String doctorId) async {
    final all = await _db.getAll(_boxEmergency, EmergencySession.fromJson);
    return all.where((s) => s.doctorId == doctorId).toList();
  }

  @override
  Future<EmergencySession> startEmergencySession(String patientId, String doctorId, String justification) async {
    final session = EmergencySession(
      id: 'emerg-${DateTime.now().millisecondsSinceEpoch}',
      patientId: patientId,
      doctorId: doctorId,
      startedAt: DateTime.now(),
      status: 'active',
      patientSummary: EmergencyPatientSummary(
        name: 'Patient',
        age: 0,
        bloodType: 'O+',
        gender: 'Non spécifié',
        allergies: [],
        chronicConditions: [],
        emergencyContact: null,
        chiefComplaint: justification,
        triageNotes: '',
      ),
    );
    await _db.putById(_boxEmergency, session.id, session, (s) => s.toJson());
    return session;
  }

  @override
  Future<void> completeEmergencySession(String sessionId) async {
    final s = await _db.getById(_boxEmergency, sessionId, EmergencySession.fromJson);
    if (s != null) {
      final updated = EmergencySession(
        id: s.id, patientId: s.patientId, doctorId: s.doctorId,
        startedAt: s.startedAt, status: 'completed',
        patientSummary: s.patientSummary,
      );
      await _db.putById(_boxEmergency, sessionId, updated, (s) => s.toJson());
    }
  }

  @override
  Future<EmergencyPatientSummary> getEmergencyPatientSummary(String patientId) async {
    final patient = await _db.getById(_boxPatients, patientId, PatientDetail.fromJson);
    if (patient == null) throw Exception('Patient not found: $patientId');
    final now = DateTime.now();
    final age = now.year - patient.dateOfBirth.year;
    return EmergencyPatientSummary(
      name: patient.name,
      age: age,
      bloodType: patient.bloodType,
      gender: patient.gender,
      allergies: patient.allergies,
      chronicConditions: patient.chronicConditions,
      emergencyContact: patient.emergencyContact != null
          ? EmergencyContactInfo(
              name: patient.emergencyContact!.name,
              relationship: patient.emergencyContact!.relationship,
              phone: patient.emergencyContact!.phone,
            )
          : null,
      chiefComplaint: '',
      triageNotes: '',
    );
  }

  @override
  Future<Map<String, dynamic>> getDoctorStats(String doctorId, {String? period}) async {
    final stats = await _db.getById(_boxAnalytics, doctorId, (json) => Map<String, dynamic>.from(json));
    return stats ?? {
      'doctorId': doctorId,
      'totalPatients': 0,
      'totalAppointments': 0,
      'completionRate': 0,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getDiagnosisDistribution(String doctorId) async {
    final consultations = await _db.getAll(_boxConsultations, Consultation.fromJson);
    final docConsults = consultations.where((c) => c.doctorId == doctorId).toList();
    final diagnosisCount = <String, int>{};
    for (final c in docConsults) {
      if (c.diagnosis.isNotEmpty) {
        diagnosisCount[c.diagnosis] = (diagnosisCount[c.diagnosis] ?? 0) + 1;
      }
    }
    final total = diagnosisCount.values.fold(0, (a, b) => a + b);
    return diagnosisCount.entries.map((e) => {
      'diagnosis': e.key,
      'count': e.value,
      'percentage': total > 0 ? (e.value / total * 100) : 0,
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> getAppointmentCompletion(String doctorId) async {
    final all = await _db.getAll(_boxAppointments, Appointment.fromJson);
    final docAppts = all.where((a) => a.doctorId == doctorId).toList();
    return {
      'total': docAppts.length,
      'completed': docAppts.where((a) => a.status == 'completed').length,
      'cancelled': docAppts.where((a) => a.status == 'cancelled').length,
      'noShow': 0,
      'completionRate': docAppts.isEmpty ? 0 : docAppts.where((a) => a.status == 'completed').length / docAppts.length,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getWeeklyTrends(String doctorId) async {
    final all = await _db.getAll(_boxAppointments, Appointment.fromJson);
    final docAppts = all.where((a) => a.doctorId == doctorId).toList();
    final now = DateTime.now();
    return List.generate(4, (i) {
      final weekStart = now.subtract(Duration(days: 7 * (i + 1)));
      final weekEnd = now.subtract(Duration(days: 7 * i));
      final count = docAppts.where((a) =>
        a.date.isAfter(weekStart) && a.date.isBefore(weekEnd)
      ).length;
      return {
        'week': weekStart.toIso8601String(),
        'appointments': count,
        'newPatients': 0,
      };
    });
  }

  @override
  Future<void> updateLanguage(String language) async {
    final settings = await _db.getById(_boxSettings, 'doctor-1', (json) => Map<String, dynamic>.from(json));
    final updated = Map<String, dynamic>.from(settings ?? {});
    updated['language'] = language;
    await _db.putById(_boxSettings, 'doctor-1', updated, (m) => m);
  }

  @override
  Future<void> updateTheme(String theme) async {
    final settings = await _db.getById(_boxSettings, 'doctor-1', (json) => Map<String, dynamic>.from(json));
    final updated = Map<String, dynamic>.from(settings ?? {});
    updated['theme'] = theme;
    await _db.putById(_boxSettings, 'doctor-1', updated, (m) => m);
  }

  @override
  Future<void> updateNotificationPreferences(Map<String, dynamic> prefs) async {
    final settings = await _db.getById(_boxSettings, 'doctor-1', (json) => Map<String, dynamic>.from(json));
    final updated = Map<String, dynamic>.from(settings ?? {});
    updated['notificationPreferences'] = prefs;
    await _db.putById(_boxSettings, 'doctor-1', updated, (m) => m);
  }

  @override
  Future<void> updateWorkingHours(List<WorkingHour> hours) async {
    final settings = await _db.getById(_boxSettings, 'doctor-1', (json) => Map<String, dynamic>.from(json));
    final updated = Map<String, dynamic>.from(settings ?? {});
    updated['workingHours'] = hours.map((h) => h.toJson()).toList();
    await _db.putById(_boxSettings, 'doctor-1', updated, (m) => m);
  }

  @override
  Future<void> updateAvailability(bool isAvailable) async {
    final settings = await _db.getById(_boxSettings, 'doctor-1', (json) => Map<String, dynamic>.from(json));
    final updated = Map<String, dynamic>.from(settings ?? {});
    updated['isAvailable'] = isAvailable;
    await _db.putById(_boxSettings, 'doctor-1', updated, (m) => m);
  }

  @override
  Future<void> setPinCode(String pin) async {
    final settings = await _db.getById(_boxSettings, 'doctor-1', (json) => Map<String, dynamic>.from(json));
    final updated = Map<String, dynamic>.from(settings ?? {});
    updated['pinCode'] = pin;
    await _db.putById(_boxSettings, 'doctor-1', updated, (m) => m);
  }

  @override
  Future<void> enableBiometric(bool enabled) async {
    final settings = await _db.getById(_boxSettings, 'doctor-1', (json) => Map<String, dynamic>.from(json));
    final updated = Map<String, dynamic>.from(settings ?? {});
    updated['biometricEnabled'] = enabled;
    await _db.putById(_boxSettings, 'doctor-1', updated, (m) => m);
  }

  @override
  Future<void> enableOfflineMode(bool enabled) async {
    final settings = await _db.getById(_boxSettings, 'doctor-1', (json) => Map<String, dynamic>.from(json));
    final updated = Map<String, dynamic>.from(settings ?? {});
    updated['offlineModeEnabled'] = enabled;
    await _db.putById(_boxSettings, 'doctor-1', updated, (m) => m);
  }

  @override
  Future<bool> isAuthenticated() async {
    final token = await _secureStorage.read(key: 'access_token');
    return token != null && token.isNotEmpty;
  }

  @override
  Future<void> login(String email, String password) async {
    throw UnimplementedError('Local login is not supported');
  }

  @override
  Future<void> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
  }) async {
    throw UnimplementedError('Local registration is not supported');
  }

  @override
  Future<void> otpLogin(String phone, String code) async {
    throw UnimplementedError('Local login is not supported');
  }

  @override
  Future<void> sendOtp(String phone) async {
    throw UnimplementedError('Local OTP is not supported');
  }

  @override
  Future<bool> verifyOtp(String phone, String code) async {
    throw UnimplementedError('Local OTP is not supported');
  }

  @override
  Future<void> resetPassword(String phone, String code, String newPassword) async {
    throw UnimplementedError('Local password reset is not supported');
  }

  @override
  Future<void> refresh() async {
    throw UnimplementedError('Local refresh is not supported');
  }

  @override
  Future<void> logout() async {
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
  }

  @override
  Future<String?> getToken() async {
    return _secureStorage.read(key: 'access_token');
  }

  @override
  Future<String?> getRefreshToken() async {
    return _secureStorage.read(key: 'refresh_token');
  }

  @override
  Future<String?> getUserId() async {
    return _secureStorage.read(key: 'user_id');
  }

  @override
  Future<void> saveUserId(String userId) async {
    await _secureStorage.write(key: 'user_id', value: userId);
  }
}
