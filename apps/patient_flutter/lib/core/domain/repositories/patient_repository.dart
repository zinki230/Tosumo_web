import '../../../../shared/models/patient.dart';
import '../../../../shared/models/card_model.dart';
import '../../../../shared/models/booklet_entry.dart';
import '../../../../shared/models/access_grant.dart';
import '../../../../shared/models/audit_event.dart';
import '../../../../shared/models/health_journey_entry.dart';
import '../../../../shared/models/doctor_profile.dart';
import '../../../../shared/models/hospital_info.dart';
import '../../../../shared/models/chat_conversation.dart';
import '../../../../shared/models/notification_model.dart';

abstract class PatientRepository {
  Future<Patient?> getPatientProfile(String patientId);
  Future<CardModel?> getCard(String patientId);
  Future<List<BookletEntry>> getMedicalBooklet(String patientId);
  Future<List<AccessGrant>> getAccessGrants(String patientId);
  Future<List<AuditEvent>> getAuditLog(String patientId);
  Future<List<HealthJourneyEntry>> getHealthJourney(String patientId);
  Future<List<DoctorProfile>> getDoctors();
  Future<DoctorProfile?> getDoctorById(String doctorId);
  Future<List<HospitalInfo>> getHospitals();
  Future<List<ChatConversation>> getChats(String patientId);
  Future<ChatConversation?> getChatById(String chatId);
  Future<List<NotificationModel>> getNotifications(String patientId);
  Future<List<NotificationModel>> getUnreadNotifications(String patientId);
  Future<AccessGrant> approveAccessRequest(String grantId);
  Future<void> revokeAccess(String grantId);
  Future<CardModel> requestCardReissue(String patientId);
  Future<Patient> registerPatient({
    required String name,
    required String gender,
    required String dateOfBirth,
    required String city,
  });
  Future<void> markNotificationRead(String notificationId);
  Future<void> markAllNotificationsRead();
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
  });
  Future<List<Map<String, dynamic>>> getAppointments(String patientId);
  Future<List<Map<String, dynamic>>> getPatientMedicalRecords(String patientId);
  Future<List<Map<String, dynamic>>> getAvailableSlots(String doctorId, String date);
  Future<List<Map<String, dynamic>>> getPrescriptions(String patientId);
  Future<Map<String, dynamic>> sendMessage({
    required String chatId,
    required String content,
    String? messageType,
  });
  Future<void> markChatAsRead(String chatId);
  Future<void> updatePatient(Map<String, dynamic> data);
  Future<Map<String, dynamic>> triggerSos({
    String? location,
    String? type,
    String? notes,
  });
  Future<Map<String, dynamic>> getCriticalInfo();
  Future<List<HospitalInfo>> getNearbyHospitals();
  Future<AccessGrant> grantAccess({
    required String doctorId,
    required String accessLevel,
    String? reason,
    String? expiresAt,
  });

  Future<void> cancelAppointment(String appointmentId, {String? reason});
  Future<void> rescheduleAppointment(String appointmentId, {
    required String date,
    required String startTime,
    required String endTime,
    String? reason,
  });
  Future<void> confirmAppointment(String appointmentId);
  Future<String?> uploadAvatar(String filePath, {String? patientId});
  Future<bool> sendOtp({required String phone, String? email});
  Future<bool> verifyOtp({required String phone, required String otp, String? email});
}
