import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../domain/models/prescription.dart';
import '../../../domain/models/medication_item.dart';
import '../../../domain/models/patient_summary.dart';

class MedicationDraft {
  final String drugName;
  final String dosage;
  final String frequency;
  final String duration;
  final String route;
  final String instructions;
  final List<String> warnings;
  final List<String> interactions;

  const MedicationDraft({
    this.drugName = '',
    this.dosage = '',
    this.frequency = '',
    this.duration = '',
    this.route = 'oral',
    this.instructions = '',
    this.warnings = const [],
    this.interactions = const [],
  });

  MedicationItem toItem() => MedicationItem(
    drugName: drugName,
    dosage: dosage,
    frequency: frequency,
    duration: duration,
    route: route,
    instructions: instructions,
    warnings: warnings,
    interactions: interactions,
  );
}

class PrescriptionState {
  final List<Prescription> prescriptions;
  final PatientSummary? selectedPatient;
  final List<MedicationDraft> medications;
  final String notes;
  final bool isRenewed;
  final bool isCreating;
  final bool isSaving;
  final String? error;

  const PrescriptionState({
    this.prescriptions = const [],
    this.selectedPatient,
    this.medications = const [],
    this.notes = '',
    this.isRenewed = false,
    this.isCreating = false,
    this.isSaving = false,
    this.error,
  });

  PrescriptionState copyWith({
    List<Prescription>? prescriptions,
    PatientSummary? selectedPatient,
    List<MedicationDraft>? medications,
    String? notes,
    bool? isRenewed,
    bool? isCreating,
    bool? isSaving,
    String? error,
  }) {
    return PrescriptionState(
      prescriptions: prescriptions ?? this.prescriptions,
      selectedPatient: selectedPatient ?? this.selectedPatient,
      medications: medications ?? this.medications,
      notes: notes ?? this.notes,
      isRenewed: isRenewed ?? this.isRenewed,
      isCreating: isCreating ?? this.isCreating,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }
}

class PrescriptionNotifier extends Notifier<PrescriptionState> {
  String get _doctorId => ref.read(currentDoctorIdProvider) ?? '';

  @override
  PrescriptionState build() => const PrescriptionState();

  Future<void> loadPatientPrescriptions(String patientId) async {
    try {
      final repo = ref.read(prescriptionRepositoryProvider);
      final prescriptions = await repo.getPatientPrescriptions(patientId);
      state = state.copyWith(prescriptions: prescriptions, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void startNew(PatientSummary patient) {
    state = state.copyWith(
      selectedPatient: patient,
      isCreating: true,
      medications: [],
      notes: '',
      isRenewed: false,
      error: null,
    );
  }

  void addMedication() {
    state = state.copyWith(
      medications: [...state.medications, const MedicationDraft()],
    );
  }

  void updateMedication(int index, MedicationDraft medication) {
    final updated = [...state.medications];
    updated[index] = medication;
    state = state.copyWith(medications: updated);
  }

  void removeMedication(int index) {
    final updated = [...state.medications];
    updated.removeAt(index);
    state = state.copyWith(medications: updated);
  }

  void setNotes(String notes) {
    state = state.copyWith(notes: notes);
  }

  void setRenewed(bool renewed) {
    state = state.copyWith(isRenewed: renewed);
  }

  void cancelCreation() {
    state = state.copyWith(isCreating: false, selectedPatient: null, medications: []);
  }

  Future<void> save() async {
    if (state.selectedPatient == null || state.medications.isEmpty) return;
    state = state.copyWith(isSaving: true, error: null);
    try {
      final medications = state.medications.map((m) => m.toItem()).toList();
      final prescription = Prescription(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        patientId: state.selectedPatient!.id,
        doctorId: _doctorId,
        consultationId: '',
        medications: medications,
        notes: state.notes,
        issueDate: DateTime.now(),
        expiryDate: DateTime.now().add(const Duration(days: 30)),
        isRenewed: state.isRenewed,
        status: 'active',
        createdAt: DateTime.now(),
      );
      await ref.read(prescriptionRepositoryProvider).createPrescription(prescription);
      state = state.copyWith(isSaving: false, isCreating: false, selectedPatient: null, medications: []);
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
    }
  }

  Future<void> renewPrescription(String id) async {
    try {
      await ref.read(prescriptionRepositoryProvider).renewPrescription(id);
      if (state.selectedPatient != null) {
        await loadPatientPrescriptions(state.selectedPatient!.id);
      }
    } catch (_) {}
  }

  Future<void> cancelPrescription(String id) async {
    try {
      await ref.read(prescriptionRepositoryProvider).cancelPrescription(id);
      if (state.selectedPatient != null) {
        await loadPatientPrescriptions(state.selectedPatient!.id);
      }
    } catch (_) {}
  }
}

final prescriptionProvider = NotifierProvider<PrescriptionNotifier, PrescriptionState>(
  PrescriptionNotifier.new,
);
