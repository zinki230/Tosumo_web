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
import 'package:dio/dio.dart' as dio_pkg;
import '../../../domain/models/chat_conversation.dart';
import '../../../domain/models/chat_message.dart';
import '../../../domain/models/notification_item.dart';
import '../../../domain/models/emergency_session.dart';
import '../../../domain/models/working_hour.dart';
import '../../services/api_client.dart';
import '../../services/error_mapper.dart';
import 'package:dio/dio.dart';
import '../../services/token_storage_service.dart';
import '../../network/doctor_api_endpoints.dart';
import '../doctor_response_mapper.dart';

class RemoteDoctorRepository implements
    DoctorRepository, PatientRepository, AppointmentRepository,
    ConsultationRepository, PrescriptionRepository, LaboratoryRepository,
    ImagingRepository, ChatRepository, NotificationRepository,
    EmergencyRepository, AnalyticsRepository, SettingsRepository, AuthRepository {
  final ApiClient _client;
  final TokenStorageService _storage;

  RemoteDoctorRepository(this._client, this._storage);

  static String _plus30(String time) {
    final parts = time.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final total = h * 60 + m + 30;
    final hh = (total ~/ 60).toString().padLeft(2, '0');
    final mm = (total % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  // ---- DoctorRepository ----

  @override
  Future<Doctor> getProfile(String doctorId) async {
    final response = await _client.dio.get(DoctorApiEndpoints.doctorProfile);
    return Doctor.fromJson(DoctorResponseMapper.doctorFromBackend(response.data as Map<String, dynamic>));
  }

  @override
  Future<Doctor> updateProfile(Doctor doctor) async {
    final response = await _client.dio.put(
      DoctorApiEndpoints.doctorProfile,
      data: _profilePayload(doctor),
    );
    return Doctor.fromJson(DoctorResponseMapper.doctorFromBackend(response.data as Map<String, dynamic>));
  }

  Map<String, dynamic> _profilePayload(Doctor doctor) {
    return {
      'title': null,
      'firstName': doctor.name.split(' ').first,
      'lastName': doctor.name.split(' ').length > 1 ? doctor.name.split(' ').sublist(1).join(' ') : '',
      'specialty': doctor.specialty,
      'bio': doctor.credentials.join(', '),
      'profilePhotoUrl': doctor.photoUrl.isEmpty ? null : doctor.photoUrl,
      'consultationFee': null,
      'languages': doctor.languages,
      'city': null,
      'region': null,
    }..removeWhere((_, v) => v == null);
  }

  @override
  Future<DashboardStats> getDashboardStats(String doctorId) async {
    final response = await _client.dio.get(DoctorApiEndpoints.doctorDashboard);
    return DashboardStats.fromJson(
      DoctorResponseMapper.dashboardStatsFromBackend(response.data as Map<String, dynamic>),
    );
  }

  @override
  Future<List<Appointment>> getTodayAppointments(String doctorId) async {
    final all = await getAppointments(doctorId);
    final now = DateTime.now();
    return all.where((a) {
      final d = a.date;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();
  }

  @override
  Future<List<Appointment>> getWeeklyAppointments(String doctorId) async {
    final all = await getAppointments(doctorId);
    final now = DateTime.now();
    final weekEnd = now.add(const Duration(days: 7));
    return all.where((a) {
      final d = a.date;
      return !d.isBefore(now) && d.isBefore(weekEnd);
    }).toList();
  }

  // ---- PatientRepository ----

  @override
  Future<List<PatientSummary>> searchPatients(String query) async {
    final response = await _client.dio.get(
      DoctorApiEndpoints.doctorPatientsSearch,
      queryParameters: {'query': query},
    );
    return (response.data as List)
        .map((e) => PatientSummary.fromJson(DoctorResponseMapper.patientSummaryFromBackend(e as Map<String, dynamic>)))
        .toList();
  }

  @override
  Future<List<PatientSummary>> searchByFilters({
    String? name, String? nationalId, String? phone, String? medicalId,
  }) async {
    final query = [name, phone, nationalId, medicalId]
        .where((v) => v != null && v.trim().isNotEmpty)
        .join(' ');
    return searchPatients(query);
  }

  @override
  Future<PatientDetail> getPatientById(String patientId) async {
    final response = await _client.dio.get(DoctorApiEndpoints.patient(patientId));
    return PatientDetail.fromJson(DoctorResponseMapper.patientDetailFromBackend(response.data as Map<String, dynamic>));
  }

  @override
  Future<PatientDetail> getPatientByQrCode(String qrData) async {
    // The patient app now emits a signed QR token. Send it as `token`; fall
    // back to `cardNumber` for legacy raw-number QR codes.
    final isToken = qrData.contains('.') && qrData.split('.').length == 3;
    final response = await _client.dio.get(
      DoctorApiEndpoints.doctorPatientsQr,
      queryParameters: isToken ? {'token': qrData} : {'cardNumber': qrData},
    );
    final data = response.data as Map<String, dynamic>;
    final patient = data['patient'] as Map<String, dynamic>? ?? data;
    return PatientDetail.fromJson(DoctorResponseMapper.patientDetailFromBackend(patient));
  }

  @override
  Future<void> grantPatientAccess(String patientId, String doctorUserId) async {
    try {
      await _client.dio.post(
        DoctorApiEndpoints.accessGrant,
        data: {
          'patientId': patientId,
          'doctorUserId': doctorUserId,
          'accessLevel': 'full',
          'accessType': 'temporary',
          'reason': 'Accès suite au scan QR et code vérifié',
        },
      );
    } on DioException {
      // Best-effort: the unlock flow must not be blocked if granting fails.
    }
  }

  @override
  Future<PatientDetail> updatePatientVitals(String patientId, PatientVitalsUpdate update) async {
    final payload = <String, dynamic>{
      'bloodType': update.bloodType,
      'allergies': update.allergies,
      'chronicDiseases': update.chronicConditions,
      'currentMeds': update.currentMeds,
      if (update.emergencyContact != null)
        'emergencyContact': {
          'name': update.emergencyContact!.name,
          'relationship': update.emergencyContact!.relationship,
          'phone': update.emergencyContact!.phone,
        },
      'isVerified': true,
      'verifiedBy': update.signedByDoctorId,
      'verifiedByName': update.signedByDoctorName,
      'signed': update.signed,
    };
    try {
      final response = await _client.dio.put(
        DoctorApiEndpoints.patient(patientId),
        data: payload,
      );
      final data = response.data as Map<String, dynamic>?;
      if (data != null) {
        return PatientDetail.fromJson(DoctorResponseMapper.patientDetailFromBackend(data));
      }
    } on DioException {
      // Best-effort: the backend may not yet expose this endpoint. We still
      // reflect the doctor-entered vitals locally so the card can be verified.
    }
    return PatientDetail(
      id: patientId,
      name: '',
      dateOfBirth: DateTime(1900),
      nationalId: '',
      bloodType: update.bloodType ?? '',
      gender: '',
      allergies: update.allergies,
      chronicConditions: update.chronicConditions,
      currentMeds: update.currentMeds,
      emergencyContact: update.emergencyContact,
      verified: true,
      lastVisit: DateTime.now(),
    );
  }

  @override
  Future<List<PatientSummary>> getRecentPatients(String doctorId) async {
    final response = await _client.dio.get(DoctorApiEndpoints.doctorPatients);
    return (response.data as List)
        .map((e) => PatientSummary.fromJson(DoctorResponseMapper.patientSummaryFromBackend(e as Map<String, dynamic>)))
        .toList();
  }

  @override
  Future<void> toggleFavorite(String patientId, bool favorite) async {
    throw UnsupportedError('Favorites are managed locally on this device');
  }

  // ---- AppointmentRepository ----

  @override
  Future<List<Appointment>> getAppointments(String doctorId, {String? status, int? page, int? limit}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    final response = await _client.dio.get(
      DoctorApiEndpoints.doctorAppointments,
      queryParameters: params,
    );
    return (response.data as List)
        .map((e) => Appointment.fromJson(DoctorResponseMapper.appointmentFromBackend(e as Map<String, dynamic>)))
        .toList();
  }

  @override
  Future<Appointment> getAppointment(String id) async {
    final response = await _client.dio.get(DoctorApiEndpoints.appointment(id));
    return Appointment.fromJson(DoctorResponseMapper.appointmentFromBackend(response.data as Map<String, dynamic>));
  }

  @override
  Future<void> approveAppointment(String id) async {
    await _client.dio.put(DoctorApiEndpoints.appointmentApprove(id));
  }

  @override
  Future<void> rejectAppointment(String id, {String? reason}) async {
    await _client.dio.put(
      DoctorApiEndpoints.appointmentCancel(id),
      data: {'reason': reason},
    );
  }

  @override
  Future<void> rescheduleAppointment(String id, DateTime newDate, String newTimeSlot) async {
    await _client.dio.put(
      DoctorApiEndpoints.appointmentReschedule(id),
      data: {
        'appointmentDate': newDate.toIso8601String(),
        'startTime': newTimeSlot,
        'endTime': _plus30(newTimeSlot),
      },
    );
  }

  @override
  Future<void> completeAppointment(String id) async {
    await _client.dio.put(DoctorApiEndpoints.appointmentComplete(id));
  }

  @override
  Future<void> cancelAppointment(String id, {String? reason}) async {
    await _client.dio.put(
      DoctorApiEndpoints.appointmentCancel(id),
      data: {'reason': reason},
    );
  }

  @override
  Future<void> markNoShow(String id) async {
    await _client.dio.put(DoctorApiEndpoints.appointmentNoShow(id));
  }

  @override
  Future<Appointment> bookAppointment(
    String patientId, String doctorId, DateTime date, String timeSlot, String type,
  ) async {
    throw UnsupportedError('Appointments are booked by patients through the patient app');
  }

  // ---- ConsultationRepository ----

  @override
  Future<Consultation> createConsultation(Consultation consultation) async {
    final response = await _client.dio.post(
      DoctorApiEndpoints.consultations,
      data: consultationToPayload(consultation),
    );
    return Consultation.fromJson(DoctorResponseMapper.consultationFromBackend(response.data as Map<String, dynamic>));
  }

  @override
  Future<Consultation> getConsultation(String id) async {
    final response = await _client.dio.get(DoctorApiEndpoints.consultation(id));
    return Consultation.fromJson(DoctorResponseMapper.consultationFromBackend(response.data as Map<String, dynamic>));
  }

  @override
  Future<List<Consultation>> getPatientConsultations(String patientId) async {
    final records = await _patientRecords(patientId);
    return (records['consultations'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => Consultation.fromJson(DoctorResponseMapper.consultationFromBackend(e as Map<String, dynamic>)))
        .toList();
  }

  @override
  Future<List<Consultation>> getMyConsultations() async {
    final response = await _client.dio.get(DoctorApiEndpoints.consultations);
    return (response.data as List)
        .map((e) => Consultation.fromJson(DoctorResponseMapper.consultationFromBackend(e as Map<String, dynamic>)))
        .toList();
  }

  @override
  Future<Consultation> updateDraft(String id, Consultation consultation) async {
    final response = await _client.dio.put(
      DoctorApiEndpoints.consultation(id),
      data: consultationToPayload(consultation),
    );
    return Consultation.fromJson(DoctorResponseMapper.consultationFromBackend(response.data as Map<String, dynamic>));
  }

  @override
  Future<Consultation> finalizeConsultation(String id) async {
    final current = await getConsultation(id);
    return updateDraft(id, current);
  }

  @override
  Future<Consultation> signConsultation(String id) async {
    final current = await getConsultation(id);
    return updateDraft(id, current);
  }

  @override
  Future<String> generatePdf(String id) async {
    throw UnsupportedError('PDF generation is performed locally on this device');
  }

  @override
  Future<void> saveVitalSigns(String consultationId, VitalSigns vitals) async {
    final current = await getConsultation(consultationId);
    await _client.dio.put(
      DoctorApiEndpoints.consultation(consultationId),
      data: consultationToPayload(current, vitalsOverride: vitals),
    );
  }

  Map<String, dynamic> consultationToPayload(Consultation c, {VitalSigns? vitalsOverride}) {
    return {
      'patientId': c.patientId,
      'appointmentId': c.appointmentId.isEmpty ? null : c.appointmentId,
      'consultationType': c.consultationType,
      'facility': c.facility.isEmpty ? null : c.facility,
      'chiefComplaint': c.chiefComplaint.isEmpty ? c.diagnosis : c.chiefComplaint,
      'historyOfPresentIllness': c.clinicalNotes,
      'diagnosis': c.diagnosis,
      'differentialDiagnosis': c.differentialDiagnosis.isEmpty ? null : c.differentialDiagnosis,
      'doctorNotes': c.doctorNotes.isEmpty ? null : c.doctorNotes,
      'recommendations': c.recommendations.isEmpty ? null : c.recommendations,
      'symptoms': c.symptoms,
      'vitalSigns': vitalsOverride?.toJson() ?? c.vitals?.toJson(),
      'assessment': c.treatment,
      'plan': c.followUpPlan,
      'notes': c.clinicalNotes,
      'orderedExams': c.orderedExams,
      'signature': c.signature,
      'status': c.status,
    }..removeWhere((_, v) => v == null);
  }

  // ---- PrescriptionRepository ----

  @override
  Future<Prescription> createPrescription(Prescription prescription) async {
    final firstMed = prescription.medications.isNotEmpty ? prescription.medications.first : null;
    final response = await _client.dio.post(
      DoctorApiEndpoints.prescriptions,
      data: {
        'patientId': prescription.patientId,
        'medicationName': firstMed?.drugName ?? '',
        'dosage': firstMed?.dosage ?? '',
        'frequency': firstMed?.frequency ?? '',
        'duration': firstMed?.duration ?? '',
        'route': firstMed?.route,
        'instructions': prescription.notes.isEmpty ? firstMed?.instructions : prescription.notes,
        'signature': prescription.signature,
        'signedAt': prescription.signedAt,
      }..removeWhere((_, v) => v == null),
    );
    return Prescription.fromJson(DoctorResponseMapper.prescriptionFromBackend(response.data as Map<String, dynamic>));
  }

  /// Uploads a file (lab/test result) to the backend and returns its served URL.
  Future<String?> uploadFile(String filePath) async {
    try {
      final formData = dio_pkg.FormData.fromMap({
        'file': await dio_pkg.MultipartFile.fromFile(filePath),
      });
      final response = await _client.dio.post(
        DoctorApiEndpoints.upload,
        data: formData,
      );
      final data = response.data as Map<String, dynamic>;
      final inner = data['data'] as Map<String, dynamic>?;
      return inner?['url'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Prescription> getPrescription(String id) async {
    final response = await _client.dio.get(DoctorApiEndpoints.prescription(id));
    return Prescription.fromJson(DoctorResponseMapper.prescriptionFromBackend(response.data as Map<String, dynamic>));
  }

  @override
  Future<List<Prescription>> getPatientPrescriptions(String patientId) async {
    final records = await _patientRecords(patientId);
    return (records['prescriptions'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => Prescription.fromJson(DoctorResponseMapper.prescriptionFromBackend(e as Map<String, dynamic>)))
        .toList();
  }

  @override
  Future<Prescription> renewPrescription(String id) async {
    throw UnsupportedError('Prescription renewal is not supported by the backend');
  }

  @override
  Future<void> cancelPrescription(String id) async {
    throw UnsupportedError('Prescription cancellation is not supported by the backend');
  }

  // ---- LaboratoryRepository (backend entity: LabResult) ----

  @override
  Future<LabRequest> createLabRequest(LabRequest request) async {
    final response = await _client.dio.post(
      DoctorApiEndpoints.labResults,
      data: {
        'patientId': request.patientId,
        'testName': request.testName,
        'testCategory': request.testType,
        'resultData': request.resultValue.isEmpty ? null : {'value': request.resultValue},
        'resultFileUrl': null,
        'laboratoryName': null,
        'notes': request.notes.isEmpty ? null : request.notes,
        'signature': request.signature,
        'signedAt': request.signedAt,
      }..removeWhere((_, v) => v == null),
    );
    return LabRequest.fromJson(DoctorResponseMapper.labRequestFromBackend(response.data as Map<String, dynamic>));
  }

  @override
  Future<LabRequest> getLabRequest(String id) async {
    final response = await _client.dio.get(DoctorApiEndpoints.labResult(id));
    return LabRequest.fromJson(DoctorResponseMapper.labRequestFromBackend(response.data as Map<String, dynamic>));
  }

  @override
  Future<List<LabRequest>> getPatientLabRequests(String patientId) async {
    final records = await _patientRecords(patientId);
    return (records['labResults'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => LabRequest.fromJson(DoctorResponseMapper.labRequestFromBackend(e as Map<String, dynamic>)))
        .toList();
  }

  @override
  Future<List<LabRequest>> getPendingRequests(String doctorId) async {
    final response = await _client.dio.get(DoctorApiEndpoints.labResults);
    return (response.data as List)
        .map((e) => LabRequest.fromJson(DoctorResponseMapper.labRequestFromBackend(e as Map<String, dynamic>)))
        .where((r) => r.status == 'pending' || r.resultValue.isEmpty)
        .toList();
  }

  @override
  Future<List<LabRequest>> getAllLabRequests(String doctorId) async {
    final response = await _client.dio.get(DoctorApiEndpoints.labResults);
    return (response.data as List)
        .map((e) => LabRequest.fromJson(DoctorResponseMapper.labRequestFromBackend(e as Map<String, dynamic>)))
        .toList();
  }

  @override
  Future<void> updateLabResults(String id, {String? resultValue, String? interpretation, String? status}) async {
    await _client.dio.put(
      DoctorApiEndpoints.labResult(id),
      data: {
        'resultData': resultValue != null ? {'value': resultValue, 'interpretation': interpretation} : null,
        'notes': interpretation,
        'status': _mapLabStatusForBackend(status),
      }..removeWhere((_, v) => v == null),
    );
  }

  // ---- ImagingRepository (backend entity: ImagingResult) ----

  @override
  Future<ImagingRequest> createImagingRequest(ImagingRequest request) async {
    final response = await _client.dio.post(
      DoctorApiEndpoints.imagingResults,
      data: {
        'patientId': request.patientId,
        'imagingType': request.imagingType,
        'bodyPart': request.bodyPart.isEmpty ? null : request.bodyPart,
        'imageUrls': request.attachments
            .map((a) => a['url'] as String? ?? '')
            .where((u) => u.isNotEmpty)
            .toList(),
        'reportText': request.findings,
        'reportFileUrl': null,
        'facilityName': null,
        'notes': request.notes.isEmpty ? null : request.notes,
        'signature': request.signature,
        'signedAt': request.signedAt,
      }..removeWhere((_, v) => v == null),
    );
    return ImagingRequest.fromJson(DoctorResponseMapper.imagingRequestFromBackend(response.data as Map<String, dynamic>));
  }

  @override
  Future<ImagingRequest> getImagingRequest(String id) async {
    final response = await _client.dio.get(DoctorApiEndpoints.imagingResult(id));
    return ImagingRequest.fromJson(DoctorResponseMapper.imagingRequestFromBackend(response.data as Map<String, dynamic>));
  }

  @override
  Future<List<ImagingRequest>> getPatientImagingRequests(String patientId) async {
    final records = await _patientRecords(patientId);
    return (records['imagingResults'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => ImagingRequest.fromJson(DoctorResponseMapper.imagingRequestFromBackend(e as Map<String, dynamic>)))
        .toList();
  }

  @override
  Future<List<ImagingRequest>> getPendingImagingRequests(String doctorId) async {
    final response = await _client.dio.get(DoctorApiEndpoints.imagingResults);
    return (response.data as List)
        .map((e) => ImagingRequest.fromJson(DoctorResponseMapper.imagingRequestFromBackend(e as Map<String, dynamic>)))
        .where((r) => r.status == 'pending' || r.findings.isEmpty)
        .toList();
  }

  @override
  Future<List<ImagingRequest>> getAllImagingRequests(String doctorId) async {
    final response = await _client.dio.get(DoctorApiEndpoints.imagingResults);
    return (response.data as List)
        .map((e) => ImagingRequest.fromJson(DoctorResponseMapper.imagingRequestFromBackend(e as Map<String, dynamic>)))
        .toList();
  }

  @override
  Future<void> updateImagingResults(String id, {String? findings, String? impression, String? status}) async {
    await _client.dio.put(
      DoctorApiEndpoints.imagingResult(id),
      data: {
        'reportText': findings,
        'notes': impression,
        'status': _mapImagingStatusForBackend(status),
      }..removeWhere((_, v) => v == null),
    );
  }

  static String? _mapLabStatusForBackend(String? status) {
    switch (status) {
      case 'completed': return 'completed';
      case 'cancelled': return 'cancelled';
      case 'pending': return 'ordered';
      default: return status;
    }
  }

  static String? _mapImagingStatusForBackend(String? status) {
    switch (status) {
      case 'completed': return 'completed';
      case 'cancelled': return 'cancelled';
      case 'pending': return 'ordered';
      default: return status;
    }
  }

  Future<Map<String, dynamic>> _patientRecords(String patientId) async {
    final response = await _client.dio.get(DoctorApiEndpoints.medicalRecordsPatient(patientId));
    return response.data as Map<String, dynamic>;
  }

  // ---- ChatRepository ----

  @override
  Future<List<ChatConversation>> getConversations(String doctorId) async {
    final response = await _client.dio.get(DoctorApiEndpoints.chat);
    return (response.data as List)
        .map((e) => ChatConversation.fromJson(DoctorResponseMapper.conversationFromBackend(e as Map<String, dynamic>)))
        .toList();
  }

  @override
  Future<List<ChatMessage>> getMessages(String conversationId, {int? page, int? limit}) async {
    final params = <String, dynamic>{};
    if (limit != null) params['limit'] = limit;
    final response = await _client.dio.get(
      DoctorApiEndpoints.chatMessages(conversationId),
      queryParameters: params,
    );
    return (response.data as List)
        .map((e) => ChatMessage.fromJson(DoctorResponseMapper.messageFromBackend(e as Map<String, dynamic>)))
        .toList();
  }

  @override
  Future<ChatMessage> sendMessage(String conversationId, String text, {String? type, Map<String, dynamic>? metadata}) async {
    final response = await _client.dio.post(
      DoctorApiEndpoints.chatMessages(conversationId),
      data: {
        'content': text,
        'messageType': type ?? 'text',
      },
    );
    return ChatMessage.fromJson(DoctorResponseMapper.messageFromBackend(response.data as Map<String, dynamic>));
  }

  @override
  Future<void> markChatRead(String conversationId) async {
    await _client.dio.put(DoctorApiEndpoints.chatMarkRead(conversationId));
  }

  @override
  Future<void> markMessageDelivered(String messageId) async {
    throw UnsupportedError('Message delivery status is not supported by the backend');
  }

  // ---- NotificationRepository ----

  @override
  Future<List<NotificationItem>> getNotifications(String doctorId) async {
    final response = await _client.dio.get(DoctorApiEndpoints.notifications);
    return (response.data as List)
        .map((e) => NotificationItem.fromJson(DoctorResponseMapper.notificationFromBackend(e as Map<String, dynamic>)))
        .toList();
  }

  @override
  Future<List<NotificationItem>> getUnreadNotifications(String doctorId) async {
    final response = await _client.dio.get(DoctorApiEndpoints.notificationUnread);
    return (response.data as List)
        .map((e) => NotificationItem.fromJson(DoctorResponseMapper.notificationFromBackend(e as Map<String, dynamic>)))
        .toList();
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _client.dio.put(DoctorApiEndpoints.notificationRead(notificationId));
  }

  @override
  Future<void> markAllAsRead() async {
    await _client.dio.put(DoctorApiEndpoints.notificationReadAll);
  }

  // ---- EmergencyRepository ----

  @override
  Future<EmergencySession?> getActiveSession(String doctorId) async {
    try {
      final response = await _client.dio.get(DoctorApiEndpoints.emergencyActiveSession);
      final data = response.data;
      if (data == null) return null;
      return EmergencySession.fromJson(DoctorResponseMapper.emergencySessionFromBackend(data as Map<String, dynamic>));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<EmergencySession>> getEmergencyHistory(String doctorId) async {
    final response = await _client.dio.get(DoctorApiEndpoints.emergencySessions);
    return (response.data as List)
        .map((e) => EmergencySession.fromJson(DoctorResponseMapper.emergencySessionFromBackend(e as Map<String, dynamic>)))
        .toList();
  }

  @override
  Future<EmergencySession> startEmergencySession(String patientId, String doctorId, String justification) async {
    final response = await _client.dio.post(
      DoctorApiEndpoints.emergencySessions,
      data: {'patientId': patientId, 'justification': justification},
    );
    return EmergencySession.fromJson(DoctorResponseMapper.emergencySessionFromBackend(response.data as Map<String, dynamic>));
  }

  @override
  Future<void> completeEmergencySession(String sessionId) async {
    await _client.dio.patch(
      DoctorApiEndpoints.emergencySession(sessionId),
      data: {'status': 'resolved'},
    );
  }

  @override
  Future<EmergencyPatientSummary> getEmergencyPatientSummary(String patientId) async {
    final response = await _client.dio.get(DoctorApiEndpoints.emergencyCriticalInfo(patientId));
    return EmergencyPatientSummary.fromJson(
      DoctorResponseMapper.criticalInfoFromBackend(response.data as Map<String, dynamic>),
    );
  }

  // ---- AnalyticsRepository (backend: /doctors/stats) ----

  @override
  Future<Map<String, dynamic>> getDoctorStats(String doctorId, {String? period}) async {
    final response = await _client.dio.get(DoctorApiEndpoints.doctorStats);
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> getDiagnosisDistribution(String doctorId) async {
    throw UnsupportedError('Diagnosis distribution is not provided by the backend');
  }

  @override
  Future<Map<String, dynamic>> getAppointmentCompletion(String doctorId) async {
    throw UnsupportedError('Appointment completion analytics are not provided by the backend');
  }

  @override
  Future<List<Map<String, dynamic>>> getWeeklyTrends(String doctorId) async {
    throw UnsupportedError('Weekly trends are not provided by the backend');
  }

  // ---- SettingsRepository (backend: doctors availability/working-hours; rest is local) ----

  @override
  Future<void> updateLanguage(String language) async {
    throw UnsupportedError('Language preference is stored locally');
  }

  @override
  Future<void> updateTheme(String theme) async {
    throw UnsupportedError('Theme preference is stored locally');
  }

  @override
  Future<void> updateNotificationPreferences(Map<String, dynamic> prefs) async {
    throw UnsupportedError('Notification preferences are stored locally');
  }

  @override
  Future<void> updateWorkingHours(List<WorkingHour> hours) async {
    await _client.dio.put(
      DoctorApiEndpoints.doctorAvailability,
      data: hours.map((h) => {
        'dayOfWeek': h.dayOfWeek,
        'startTime': h.startTime,
        'endTime': h.endTime,
        'isAvailable': h.isAvailable,
        'slotDuration': 30,
      }).toList(),
    );
  }

  @override
  Future<void> updateAvailability(bool isAvailable) async {
    await _client.dio.put(
      DoctorApiEndpoints.doctorAvailabilityStatus,
      data: {'isAvailable': isAvailable},
    );
  }

  @override
  Future<void> setPinCode(String pin) async {
    throw UnsupportedError('PIN is stored locally');
  }

  @override
  Future<void> enableBiometric(bool enabled) async {
    throw UnsupportedError('Biometric preference is stored locally');
  }

  @override
  Future<void> enableOfflineMode(bool enabled) async {
    throw UnsupportedError('Offline preference is stored locally');
  }

  // ---- AuthRepository ----

  @override
  Future<void> login(String identifier, String password) async {
    final isEmail = identifier.contains('@');
    final response = await _client.dio.post(DoctorApiEndpoints.login, data: isEmail
        ? {'email': identifier, 'password': password}
        : {'phone': identifier, 'password': password});
    await _persistAuth(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
  }) async {
    await _client.dio.post(DoctorApiEndpoints.register, data: {
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'password': password,
      'role': 'doctor',
    });
    // Don't persist auth after register, let user login manually
  }

  @override
  Future<void> otpLogin(String phone, String code) async {
    final response = await _client.dio.post(DoctorApiEndpoints.otpLogin, data: {
      'phone': phone,
      'code': code,
    });
    await _persistAuth(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> sendOtp(String phone) async {
    if (DoctorApiEndpoints.isDemoMode) return;
    await _client.dio.post(DoctorApiEndpoints.sendOtp, data: {'phone': phone});
  }

  @override
  Future<bool> verifyOtp(String phone, String code) async {
    if (DoctorApiEndpoints.isDemoMode) {
      // No real SMS provider yet: accept the fixed demo code (or any code if
      // running purely against the local mock backend).
      return code == DoctorApiEndpoints.demoOtpCode || code.isNotEmpty;
    }
    try {
      // NOTE: we intentionally discard the returned tokens so the doctor's
      // own session is never replaced by the patient's.
      await _client.dio.post(DoctorApiEndpoints.verifyOtp, data: {
        'phone': phone,
        'code': code,
      });
      return true;
    } on DioException {
      return false;
    }
  }

  @override
  Future<void> resetPassword(String phone, String code, String newPassword) async {
    await _client.dio.post(DoctorApiEndpoints.resetPassword, data: {
      'phone': phone,
      'code': code,
      'newPassword': newPassword,
    });
  }

  @override
  Future<void> refresh() async {
    await _storage.runRefreshLocked(() async {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        throw const AuthFailure(message: 'No refresh token available');
      }
      final response = await _client.dio.post(
        DoctorApiEndpoints.refresh,
        data: {'refreshToken': refreshToken},
      );
      // The response unwrapper already strips the {success, data} envelope,
      // so the payload is either {tokens: {...}} (interop) or the flat token
      // map {accessToken, refreshToken} returned by /auth/refresh.
      final data = response.data as Map<String, dynamic>;
      final nested = data['tokens'] as Map<String, dynamic>?;
      final accessToken = (nested?['accessToken'] ?? data['accessToken']) as String?;
      final newRefreshToken = (nested?['refreshToken'] ?? data['refreshToken']) as String?;
      if (accessToken == null || newRefreshToken == null) {
        throw const AuthFailure(message: 'Invalid refresh response');
      }
      await _storage.saveTokens(accessToken: accessToken, refreshToken: newRefreshToken);
    });
  }

  Future<void> _persistAuth(Map<String, dynamic> data) async {
    final user = data['user'] as Map<String, dynamic>?;
    final tokens = data['tokens'] as Map<String, dynamic>?;
    final accessToken = tokens?['accessToken'] as String? ?? data['accessToken'] as String?;
    final refreshToken = tokens?['refreshToken'] as String? ?? data['refreshToken'] as String?;
    if (accessToken == null || refreshToken == null) {
      throw const AuthFailure(message: 'Invalid authentication response');
    }
    await _storage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
    final userId = user?['id'] as String?;
    if (userId != null) {
      await _storage.saveUserId(userId);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _client.dio.post(DoctorApiEndpoints.logout);
    } catch (_) {}
    await _storage.clearTokens();
  }

  @override
  Future<bool> isAuthenticated() async {
    return _storage.hasTokens();
  }

  @override
  Future<String?> getToken() async {
    return _storage.getAccessToken();
  }

  @override
  Future<String?> getRefreshToken() async {
    return _storage.getRefreshToken();
  }

  @override
  Future<String?> getUserId() async {
    return _storage.getUserId();
  }

  @override
  Future<void> saveUserId(String userId) async {
    await _storage.saveUserId(userId);
  }
}
