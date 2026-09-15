import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../domain/models/lab_request.dart';
import '../../../domain/models/patient_summary.dart';

class LabState {
  final List<LabRequest> requests;
  final String? statusFilter;
  final bool loading;
  final String? error;

  const LabState({
    this.requests = const [],
    this.statusFilter,
    this.loading = false,
    this.error,
  });

  LabState copyWith({
    List<LabRequest>? requests,
    String? statusFilter,
    bool? loading,
    String? error,
  }) {
    return LabState(
      requests: requests ?? this.requests,
      statusFilter: statusFilter ?? this.statusFilter,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  List<LabRequest> get filteredRequests {
    if (statusFilter == null) return requests;
    return requests.where((r) => r.status == statusFilter).toList();
  }
}

final labProvider = NotifierProvider<LabNotifier, LabState>(LabNotifier.new);

class LabNotifier extends Notifier<LabState> {
  String get _doctorId => ref.read(currentDoctorIdProvider) ?? '';

  @override
  LabState build() => const LabState();

  Future<void> loadRequests() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final repo = ref.read(laboratoryRepositoryProvider);
      final requests = await repo.getPendingRequests(_doctorId);
      state = state.copyWith(requests: requests, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setFilter(String? status) {
    state = state.copyWith(statusFilter: status);
  }

  Future<void> createRequest(PatientSummary patient, String testName, String testType, String notes) async {
    try {
      final request = LabRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        patientId: patient.id,
        doctorId: _doctorId,
        consultationId: '',
        testName: testName,
        testType: testType,
        status: 'pending',
        orderedAt: DateTime.now(),
        notes: notes,
      );
      await ref.read(laboratoryRepositoryProvider).createLabRequest(request);
      await loadRequests();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> enterResults(String id, {String? resultValue, String? interpretation}) async {
    try {
      await ref.read(laboratoryRepositoryProvider).updateLabResults(
        id,
        resultValue: resultValue,
        interpretation: interpretation,
        status: 'completed',
      );
      await loadRequests();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final labPendingCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.read(laboratoryRepositoryProvider);
  final pending = await repo.getPendingRequests(ref.read(currentDoctorIdProvider) ?? '');
  return pending.where((r) => r.status == 'pending').length;
});