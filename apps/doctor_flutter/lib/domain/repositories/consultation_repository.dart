import '../models/consultation.dart';
import '../models/vital_signs.dart';

abstract class ConsultationRepository {
  Future<Consultation> createConsultation(Consultation consultation);
  Future<Consultation> getConsultation(String id);
  Future<List<Consultation>> getMyConsultations();
  Future<List<Consultation>> getPatientConsultations(String patientId);
  Future<Consultation> updateDraft(String id, Consultation consultation);
  Future<Consultation> finalizeConsultation(String id);
  Future<Consultation> signConsultation(String id);
  Future<String> generatePdf(String id);
  Future<void> saveVitalSigns(String consultationId, VitalSigns vitals);
}
