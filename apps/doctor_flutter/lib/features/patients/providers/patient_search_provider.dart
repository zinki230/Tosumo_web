import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../domain/models/patient_summary.dart';

class PatientSearchState {
  final String query;
  final List<PatientSummary> results;
  final List<PatientSummary> recentPatients;
  final List<PatientSummary> favoritePatients;
  final bool loading;
  final String? error;

  const PatientSearchState({
    this.query = '',
    this.results = const [],
    this.recentPatients = const [],
    this.favoritePatients = const [],
    this.loading = false,
    this.error,
  });

  PatientSearchState copyWith({
    String? query,
    List<PatientSummary>? results,
    List<PatientSummary>? recentPatients,
    List<PatientSummary>? favoritePatients,
    bool? loading,
    String? error,
  }) {
    return PatientSearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      recentPatients: recentPatients ?? this.recentPatients,
      favoritePatients: favoritePatients ?? this.favoritePatients,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class PatientSearchNotifier extends Notifier<PatientSearchState> {
  String get _doctorId => ref.read(currentDoctorIdProvider) ?? '';

  @override
  PatientSearchState build() => const PatientSearchState();

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = state.copyWith(query: '', results: const []);
      return;
    }
    state = state.copyWith(query: query, loading: true, error: null);
    try {
      final repo = ref.read(patientRepositoryProvider);
      final results = await repo.searchPatients(query);
      state = state.copyWith(results: results, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadRecent() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final repo = ref.read(patientRepositoryProvider);
      final recent = await repo.getRecentPatients(_doctorId);
      state = state.copyWith(recentPatients: recent, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> toggleFavorite(String patientId, bool favorite) async {
    try {
      final repo = ref.read(patientRepositoryProvider);
      await repo.toggleFavorite(patientId, favorite);
    } catch (_) {}
  }

  void clearResults() {
    state = state.copyWith(query: '', results: const [], error: null);
  }
}

final patientSearchProvider = NotifierProvider<PatientSearchNotifier, PatientSearchState>(
  PatientSearchNotifier.new,
);
