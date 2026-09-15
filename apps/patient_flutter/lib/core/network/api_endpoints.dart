import '../config/app_environment.dart';

class ApiEndpoints {
  ApiEndpoints._();

  static String get baseUrl => AppEnvironment.current.apiBaseUrl;

  static const String auth = '/api/v1/auth';
  static const String login = '$auth/login';
  static const String otpLogin = '$auth/otp-login';
  static const String register = '$auth/register';
  static const String refresh = '$auth/refresh';
  static const String logout = '$auth/logout';
  static const String authProfile = '$auth/profile';
  static const String sendOtp = '$auth/send-otp';
  static const String verifyOtp = '$auth/verify-otp';
  static const String checkPhone = '$auth/check-phone';

  static const String patients = '/api/v1/patients';
  static String patient(String id) => '$patients/$id';
  static const String patientProfile = '$patients/profile';
  static const String patientOnboard = '$patients/onboard';
  static const String patientMedicalCard = '$patients/medical-card';
  static const String patientMedicalBooklets = '$patients/medical-booklets';
  static const String patientJourney = '$patients/journey';
  static const String patientAppointments = '$patients/appointments';
  static const String patientMedicalRecords = '$patients/medical-records';

  static const String cards = '/api/v1/cards';
  static const String cardReissue = '$cards/reissue';

  static const String appointments = '/api/v1/appointments';
  static String appointment(String id) => '$appointments/$id';
  static String appointmentApprove(String id) => '$appointments/$id/approve';
  static String appointmentConfirm(String id) => '$appointments/$id/confirm';
  static String appointmentCancel(String id) => '$appointments/$id/cancel';
  static String appointmentReschedule(String id) => '$appointments/$id/reschedule';
  static const String appointmentAvailableSlots = '$appointments/available-slots';
  static const String appointmentUpcoming = '$appointments/upcoming';

  static const String doctors = '/api/v1/doctors';
  static String doctor(String id) => '$doctors/$id';

  static const String institutions = '/api/v1/institutions';
  static String institution(String id) => '$institutions/$id';

  static const String chat = '/api/v1/chat';
  static String chatById(String id) => '$chat/$id';
  static String chatMessages(String id) => '$chat/$id/messages';
  static const String chatUnread = '$chat/unread';

  static const String notifications = '/api/v1/notifications';
  static String notificationRead(String id) => '$notifications/$id/read';
  static const String notificationReadAll = '$notifications/read-all';
  static const String notificationUnread = '$notifications/unread';

  static const String access = '/api/v1/access';
  static const String accessGrant = '$access/grant';
  static const String accessPatient = '$access/patient';
  static String accessApprove(String id) => '$access/$id/approve';
  static String accessRevoke(String id) => '$access/$id/revoke';

  static String chatReadById(String id) => '$chat/$id/read';

  static const String auditLogs = '/api/v1/audit-logs';

  static const String emergency = '/api/v1/emergency';
  static const String emergencySos = '$emergency/sos';
  static const String emergencyCriticalInfo = '$emergency/critical-info';
  static const String emergencyNearbyHospitals = '$emergency/nearby-hospitals';

  static const String payments = '/api/v1/payments';
  static String payment(String id) => '$payments/$id';
  static const String paymentInitiate = '$payments/initiate';

  static const String medicalRecords = '/api/v1/medical-records';
  static const String medicalRecordsConsultations = '$medicalRecords/consultations';
  static String medicalRecordsConsultation(String id) => '$medicalRecords/consultations/$id';
  static const String medicalRecordsLabResults = '$medicalRecords/lab-results';
  static String medicalRecordsLabResult(String id) => '$medicalRecords/lab-results/$id';
  static const String medicalRecordsImagingResults = '$medicalRecords/imaging-results';
  static String medicalRecordsImagingResult(String id) => '$medicalRecords/imaging-results/$id';
  static const String medicalRecordsPrescriptions = '$medicalRecords/prescriptions';
  static String medicalRecordsPrescription(String id) => '$medicalRecords/prescriptions/$id';
  static String medicalRecordsPrescriptionFulfill(String id) => '$medicalRecords/prescriptions/$id/fulfill';

  static const String upload = '/api/v1/upload';
  static const String uploadMultiple = '$upload/multiple';

  static const String sync = '/api/v1/sync';
}
