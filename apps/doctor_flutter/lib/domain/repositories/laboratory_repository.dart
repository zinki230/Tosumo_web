import '../models/lab_request.dart';

abstract class LaboratoryRepository {
  Future<LabRequest> createLabRequest(LabRequest request);
  Future<LabRequest> getLabRequest(String id);
  Future<List<LabRequest>> getPatientLabRequests(String patientId);
  Future<List<LabRequest>> getAllLabRequests(String doctorId);
  Future<List<LabRequest>> getPendingRequests(String doctorId);
  Future<void> updateLabResults(
    String id, {
    String? resultValue,
    String? interpretation,
    String? status,
  });
}
