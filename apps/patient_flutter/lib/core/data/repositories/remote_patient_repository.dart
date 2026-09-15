import 'package:dio/dio.dart';
import '../../domain/repositories/patient_repository.dart';
import '../../network/api_client.dart';
import '../../network/api_endpoints.dart';
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
import '../response_mapper.dart';

class RemotePatientRepository implements PatientRepository {
  final ApiClient _client;

  RemotePatientRepository(this._client);

  Map<String, dynamic> _unwrap(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      if (responseData.containsKey('success') || responseData.containsKey('data')) {
        final data = responseData['data'];
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return data.cast<String, dynamic>();
        if (data is List) return <String, dynamic>{'items': _safeList(data)};
      }
      return responseData;
    }
    if (responseData is Map) return responseData.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _safeList(dynamic list) {
    if (list is List) {
      return list.map((e) => e is Map<String, dynamic> ? e : e is Map ? e.cast<String, dynamic>() : <String, dynamic>{}).toList();
    }
    return [];
  }

  List<Map<String, dynamic>> _unwrapList(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      if (responseData.containsKey('data')) {
        final data = responseData['data'];
        if (data is List) return _safeList(data);
      }
      if (responseData.containsKey('items')) {
        final items = responseData['items'];
        if (items is List) return _safeList(items);
      }
    }
    if (responseData is List) return _safeList(responseData);
    return [];
  }

  @override
  Future<Patient?> getPatientProfile(String patientId) async {
    final response = await _client.get(ApiEndpoints.patientProfile);
    final data = _unwrap(response.data);
    return ResponseMapper.patientFromBackend(data);
  }

  @override
  Future<CardModel?> getCard(String patientId) async {
    final response = await _client.get(ApiEndpoints.patientMedicalCard);
    final data = _unwrap(response.data);
    return ResponseMapper.medicalCardFromBackend(data);
  }

  @override
  Future<List<BookletEntry>> getMedicalBooklet(String patientId) async {
    final response = await _client.get(ApiEndpoints.patientMedicalBooklets);
    return _unwrapList(response.data).map((e) => ResponseMapper.bookletEntryFromBackend(e)).toList();
  }

  @override
  Future<List<AccessGrant>> getAccessGrants(String patientId) async {
    final response = await _client.get(ApiEndpoints.accessPatient);
    return _unwrapList(response.data).map((e) => ResponseMapper.accessGrantFromBackend(e)).toList();
  }

  @override
  Future<List<AuditEvent>> getAuditLog(String patientId) async {
    final response = await _client.get(ApiEndpoints.auditLogs);
    return _unwrapList(response.data).map((e) => AuditEvent.fromJson(e)).toList();
  }

  @override
  Future<List<HealthJourneyEntry>> getHealthJourney(String patientId) async {
    final response = await _client.get(ApiEndpoints.patientJourney);
    return _unwrapList(response.data).map((e) => ResponseMapper.journeyEntryFromBackend(e)).toList();
  }

  @override
  Future<List<DoctorProfile>> getDoctors() async {
    final response = await _client.get(ApiEndpoints.doctors);
    return _unwrapList(response.data).map((e) => ResponseMapper.doctorFromBackend(e)).toList();
  }

  @override
  Future<DoctorProfile?> getDoctorById(String doctorId) async {
    final response = await _client.get(ApiEndpoints.doctor(doctorId));
    return ResponseMapper.doctorFromBackend(_unwrap(response.data));
  }

  @override
  Future<List<HospitalInfo>> getHospitals() async {
    final response = await _client.get(ApiEndpoints.institutions);
    return _unwrapList(response.data).map((e) => HospitalInfo.fromJson(e)).toList();
  }

  @override
  Future<List<ChatConversation>> getChats(String patientId) async {
    final response = await _client.get(ApiEndpoints.chat);
    final items = _unwrapList(response.data);
    return items.map((e) => ResponseMapper.conversationFromBackend(e)).toList();
  }

  @override
  Future<ChatConversation?> getChatById(String chatId) async {
    final response = await _client.get(ApiEndpoints.chatById(chatId));
    return ResponseMapper.conversationFromBackend(_unwrap(response.data));
  }

  @override
  Future<List<NotificationModel>> getNotifications(String patientId) async {
    final response = await _client.get(ApiEndpoints.notifications);
    return _unwrapList(response.data).map((e) => ResponseMapper.notificationFromBackend(e)).toList();
  }

  @override
  Future<List<NotificationModel>> getUnreadNotifications(String patientId) async {
    final response = await _client.get(ApiEndpoints.notificationUnread);
    return _unwrapList(response.data).map((e) => ResponseMapper.notificationFromBackend(e)).toList();
  }

  @override
  Future<AccessGrant> approveAccessRequest(String grantId) async {
    final response = await _client.put(ApiEndpoints.accessApprove(grantId));
    return ResponseMapper.accessGrantFromBackend(_unwrap(response.data));
  }

  @override
  Future<void> revokeAccess(String grantId) async {
    await _client.put(ApiEndpoints.accessRevoke(grantId));
  }

  @override
  Future<CardModel> requestCardReissue(String patientId) async {
    final response = await _client.post(ApiEndpoints.cardReissue, data: {
      'patientId': patientId,
    });
    return ResponseMapper.medicalCardFromBackend(_unwrap(response.data));
  }

  @override
  Future<Patient> registerPatient({
    required String name,
    required String gender,
    required String dateOfBirth,
    required String city,
  }) async {
    final response = await _client.post(ApiEndpoints.patients, data: {
      'name': name,
      'gender': gender,
      'dateOfBirth': dateOfBirth,
      'city': city,
    });
    return ResponseMapper.patientFromBackend(_unwrap(response.data));
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    await _client.put(ApiEndpoints.notificationRead(notificationId));
  }

  @override
  Future<void> markAllNotificationsRead() async {
    await _client.put(ApiEndpoints.notificationReadAll);
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
    final appointment = ResponseMapper.appointmentToBackend(Appointment(
      id: '',
      doctorName: doctorName,
      specialty: specialty,
      location: location,
      date: date,
      doctorId: doctorId,
    ));
    if (startTime.isNotEmpty) appointment['startTime'] = startTime;
    if (endTime.isNotEmpty) appointment['endTime'] = endTime;
    if (reason.isNotEmpty) appointment['reason'] = reason;
    appointment['patientId'] = patientId;
    final response = await _client.post(ApiEndpoints.appointments, data: appointment);
    return _unwrap(response.data);
  }

  @override
  Future<List<Map<String, dynamic>>> getAppointments(String patientId) async {
    final response = await _client.get(ApiEndpoints.patientAppointments);
    return _unwrapList(response.data);
  }

  @override
  Future<List<Map<String, dynamic>>> getAvailableSlots(String doctorId, String date) async {
    final response = await _client.get(
      ApiEndpoints.appointmentAvailableSlots,
      queryParameters: {'doctorId': doctorId, 'date': date},
    );
    return _unwrapList(response.data);
  }

  @override
  Future<List<Map<String, dynamic>>> getPrescriptions(String patientId) async {
    final response = await _client.get(ApiEndpoints.medicalRecordsPrescriptions);
    return _unwrapList(response.data);
  }

  /// Fetches the patient's own medical records aggregate (consultations, labs,
  /// imaging, prescriptions). Used to surface doctor-created consultations in
  /// the patient's medical booklet.
  Future<List<Map<String, dynamic>>> getPatientMedicalRecords(String patientId) async {
    final response = await _client.get(ApiEndpoints.patientMedicalRecords);
    final data = _unwrap(response.data);
    if (data case {'consultations': final List consultations}) {
      return _safeList(consultations);
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>> sendMessage({
    required String chatId,
    required String content,
    String? messageType,
  }) async {
    final response = await _client.post(ApiEndpoints.chatMessages(chatId), data: {
      'content': content,
      'messageType': messageType ?? 'text',
    });
    return _unwrap(response.data);
  }

  @override
  Future<void> markChatAsRead(String chatId) async {
    await _client.put(ApiEndpoints.chatReadById(chatId));
  }

  @override
  Future<void> updatePatient(Map<String, dynamic> data) async {
    await _client.put(ApiEndpoints.patientProfile, data: data);
  }

  @override
  Future<Map<String, dynamic>> triggerSos({
    String? location,
    String? type,
    String? notes,
  }) async {
    final response = await _client.post(ApiEndpoints.emergencySos, data: {
      'type': type ?? 'emergency',
      'message': notes ?? 'SOS Emergency!',
    });
    return _unwrap(response.data);
  }

  @override
  Future<Map<String, dynamic>> getCriticalInfo() async {
    final response = await _client.get(ApiEndpoints.emergencyCriticalInfo);
    return _unwrap(response.data);
  }

  @override
  Future<List<HospitalInfo>> getNearbyHospitals() async {
    final response = await _client.get(ApiEndpoints.emergencyNearbyHospitals);
    return _unwrapList(response.data).map((e) => HospitalInfo.fromJson(e)).toList();
  }

  @override
  Future<AccessGrant> grantAccess({
    required String doctorId,
    required String accessLevel,
    String? reason,
    String? expiresAt,
  }) async {
    final response = await _client.post(ApiEndpoints.accessGrant, data: {
      'doctorId': doctorId,
      'accessLevel': accessLevel,
      'reason': reason,
      'endDate': ?expiresAt,
    });
    return ResponseMapper.accessGrantFromBackend(_unwrap(response.data));
  }

  @override
  Future<void> cancelAppointment(String appointmentId, {String? reason}) async {
    await _client.put(ApiEndpoints.appointmentCancel(appointmentId), data: {
      'reason': ?reason,
    });
  }

  @override
  Future<void> rescheduleAppointment(String appointmentId, {
    required String date,
    required String startTime,
    required String endTime,
    String? reason,
  }) async {
    await _client.put(ApiEndpoints.appointmentReschedule(appointmentId), data: {
      'appointmentDate': date,
      'startTime': startTime,
      'endTime': endTime,
      'reason': ?reason,
    });
  }

  @override
  Future<void> confirmAppointment(String appointmentId) async {
    await _client.put(ApiEndpoints.appointmentConfirm(appointmentId));
  }

  @override
  Future<String?> uploadAvatar(String filePath, {String? patientId}) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'patientId': ?patientId,
    });
    final response = await _client.post(ApiEndpoints.upload, data: formData);
    final data = _unwrap(response.data);
    return data['url'] as String?;
  }

  /// Uploads a lab/test result file and returns its served URL.
  Future<String?> uploadFile(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _client.post(ApiEndpoints.upload, data: formData);
      final data = _unwrap(response.data);
      return data['url'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Fetches a single consultation (includes orderedExams).
  Future<Map<String, dynamic>> getConsultation(String id) async {
    final response = await _client.get(ApiEndpoints.medicalRecordsConsultation(id));
    return _unwrap(response.data);
  }

  /// Patches a consultation (e.g. to attach uploaded exam results).
  Future<void> updateConsultation(String id, Map<String, dynamic> data) async {
    await _client.put(ApiEndpoints.medicalRecordsConsultation(id), data: data);
  }

  @override
  Future<bool> sendOtp({required String phone, String? email}) async {
    try {
      await _client.post(ApiEndpoints.sendOtp, data: {
        'phone': phone,
        'email': ?email,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> verifyOtp({required String phone, required String otp, String? email}) async {
    try {
      await _client.post(ApiEndpoints.verifyOtp, data: {
        'phone': phone,
        'otp': otp,
        'email': ?email,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
