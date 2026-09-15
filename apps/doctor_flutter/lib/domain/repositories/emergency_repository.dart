import '../models/emergency_session.dart';

abstract class EmergencyRepository {
  Future<EmergencySession?> getActiveSession(String doctorId);
  Future<List<EmergencySession>> getEmergencyHistory(String doctorId);
  Future<EmergencySession> startEmergencySession(
    String patientId,
    String doctorId,
    String justification,
  );
  Future<void> completeEmergencySession(String sessionId);
  Future<EmergencyPatientSummary> getEmergencyPatientSummary(String patientId);
}
