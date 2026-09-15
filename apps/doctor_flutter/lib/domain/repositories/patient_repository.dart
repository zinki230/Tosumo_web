import '../models/patient_summary.dart';
import '../models/patient_detail.dart';
import '../models/patient_vitals_update.dart';

abstract class PatientRepository {
  Future<List<PatientSummary>> searchPatients(String query);
  Future<List<PatientSummary>> searchByFilters({
    String? name,
    String? nationalId,
    String? phone,
    String? medicalId,
  });
  Future<PatientDetail> getPatientById(String patientId);
  Future<PatientDetail> getPatientByQrCode(String qrData);
  Future<void> grantPatientAccess(String patientId, String doctorUserId);
  Future<List<PatientSummary>> getRecentPatients(String doctorId);
  Future<void> toggleFavorite(String patientId, bool favorite);
  Future<PatientDetail> updatePatientVitals(String patientId, PatientVitalsUpdate update);
}
