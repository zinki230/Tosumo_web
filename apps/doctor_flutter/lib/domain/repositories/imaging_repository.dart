import '../models/imaging_request.dart';

abstract class ImagingRepository {
  Future<ImagingRequest> createImagingRequest(ImagingRequest request);
  Future<ImagingRequest> getImagingRequest(String id);
  Future<List<ImagingRequest>> getPatientImagingRequests(String patientId);
  Future<List<ImagingRequest>> getAllImagingRequests(String doctorId);
  Future<List<ImagingRequest>> getPendingImagingRequests(String doctorId);
  Future<void> updateImagingResults(
    String id, {
    String? findings,
    String? impression,
    String? status,
  });
}
