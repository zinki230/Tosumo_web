import 'dart:async';
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
import '../../database/sync_queue.dart';
import 'local_doctor_repository.dart';
import 'remote_doctor_repository.dart';

class RepositoryCoordinator implements
    DoctorRepository, PatientRepository, AppointmentRepository,
    ConsultationRepository, PrescriptionRepository, LaboratoryRepository,
    ImagingRepository, ChatRepository, NotificationRepository,
    EmergencyRepository, AnalyticsRepository, SettingsRepository, AuthRepository {
  final LocalDoctorRepository _local;
  final RemoteDoctorRepository _remote;
  final SyncQueue _syncQueue;

  bool _online = true;
  final StreamController<bool> _onlineController = StreamController<bool>.broadcast();

  Stream<bool> get onlineStream => _onlineController.stream;
  bool get isOnline => _online;

  RepositoryCoordinator(this._local, this._remote, this._syncQueue);

  void setOnline(bool value) {
    _online = value;
    _onlineController.add(value);
  }

  Future<T> _fetchWithFallback<T>({
    required Future<T> Function() remote,
    required Future<T> Function() local,
    void Function(T)? cacheLocally,
  }) async {
    if (_online) {
      try {
        final result = await remote().timeout(const Duration(seconds: 10));
        setOnline(true);
        if (cacheLocally != null) cacheLocally(result);
        return result;
      } catch (_) {
        setOnline(false);
      }
    }
    return local();
  }

  void _enqueueSync(String endpoint, Map<String, dynamic> body, {String type = 'POST'}) {
    _syncQueue.enqueue(SyncOperation(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      endpoint: endpoint,
      body: body,
    ));
    if (_online) {
      unawaited(synchronize());
    }
  }

  @override
  Future<Doctor> getProfile(String doctorId) {
    return _fetchWithFallback(
      remote: () => _remote.getProfile(doctorId),
      local: () => _local.getProfile(doctorId),
      cacheLocally: (doctor) => _local.updateProfile(doctor),
    );
  }

  @override
  Future<Doctor> updateProfile(Doctor doctor) async {
    final result = await _local.updateProfile(doctor);
    _enqueueSync('/api/v1/doctors/${doctor.id}', doctor.toJson(), type: 'PUT');
    return result;
  }

  @override
  Future<DashboardStats> getDashboardStats(String doctorId) {
    return _fetchWithFallback(
      remote: () => _remote.getDashboardStats(doctorId),
      local: () => _local.getDashboardStats(doctorId),
    );
  }

  @override
  Future<List<Appointment>> getTodayAppointments(String doctorId) {
    return _fetchWithFallback(
      remote: () => _remote.getTodayAppointments(doctorId),
      local: () => _local.getTodayAppointments(doctorId),
    );
  }

  @override
  Future<List<Appointment>> getWeeklyAppointments(String doctorId) {
    return _fetchWithFallback(
      remote: () => _remote.getWeeklyAppointments(doctorId),
      local: () => _local.getWeeklyAppointments(doctorId),
    );
  }

  @override
  Future<List<PatientSummary>> searchPatients(String query) {
    return _fetchWithFallback(
      remote: () => _remote.searchPatients(query),
      local: () => _local.searchPatients(query),
    );
  }

  @override
  Future<List<PatientSummary>> searchByFilters({
    String? name, String? nationalId, String? phone, String? medicalId,
  }) {
    return _fetchWithFallback(
      remote: () => _remote.searchByFilters(name: name, nationalId: nationalId, phone: phone, medicalId: medicalId),
      local: () => _local.searchByFilters(name: name, nationalId: nationalId, phone: phone, medicalId: medicalId),
    );
  }

  @override
  Future<PatientDetail> getPatientById(String patientId) {
    return _fetchWithFallback(
      remote: () => _remote.getPatientById(patientId),
      local: () => _local.getPatientById(patientId),
    );
  }

  @override
  Future<PatientDetail> getPatientByQrCode(String qrData) {
    return _fetchWithFallback(
      remote: () => _remote.getPatientByQrCode(qrData),
      local: () => _local.getPatientByQrCode(qrData),
    );
  }

  @override
  Future<void> grantPatientAccess(String patientId, String doctorUserId) {
    return _remote.grantPatientAccess(patientId, doctorUserId);
  }

  @override
  Future<PatientDetail> updatePatientVitals(String patientId, PatientVitalsUpdate update) {
    return _fetchWithFallback(
      remote: () => _remote.updatePatientVitals(patientId, update),
      local: () => _local.updatePatientVitals(patientId, update),
    );
  }

  @override
  Future<List<PatientSummary>> getRecentPatients(String doctorId) {
    return _fetchWithFallback(
      remote: () => _remote.getRecentPatients(doctorId),
      local: () => _local.getRecentPatients(doctorId),
    );
  }

  @override
  Future<void> toggleFavorite(String patientId, bool favorite) async {
    await _local.toggleFavorite(patientId, favorite);
    _enqueueSync('/api/v1/patients/$patientId/favorite', {'favorite': favorite}, type: 'PATCH');
  }

  @override
  Future<List<Appointment>> getAppointments(String doctorId, {String? status, int? page, int? limit}) {
    return _fetchWithFallback(
      remote: () => _remote.getAppointments(doctorId, status: status, page: page, limit: limit),
      local: () => _local.getAppointments(doctorId, status: status, page: page, limit: limit),
    );
  }

  @override
  Future<Appointment> getAppointment(String id) {
    return _fetchWithFallback(
      remote: () => _remote.getAppointment(id),
      local: () => _local.getAppointment(id),
    );
  }

  @override
  Future<void> approveAppointment(String id) async {
    await _local.approveAppointment(id);
    _enqueueSync('/api/v1/appointments/$id/approve', {}, type: 'PATCH');
  }

  @override
  Future<void> rejectAppointment(String id, {String? reason}) async {
    await _local.rejectAppointment(id, reason: reason);
    _enqueueSync('/api/v1/appointments/$id/reject', {'reason': reason}, type: 'PATCH');
  }

  @override
  Future<void> rescheduleAppointment(String id, DateTime newDate, String newTimeSlot) async {
    await _local.rescheduleAppointment(id, newDate, newTimeSlot);
    _enqueueSync('/api/v1/appointments/$id/reschedule', {
      'date': newDate.toIso8601String(),
      'timeSlot': newTimeSlot,
    }, type: 'PATCH');
  }

  @override
  Future<void> completeAppointment(String id) async {
    await _local.completeAppointment(id);
    _enqueueSync('/api/v1/appointments/$id/complete', {}, type: 'PATCH');
  }

  @override
  Future<void> markNoShow(String id) async {
    await _remote.markNoShow(id);
  }

  @override
  Future<void> cancelAppointment(String id, {String? reason}) async {
    await _local.cancelAppointment(id, reason: reason);
    _enqueueSync('/api/v1/appointments/$id/cancel', {'reason': reason}, type: 'PATCH');
  }

  @override
  Future<Appointment> bookAppointment(String patientId, String doctorId, DateTime date, String timeSlot, String type) async {
    final result = await _local.bookAppointment(patientId, doctorId, date, timeSlot, type);
    _enqueueSync('/api/v1/appointments', {
      'patientId': patientId, 'doctorId': doctorId,
      'date': date.toIso8601String(), 'timeSlot': timeSlot, 'type': type,
    });
    return result;
  }

  @override
  Future<Consultation> createConsultation(Consultation consultation) async {
    final result = await _local.createConsultation(consultation);
    _enqueueSync('/api/v1/consultations', consultation.toJson());
    return result;
  }

  @override
  Future<Consultation> getConsultation(String id) {
    return _fetchWithFallback(
      remote: () => _remote.getConsultation(id),
      local: () => _local.getConsultation(id),
    );
  }

  @override
  Future<List<Consultation>> getPatientConsultations(String patientId) {
    return _fetchWithFallback(
      remote: () => _remote.getPatientConsultations(patientId),
      local: () => _local.getPatientConsultations(patientId),
    );
  }

  @override
  Future<List<Consultation>> getMyConsultations() async {
    return _remote.getMyConsultations();
  }

  @override
  Future<Consultation> updateDraft(String id, Consultation consultation) async {
    final result = await _local.updateDraft(id, consultation);
    _enqueueSync('/api/v1/consultations/$id', consultation.toJson(), type: 'PUT');
    return result;
  }

  @override
  Future<Consultation> finalizeConsultation(String id) async {
    final result = await _local.finalizeConsultation(id);
    _enqueueSync('/api/v1/consultations/$id/finalize', {}, type: 'PATCH');
    return result;
  }

  @override
  Future<Consultation> signConsultation(String id) async {
    final result = await _local.signConsultation(id);
    _enqueueSync('/api/v1/consultations/$id/sign', {}, type: 'PATCH');
    return result;
  }

  @override
  Future<String> generatePdf(String id) {
    return _fetchWithFallback(
      remote: () => _remote.generatePdf(id),
      local: () => _local.generatePdf(id),
    );
  }

  @override
  Future<void> saveVitalSigns(String consultationId, VitalSigns vitals) async {
    await _local.saveVitalSigns(consultationId, vitals);
    _enqueueSync('/api/v1/consultations/$consultationId/vitals', vitals.toJson(), type: 'PATCH');
  }

  @override
  Future<Prescription> createPrescription(Prescription prescription) async {
    final result = await _local.createPrescription(prescription);
    _enqueueSync('/api/v1/medical-records/prescriptions', prescription.toJson());
    return result;
  }

  @override
  Future<Prescription> getPrescription(String id) {
    return _fetchWithFallback(
      remote: () => _remote.getPrescription(id),
      local: () => _local.getPrescription(id),
    );
  }

  @override
  Future<List<Prescription>> getPatientPrescriptions(String patientId) {
    return _fetchWithFallback(
      remote: () => _remote.getPatientPrescriptions(patientId),
      local: () => _local.getPatientPrescriptions(patientId),
    );
  }

  @override
  Future<Prescription> renewPrescription(String id) async {
    final result = await _local.renewPrescription(id);
    _enqueueSync('/api/v1/medical-records/prescriptions/$id/renew', {}, type: 'PATCH');
    return result;
  }

  @override
  Future<void> cancelPrescription(String id) async {
    await _local.cancelPrescription(id);
    _enqueueSync('/api/v1/medical-records/prescriptions/$id/cancel', {}, type: 'PATCH');
  }

  @override
  Future<LabRequest> createLabRequest(LabRequest request) async {
    final result = await _local.createLabRequest(request);
    _enqueueSync('/api/v1/medical-records/lab-results', request.toJson());
    return result;
  }

  @override
  Future<LabRequest> getLabRequest(String id) {
    return _fetchWithFallback(
      remote: () => _remote.getLabRequest(id),
      local: () => _local.getLabRequest(id),
    );
  }

  @override
  Future<List<LabRequest>> getPatientLabRequests(String patientId) {
    return _fetchWithFallback(
      remote: () => _remote.getPatientLabRequests(patientId),
      local: () => _local.getPatientLabRequests(patientId),
    );
  }

  @override
  Future<List<LabRequest>> getPendingRequests(String doctorId) {
    return _fetchWithFallback(
      remote: () => _remote.getPendingRequests(doctorId),
      local: () => _local.getPendingRequests(doctorId),
    );
  }

  @override
  Future<List<LabRequest>> getAllLabRequests(String doctorId) {
    return _fetchWithFallback(
      remote: () => _remote.getAllLabRequests(doctorId),
      local: () => _local.getAllLabRequests(doctorId),
    );
  }

  @override
  Future<void> updateLabResults(String id, {String? resultValue, String? interpretation, String? status}) async {
    await _local.updateLabResults(id, resultValue: resultValue, interpretation: interpretation, status: status);
    _enqueueSync('/api/v1/medical-records/lab-results/$id', {
      'resultValue': resultValue,
      'interpretation': interpretation,
      'status': status,
    }, type: 'PATCH');
  }

  @override
  Future<ImagingRequest> createImagingRequest(ImagingRequest request) async {
    final result = await _local.createImagingRequest(request);
    _enqueueSync('/api/v1/medical-records/imaging-results', request.toJson());
    return result;
  }

  @override
  Future<ImagingRequest> getImagingRequest(String id) {
    return _fetchWithFallback(
      remote: () => _remote.getImagingRequest(id),
      local: () => _local.getImagingRequest(id),
    );
  }

  @override
  Future<List<ImagingRequest>> getPatientImagingRequests(String patientId) {
    return _fetchWithFallback(
      remote: () => _remote.getPatientImagingRequests(patientId),
      local: () => _local.getPatientImagingRequests(patientId),
    );
  }

  @override
  Future<List<ImagingRequest>> getPendingImagingRequests(String doctorId) {
    return _fetchWithFallback(
      remote: () => _remote.getPendingImagingRequests(doctorId),
      local: () => _local.getPendingImagingRequests(doctorId),
    );
  }

  @override
  Future<List<ImagingRequest>> getAllImagingRequests(String doctorId) {
    return _fetchWithFallback(
      remote: () => _remote.getAllImagingRequests(doctorId),
      local: () => _local.getAllImagingRequests(doctorId),
    );
  }

  @override
  Future<void> updateImagingResults(String id, {String? findings, String? impression, String? status}) async {
    await _local.updateImagingResults(id, findings: findings, impression: impression, status: status);
    _enqueueSync('/api/v1/medical-records/imaging-results/$id', {
      'findings': findings,
      'impression': impression,
      'status': status,
    }, type: 'PATCH');
  }

  @override
  Future<List<ChatConversation>> getConversations(String doctorId) {
    return _fetchWithFallback(
      remote: () => _remote.getConversations(doctorId),
      local: () => _local.getConversations(doctorId),
    );
  }

  @override
  Future<List<ChatMessage>> getMessages(String conversationId, {int? page, int? limit}) {
    return _fetchWithFallback(
      remote: () => _remote.getMessages(conversationId, page: page, limit: limit),
      local: () => _local.getMessages(conversationId, page: page, limit: limit),
    );
  }

  @override
  Future<ChatMessage> sendMessage(String conversationId, String text, {String? type, Map<String, dynamic>? metadata}) async {
    final result = await _local.sendMessage(conversationId, text, type: type, metadata: metadata);
    _enqueueSync('/api/v1/chats/$conversationId/messages', {
      'text': text, 'type': type ?? 'text', 'metadata': metadata,
    });
    return result;
  }

  @override
  Future<void> markChatRead(String id) async {
    await _local.markChatRead(id);
    _enqueueSync('/api/v1/chat/$id/read', {}, type: 'PATCH');
  }

  @override
  Future<void> markMessageDelivered(String messageId) async {
    await _local.markMessageDelivered(messageId);
    _enqueueSync('/api/v1/chats/messages/$messageId', {'status': 'delivered'}, type: 'PATCH');
  }

  @override
  Future<List<NotificationItem>> getNotifications(String doctorId) {
    return _fetchWithFallback(
      remote: () => _remote.getNotifications(doctorId),
      local: () => _local.getNotifications(doctorId),
    );
  }

  @override
  Future<List<NotificationItem>> getUnreadNotifications(String doctorId) {
    return _fetchWithFallback(
      remote: () => _remote.getUnreadNotifications(doctorId),
      local: () => _local.getUnreadNotifications(doctorId),
    );
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _local.markAsRead(notificationId);
    _enqueueSync('/api/v1/notifications/$notificationId/read', {}, type: 'PATCH');
  }

  @override
  Future<void> markAllAsRead() async {
    await _local.markAllAsRead();
    _enqueueSync('/api/v1/notifications/read-all', {}, type: 'PATCH');
  }

  @override
  Future<EmergencySession?> getActiveSession(String doctorId) {
    return _fetchWithFallback(
      remote: () => _remote.getActiveSession(doctorId),
      local: () => _local.getActiveSession(doctorId),
    );
  }

  @override
  Future<List<EmergencySession>> getEmergencyHistory(String doctorId) {
    return _fetchWithFallback(
      remote: () => _remote.getEmergencyHistory(doctorId),
      local: () => _local.getEmergencyHistory(doctorId),
    );
  }

  @override
  Future<EmergencySession> startEmergencySession(String patientId, String doctorId, String justification) async {
    final result = await _local.startEmergencySession(patientId, doctorId, justification);
    _enqueueSync('/api/v1/emergency/sessions', {
      'patientId': patientId, 'doctorId': doctorId, 'justification': justification,
    });
    return result;
  }

  @override
  Future<void> completeEmergencySession(String sessionId) async {
    await _local.completeEmergencySession(sessionId);
    try {
      await _remote.completeEmergencySession(sessionId);
    } catch (_) {
      _enqueueSync('/api/v1/emergency/sessions/$sessionId', {'status': 'resolved'}, type: 'PATCH');
      setOnline(false);
    }
  }

  @override
  Future<EmergencyPatientSummary> getEmergencyPatientSummary(String patientId) {
    return _fetchWithFallback(
      remote: () => _remote.getEmergencyPatientSummary(patientId),
      local: () => _local.getEmergencyPatientSummary(patientId),
    );
  }

  @override
  Future<Map<String, dynamic>> getDoctorStats(String doctorId, {String? period}) {
    return _fetchWithFallback(
      remote: () => _remote.getDoctorStats(doctorId, period: period),
      local: () => _local.getDoctorStats(doctorId, period: period),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getDiagnosisDistribution(String doctorId) {
    return _fetchWithFallback(
      remote: () => _remote.getDiagnosisDistribution(doctorId),
      local: () => _local.getDiagnosisDistribution(doctorId),
    );
  }

  @override
  Future<Map<String, dynamic>> getAppointmentCompletion(String doctorId) {
    return _fetchWithFallback(
      remote: () => _remote.getAppointmentCompletion(doctorId),
      local: () => _local.getAppointmentCompletion(doctorId),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getWeeklyTrends(String doctorId) {
    return _fetchWithFallback(
      remote: () => _remote.getWeeklyTrends(doctorId),
      local: () => _local.getWeeklyTrends(doctorId),
    );
  }

  @override
  Future<void> updateLanguage(String language) async {
    await _local.updateLanguage(language);
  }

  @override
  Future<void> updateTheme(String theme) async {
    await _local.updateTheme(theme);
  }

  @override
  Future<void> updateNotificationPreferences(Map<String, dynamic> prefs) async {
    await _local.updateNotificationPreferences(prefs);
  }

  @override
  Future<void> updateWorkingHours(List<WorkingHour> hours) async {
    await _local.updateWorkingHours(hours);
    try {
      await _remote.updateWorkingHours(hours);
    } catch (_) {
      setOnline(false);
    }
  }

  @override
  Future<void> updateAvailability(bool isAvailable) async {
    await _local.updateAvailability(isAvailable);
    try {
      await _remote.updateAvailability(isAvailable);
    } catch (_) {
      setOnline(false);
    }
  }

  @override
  Future<void> setPinCode(String pin) async {
    await _local.setPinCode(pin);
  }

  @override
  Future<void> enableBiometric(bool enabled) async {
    await _local.enableBiometric(enabled);
  }

  @override
  Future<void> enableOfflineMode(bool enabled) async {
    await _local.enableOfflineMode(enabled);
  }

  @override
  Future<bool> isAuthenticated() {
    return _remote.isAuthenticated();
  }

  @override
  Future<void> login(String email, String password) {
    return _remote.login(email, password);
  }

  @override
  Future<void> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
  }) {
    return _remote.register(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      password: password,
    );
  }

  @override
  Future<void> otpLogin(String phone, String code) {
    return _remote.otpLogin(phone, code);
  }

  @override
  Future<void> sendOtp(String phone) {
    return _remote.sendOtp(phone);
  }

  @override
  Future<bool> verifyOtp(String phone, String code) {
    return _remote.verifyOtp(phone, code);
  }

  @override
  Future<void> resetPassword(String phone, String code, String newPassword) {
    return _remote.resetPassword(phone, code, newPassword);
  }

  @override
  Future<void> refresh() {
    return _remote.refresh();
  }

  @override
  Future<void> logout() async {
    await _remote.logout();
    await _local.logout();
  }

  @override
  Future<String?> getToken() {
    return _remote.getToken();
  }

  @override
  Future<String?> getRefreshToken() {
    return _remote.getRefreshToken();
  }

  @override
  Future<String?> getUserId() {
    return _remote.getUserId();
  }

  @override
  Future<void> saveUserId(String userId) {
    return _remote.saveUserId(userId);
  }

  Future<int> synchronize() async {
    if (_syncQueue.isSyncing || !_syncQueue.hasPending) return 0;
    _syncQueue.isSyncing = true;
    int synced = 0;
    final pending = List<SyncOperation>.from(_syncQueue.pending);
    for (final op in pending) {
      try {
        await _executeSyncOp(op);
        _syncQueue.remove(op.id);
        synced++;
        setOnline(true);
      } catch (_) {
        op.retryCount++;
        if (op.retryCount >= 3) {
          _syncQueue.remove(op.id);
        } else {
          setOnline(false);
        }
      }
    }
    _syncQueue.isSyncing = false;
    return synced;
  }

  Future<void> _executeSyncOp(SyncOperation op) async {
    switch (op.type) {
      case 'POST':
        await _clientDioPost(op.endpoint, op.body);
      case 'PUT':
        await _clientDioPut(op.endpoint, op.body);
      case 'PATCH':
        await _clientDioPatch(op.endpoint, op.body);
    }
  }

  Future<void> _clientDioPost(String endpoint, Map<String, dynamic> body) async {
    if (endpoint.startsWith('/api/v1/doctors')) {
      final doctor = Doctor.fromJson(body);
      await _remote.updateProfile(doctor);
    } else if (endpoint.startsWith('/api/v1/appointments')) {
      await _remote.bookAppointment(
        body['patientId'] as String,
        body['doctorId'] as String,
        DateTime.parse(body['date'] as String),
        body['timeSlot'] as String,
        body['type'] as String,
      );
    } else if (endpoint.startsWith('/api/v1/consultations')) {
      final consultation = Consultation.fromJson(body);
      await _remote.createConsultation(consultation);
    } else if (endpoint.startsWith('/api/v1/medical-records/prescriptions')) {
      final prescription = Prescription.fromJson(body);
      await _remote.createPrescription(prescription);
    } else if (endpoint.startsWith('/api/v1/medical-records/lab-results')) {
      final request = LabRequest.fromJson(body);
      await _remote.createLabRequest(request);
    } else if (endpoint.startsWith('/api/v1/medical-records/imaging-results')) {
      final request = ImagingRequest.fromJson(body);
      await _remote.createImagingRequest(request);
    } else if (endpoint.startsWith('/api/v1/chats')) {
      await _remote.sendMessage(
        endpoint.split('/').elementAt(4),
        body['text'] as String,
        type: body['type'] as String?,
        metadata: body['metadata'] as Map<String, dynamic>?,
      );
    } else if (endpoint.startsWith('/api/v1/emergency')) {
      await _remote.startEmergencySession(
        body['patientId'] as String,
        body['doctorId'] as String,
        body['justification'] as String,
      );
    }
  }

  Future<void> _clientDioPut(String endpoint, Map<String, dynamic> body) async {
    if (endpoint.startsWith('/api/v1/doctors')) {
      final doctor = Doctor.fromJson(body);
      await _remote.updateProfile(doctor);
    } else if (endpoint.startsWith('/api/v1/consultations')) {
      final consultation = Consultation.fromJson(body);
      await _remote.updateDraft(endpoint.split('/').last, consultation);
    }
  }

  Future<void> _clientDioPatch(String endpoint, Map<String, dynamic> body) async {
    if (endpoint.startsWith('/api/v1/notifications/read-all')) {
      await _remote.markAllAsRead();
    } else if (endpoint.startsWith('/api/v1/notifications')) {
      final id = endpoint.split('/').elementAt(4);
      await _remote.markAsRead(id);
    } else if (endpoint.contains('/api/v1/chat/') && endpoint.endsWith('/read')) {
      final id = endpoint.split('/').elementAt(4);
      await _remote.markChatRead(id);
    } else if (endpoint.startsWith('/api/v1/settings')) {
      if (body.containsKey('language')) {
        await _remote.updateLanguage(body['language'] as String);
      } else if (body.containsKey('theme')) {
        await _remote.updateTheme(body['theme'] as String);
      } else if (body.containsKey('notificationPreferences')) {
        await _remote.updateNotificationPreferences(body['notificationPreferences'] as Map<String, dynamic>);
      } else if (body.containsKey('workingHours')) {
        await _remote.updateWorkingHours(
          (body['workingHours'] as List).map((e) => WorkingHour.fromJson(e as Map<String, dynamic>)).toList(),
        );
      } else if (body.containsKey('pinCode')) {
        await _remote.setPinCode(body['pinCode'] as String);
      } else if (body.containsKey('biometricEnabled')) {
        await _remote.enableBiometric(body['biometricEnabled'] as bool);
      } else if (body.containsKey('offlineModeEnabled')) {
        await _remote.enableOfflineMode(body['offlineModeEnabled'] as bool);
      }
    } else if (endpoint.contains('/appointments/') && endpoint.endsWith('/approve')) {
      final id = endpoint.split('/').elementAt(4);
      await _remote.approveAppointment(id);
    } else if (endpoint.contains('/appointments/') && endpoint.endsWith('/reject')) {
      final id = endpoint.split('/').elementAt(4);
      await _remote.rejectAppointment(id);
    } else if (endpoint.contains('/appointments/') && endpoint.endsWith('/cancel')) {
      final id = endpoint.split('/').elementAt(4);
      await _remote.cancelAppointment(id, reason: body['cancellationReason'] as String?);
    } else if (endpoint.contains('/appointments/') && endpoint.endsWith('/complete')) {
      final id = endpoint.split('/').elementAt(4);
      await _remote.completeAppointment(id);
    } else if (endpoint.contains('/appointments/') && endpoint.endsWith('/reschedule')) {
      final id = endpoint.split('/').elementAt(4);
      await _remote.rescheduleAppointment(id, DateTime.parse(body['appointmentDate'] as String), body['startTime'] as String);
    } else if (endpoint.contains('/consultations/') && endpoint.endsWith('/finalize')) {
      final id = endpoint.split('/').elementAt(4);
      await _remote.finalizeConsultation(id);
    } else if (endpoint.contains('/consultations/') && endpoint.endsWith('/sign')) {
      final id = endpoint.split('/').elementAt(4);
      await _remote.signConsultation(id);
    } else if (endpoint.contains('/consultations/') && endpoint.endsWith('/vitals')) {
      final id = endpoint.split('/').elementAt(4);
      await _remote.saveVitalSigns(id, VitalSigns.fromJson(body));
    } else if (endpoint.contains('/medical-records/lab-results/')) {
      final id = endpoint.split('/').elementAt(5);
      await _remote.updateLabResults(id, resultValue: body['resultValue'] as String?, interpretation: body['interpretation'] as String?, status: body['status'] as String?);
    } else if (endpoint.contains('/medical-records/imaging-results/')) {
      final id = endpoint.split('/').elementAt(5);
      await _remote.updateImagingResults(id, findings: body['findings'] as String?, impression: body['impression'] as String?, status: body['status'] as String?);
    } else if (endpoint.contains('/medical-records/prescriptions/') && endpoint.endsWith('/renew')) {
      final id = endpoint.split('/').elementAt(5);
      await _remote.renewPrescription(id);
    } else if (endpoint.contains('/medical-records/prescriptions/') && endpoint.endsWith('/cancel')) {
      final id = endpoint.split('/').elementAt(5);
      await _remote.cancelPrescription(id);
    } else if (endpoint.contains('/patients/') && endpoint.endsWith('/favorite')) {
      final id = endpoint.split('/').elementAt(4);
      await _remote.toggleFavorite(id, true);
    } else if (endpoint.startsWith('/api/v1/doctors/availability')) {
      await _remote.updateAvailability(true);
    } else if (endpoint.contains('/api/v1/emergency/sessions/')) {
      final id = endpoint.split('/').elementAt(5);
      await _remote.completeEmergencySession(id);
    }
  }

  void dispose() {
    _onlineController.close();
  }
}
