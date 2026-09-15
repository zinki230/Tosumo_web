import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../domain/models/consultation.dart';
import '../../../domain/models/vital_signs.dart';
import '../../../domain/models/patient_summary.dart';

class ConsultationDraft {
  final PatientSummary patient;
  final List<String> symptoms;
  final String diagnosis;
  final String clinicalNotes;
  final VitalSigns? vitals;
  final String physicalExamination;
  final String treatment;
  final String followUpPlan;
  final String severity;

  const ConsultationDraft({
    required this.patient,
    this.symptoms = const [],
    this.diagnosis = '',
    this.clinicalNotes = '',
    this.vitals,
    this.physicalExamination = '',
    this.treatment = '',
    this.followUpPlan = '',
    this.severity = 'mild',
  });

  ConsultationDraft copyWith({
    PatientSummary? patient,
    List<String>? symptoms,
    String? diagnosis,
    String? clinicalNotes,
    VitalSigns? vitals,
    String? physicalExamination,
    String? treatment,
    String? followUpPlan,
    String? severity,
  }) {
    return ConsultationDraft(
      patient: patient ?? this.patient,
      symptoms: symptoms ?? this.symptoms,
      diagnosis: diagnosis ?? this.diagnosis,
      clinicalNotes: clinicalNotes ?? this.clinicalNotes,
      vitals: vitals ?? this.vitals,
      physicalExamination: physicalExamination ?? this.physicalExamination,
      treatment: treatment ?? this.treatment,
      followUpPlan: followUpPlan ?? this.followUpPlan,
      severity: severity ?? this.severity,
    );
  }
}

class ConsultationState {
  final List<Consultation> consultations;
  final ConsultationDraft? draft;
  final bool isCreating;
  final bool isSaving;
  final String? error;

  const ConsultationState({
    this.consultations = const [],
    this.draft,
    this.isCreating = false,
    this.isSaving = false,
    this.error,
  });

  ConsultationState copyWith({
    List<Consultation>? consultations,
    ConsultationDraft? draft,
    bool? isCreating,
    bool? isSaving,
    String? error,
  }) {
    return ConsultationState(
      consultations: consultations ?? this.consultations,
      draft: draft ?? this.draft,
      isCreating: isCreating ?? this.isCreating,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }
}

class ConsultationNotifier extends Notifier<ConsultationState> {
  String get _doctorId => ref.read(currentDoctorIdProvider) ?? '';

  @override
  ConsultationState build() => const ConsultationState();

  Future<void> loadConsultations(String patientId) async {
    try {
      final repo = ref.read(consultationRepositoryProvider);
      final consultations = await repo.getPatientConsultations(patientId);
      state = state.copyWith(consultations: consultations, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void startDraft(PatientSummary patient) {
    state = state.copyWith(
      draft: ConsultationDraft(patient: patient),
      isCreating: true,
      error: null,
    );
  }

  void updateDraft(ConsultationDraft draft) {
    state = state.copyWith(draft: draft);
  }

  void clearDraft() {
    state = state.copyWith(draft: null, isCreating: false);
  }

  Future<void> saveDraft() async {
    final draft = state.draft;
    if (draft == null) return;
    state = state.copyWith(isSaving: true, error: null);
    try {
      final consultation = Consultation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        patientId: draft.patient.id,
        doctorId: _doctorId,
        appointmentId: '',
        date: DateTime.now(),
        symptoms: draft.symptoms,
        diagnosis: draft.diagnosis,
        clinicalNotes: draft.clinicalNotes,
        vitals: draft.vitals,
        physicalExamination: draft.physicalExamination,
        treatment: draft.treatment,
        followUpPlan: draft.followUpPlan,
        severity: draft.severity,
        status: 'draft',
        createdAt: DateTime.now(),
      );
      await ref.read(consultationRepositoryProvider).createConsultation(consultation);
      state = state.copyWith(isSaving: false, isCreating: false, draft: null);
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
    }
  }

  Future<void> finalizeConsultation() async {
    final draft = state.draft;
    if (draft == null) return;
    state = state.copyWith(isSaving: true, error: null);
    try {
      final consultation = Consultation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        patientId: draft.patient.id,
        doctorId: _doctorId,
        appointmentId: '',
        date: DateTime.now(),
        symptoms: draft.symptoms,
        diagnosis: draft.diagnosis,
        clinicalNotes: draft.clinicalNotes,
        vitals: draft.vitals,
        physicalExamination: draft.physicalExamination,
        treatment: draft.treatment,
        followUpPlan: draft.followUpPlan,
        severity: draft.severity,
        status: 'finalized',
        createdAt: DateTime.now(),
        signedAt: DateTime.now(),
      );
      final created = await ref.read(consultationRepositoryProvider).createConsultation(consultation);
      await ref.read(consultationRepositoryProvider).finalizeConsultation(created.id);
      state = state.copyWith(isSaving: false, isCreating: false, draft: null);
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
    }
  }

  Future<void> signConsultation(String id) async {
    try {
      await ref.read(consultationRepositoryProvider).signConsultation(id);
    } catch (_) {}
  }
}

final consultationProvider = NotifierProvider<ConsultationNotifier, ConsultationState>(
  ConsultationNotifier.new,
);

final patientConsultationsProvider = FutureProvider.family<List<Consultation>, String>((ref, patientId) async {
  return ref.read(consultationRepositoryProvider).getPatientConsultations(patientId);
});
