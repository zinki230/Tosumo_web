class DoctorApiEndpoints {
  DoctorApiEndpoints._();

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    // Default to the live backend (seeded with demo doctors) so the app works
    // out of the box. Override with --dart-define=API_BASE_URL=<url> for local
    // development (e.g. http://localhost:3000).
    return 'https://tosumo-production.up.railway.app';
  }

  /// Demo mode is used until a real SMS provider is wired up. In demo mode no
  /// real SMS is sent and a fixed code unlocks full access.
  static bool get isDemoMode {
    const demo = String.fromEnvironment('DEMO_MODE');
    if (demo.isNotEmpty) return demo == 'true';
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    return fromEnv.isEmpty;
  }

  static const String demoOtpCode = '123456';

  static const String auth = '/api/v1/auth';
  static const String login = '$auth/login';
  static const String register = '$auth/register';
  static const String otpLogin = '$auth/otp-login';
  static const String refresh = '$auth/refresh';
  static const String logout = '$auth/logout';
  static const String sendOtp = '$auth/send-otp';
  static const String verifyOtp = '$auth/verify-otp';
  static const String resetPassword = '$auth/reset-password';
  static const String changePassword = '$auth/change-password';
  static const String fcmToken = '$auth/fcm-token';
  static const String authProfile = '$auth/profile';

  static const String doctors = '/api/v1/doctors';
  static String doctor(String id) => '$doctors/$id';
  static const String doctorRegister = '$doctors/register';
  static const String doctorProfile = '$doctors/profile';
  static const String doctorChangePassword = '$doctors/change-password';
  static const String doctorAvailability = '$doctors/availability';
  static const String doctorAvailabilityStatus = '$doctors/availability-status';
  static const String doctorWorkingHours = '$doctors/working-hours';
  static const String doctorAppointments = '$doctors/appointments';
  static const String doctorPatients = '$doctors/patients';
  static const String doctorPatientsSearch = '$doctors/patients/search';
  static const String doctorPatientsQr = '$doctors/patients/qr';
  static const String doctorDashboard = '$doctors/dashboard';
  static const String doctorStats = '$doctors/stats';
  static const String doctorReviews = '$doctors/reviews';
  static const String doctorInstitutions = '$doctors/institutions';

  static const String patients = '/api/v1/patients';
  static String patient(String id) => '$patients/$id';
  static const String patientProfile = '$patients/profile';

  static const String appointments = '/api/v1/appointments';
  static String appointment(String id) => '$appointments/$id';
  static String appointmentApprove(String id) => '$appointments/$id/approve';
  static String appointmentConfirm(String id) => '$appointments/$id/confirm';
  static String appointmentCancel(String id) => '$appointments/$id/cancel';
  static String appointmentReschedule(String id) => '$appointments/$id/reschedule';
  static String appointmentComplete(String id) => '$appointments/$id/complete';
  static String appointmentNoShow(String id) => '$appointments/$id/no-show';
  static const String appointmentUpcoming = '$appointments/upcoming';
  static const String appointmentAvailableSlots = '$appointments/available-slots';

  static const String medicalRecords = '/api/v1/medical-records';
  static String medicalRecordsPatient(String patientId) => '$medicalRecords/patient/$patientId';

  static const String consultations = '$medicalRecords/consultations';
  static String consultation(String id) => '$consultations/$id';

  static const String labResults = '$medicalRecords/lab-results';
  static String labResult(String id) => '$labResults/$id';

  static const String imagingResults = '$medicalRecords/imaging-results';
  static String imagingResult(String id) => '$imagingResults/$id';

  static const String prescriptions = '$medicalRecords/prescriptions';
  static String prescription(String id) => '$prescriptions/$id';
  static String prescriptionFulfill(String id) => '$prescriptions/$id/fulfill';

  static const String access = '/api/v1/access';
  static const String accessRequest = '$access/request';
  static const String accessGrant = '$access/grant';
  static String accessApprove(String id) => '$access/$id/approve';
  static String accessRevoke(String id) => '$access/$id/revoke';
  static const String accessPatient = '$access/patient';
  static const String accessDoctor = '$access/doctor';
  static String accessCheck(String patientUserId) => '$access/check/$patientUserId';

  static const String chat = '/api/v1/chat';
  static String chatById(String id) => '$chat/$id';
  static String chatMessages(String id) => '$chat/$id/messages';
  static String chatMarkRead(String id) => '$chat/$id/read';
  static const String chatUnreadCount = '$chat/unread';

  static const String notifications = '/api/v1/notifications';
  static const String notificationUnread = '$notifications/unread';
  static const String notificationUnreadCount = '$notifications/unread/count';
  static String notificationRead(String id) => '$notifications/$id/read';
  static const String notificationReadAll = '$notifications/read-all';

  static const String emergency = '/api/v1/emergency';
  static const String emergencySessions = '$emergency/sessions';
  static String emergencySession(String id) => '$emergency/sessions/$id';
  static const String emergencyActiveSession = '$emergency/sessions/active';
  static String emergencyCriticalInfo(String patientId) => '$emergency/critical-info/$patientId';
  static const String emergencyNearbyHospitals = '$emergency/nearby-hospitals';

  static const String institutions = '/api/v1/institutions';
  static String institution(String id) => '$institutions/$id';

  static const String upload = '/api/v1/upload';
}
