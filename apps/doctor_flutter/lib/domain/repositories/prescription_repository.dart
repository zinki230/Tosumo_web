import '../models/prescription.dart';

abstract class PrescriptionRepository {
  Future<Prescription> createPrescription(Prescription prescription);
  Future<Prescription> getPrescription(String id);
  Future<List<Prescription>> getPatientPrescriptions(String patientId);
  Future<Prescription> renewPrescription(String id);
  Future<String> generatePdf(String id);
  Future<void> cancelPrescription(String id);
}
