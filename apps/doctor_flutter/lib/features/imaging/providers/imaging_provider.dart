import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../domain/models/imaging_request.dart';
import '../../../domain/models/patient_summary.dart';

class ImagingState {
  final List<ImagingRequest> requests;
  final String? statusFilter;
  final bool loading;
  final String? error;

  const ImagingState({
    this.requests = const [],
    this.statusFilter,
    this.loading = false,
    this.error,
  });

  ImagingState copyWith({
    List<ImagingRequest>? requests,
    String? statusFilter,
    bool? loading,
    String? error,
  }) {
    return ImagingState(
      requests: requests ?? this.requests,
      statusFilter: statusFilter ?? this.statusFilter,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  List<ImagingRequest> get filteredRequests {
    if (statusFilter == null) return requests;
    return requests.where((r) => r.status == statusFilter).toList();
  }
}

final imagingProvider = NotifierProvider<ImagingNotifier, ImagingState>(ImagingNotifier.new);

class ImagingNotifier extends Notifier<ImagingState> {
  String get _doctorId => ref.read(currentDoctorIdProvider) ?? '';

  @override
  ImagingState build() => const ImagingState();

  Future<void> loadRequests() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final repo = ref.read(imagingRepositoryProvider);
      final requests = await repo.getPendingImagingRequests(_doctorId);
      state = state.copyWith(requests: requests, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setFilter(String? status) {
    state = state.copyWith(statusFilter: status);
  }

  Future<void> createRequest(
    PatientSummary patient,
    String imagingType,
    String bodyPart,
    String notes,
  ) async {
    try {
      final request = ImagingRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        patientId: patient.id,
        doctorId: _doctorId,
        consultationId: '',
        imagingType: imagingType,
        bodyPart: bodyPart,
        status: 'pending',
        orderedAt: DateTime.now(),
        notes: notes,
      );
      await ref.read(imagingRepositoryProvider).createImagingRequest(request);
      await loadRequests();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> enterReport(String id, {String? findings, String? impression}) async {
    try {
      await ref.read(imagingRepositoryProvider).updateImagingResults(
        id,
        findings: findings,
        impression: impression,
        status: 'completed',
      );
      await loadRequests();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final imagingPendingCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.read(imagingRepositoryProvider);
  final pending = await repo.getPendingImagingRequests(ref.read(currentDoctorIdProvider) ?? '');
  return pending.where((r) => r.status == 'pending').length;
});