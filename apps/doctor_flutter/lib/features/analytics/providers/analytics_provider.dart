import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';

class AnalyticsState {
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> diagnosisDistribution;
  final Map<String, dynamic> appointmentCompletion;
  final List<Map<String, dynamic>> weeklyTrends;
  final String period;
  final bool loading;
  final String? error;

  const AnalyticsState({
    this.stats = const {},
    this.diagnosisDistribution = const [],
    this.appointmentCompletion = const {},
    this.weeklyTrends = const [],
    this.period = 'Month',
    this.loading = false,
    this.error,
  });

  AnalyticsState copyWith({
    Map<String, dynamic>? stats,
    List<Map<String, dynamic>>? diagnosisDistribution,
    Map<String, dynamic>? appointmentCompletion,
    List<Map<String, dynamic>>? weeklyTrends,
    String? period,
    bool? loading,
    String? error,
  }) {
    return AnalyticsState(
      stats: stats ?? this.stats,
      diagnosisDistribution: diagnosisDistribution ?? this.diagnosisDistribution,
      appointmentCompletion: appointmentCompletion ?? this.appointmentCompletion,
      weeklyTrends: weeklyTrends ?? this.weeklyTrends,
      period: period ?? this.period,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  int get totalPatients => stats['totalPatients'] as int? ?? 0;
  int get totalAppointments => stats['totalAppointments'] as int? ?? 0;
  double get completionRate => stats['completionRate'] as double? ?? 0.0;
  String get avgDuration => stats['avgDuration'] as String? ?? '—';
  String get revenue => stats['revenue'] as String? ?? '—';
}

final analyticsProvider = NotifierProvider<AnalyticsNotifier, AnalyticsState>(AnalyticsNotifier.new);

class AnalyticsNotifier extends Notifier<AnalyticsState> {
  String get _doctorId => ref.read(currentDoctorIdProvider) ?? '';

  @override
  AnalyticsState build() => const AnalyticsState();

  Future<void> load({String? period}) async {
    final p = period ?? state.period;
    state = state.copyWith(loading: true, period: p, error: null);
    try {
      final repo = ref.read(analyticsRepositoryProvider);
      final results = await Future.wait([
        repo.getDoctorStats(_doctorId, period: p.toLowerCase()),
        repo.getDiagnosisDistribution(_doctorId),
        repo.getAppointmentCompletion(_doctorId),
        repo.getWeeklyTrends(_doctorId),
      ]);
      state = state.copyWith(
        stats: results[0] as Map<String, dynamic>,
        diagnosisDistribution: results[1] as List<Map<String, dynamic>>,
        appointmentCompletion: results[2] as Map<String, dynamic>,
        weeklyTrends: results[3] as List<Map<String, dynamic>>,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setPeriod(String period) {
    load(period: period);
  }

  Future<void> refresh() async {
    await load();
  }
}

final doctorStatsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, period) async {
  final doctorId = ref.read(currentDoctorIdProvider) ?? '';
  return ref.read(analyticsRepositoryProvider).getDoctorStats(doctorId, period: period.toLowerCase());
});

final diagnosisDistributionProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  throw UnsupportedError('Diagnosis distribution is not provided by the backend');
});

final appointmentCompletionProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  throw UnsupportedError('Appointment completion analytics are not provided by the backend');
});

final weeklyTrendsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  throw UnsupportedError('Weekly trends are not provided by the backend');
});