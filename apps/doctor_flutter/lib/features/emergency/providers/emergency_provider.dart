import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../domain/models/emergency_session.dart';

class EmergencyState {
  final EmergencySession? activeSession;
  final List<EmergencySession> history;
  final bool loading;
  final bool starting;
  final String? error;

  const EmergencyState({
    this.activeSession,
    this.history = const [],
    this.loading = false,
    this.starting = false,
    this.error,
  });

  EmergencyState copyWith({
    EmergencySession? activeSession,
    List<EmergencySession>? history,
    bool? loading,
    bool? starting,
    String? error,
  }) {
    return EmergencyState(
      activeSession: activeSession,
      history: history ?? this.history,
      loading: loading ?? this.loading,
      starting: starting ?? this.starting,
      error: error,
    );
  }

  bool get hasActiveSession => activeSession != null;
}

final emergencyProvider = NotifierProvider<EmergencyNotifier, EmergencyState>(EmergencyNotifier.new);

class EmergencyNotifier extends Notifier<EmergencyState> {
  String get _doctorId => ref.read(currentDoctorIdProvider) ?? '';

  @override
  EmergencyState build() => const EmergencyState();

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final repo = ref.read(emergencyRepositoryProvider);
      final active = await repo.getActiveSession(_doctorId);
      final history = await repo.getEmergencyHistory(_doctorId);
      state = state.copyWith(
        activeSession: active,
        history: history,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> startSession(String patientId, String justification) async {
    state = state.copyWith(starting: true, error: null);
    try {
      final repo = ref.read(emergencyRepositoryProvider);
      final session = await repo.startEmergencySession(patientId, _doctorId, justification);
      state = state.copyWith(activeSession: session, starting: false);
      await load();
    } catch (e) {
      state = state.copyWith(starting: false, error: e.toString());
    }
  }

  Future<void> completeSession(String sessionId) async {
    try {
      final repo = ref.read(emergencyRepositoryProvider);
      await repo.completeEmergencySession(sessionId);
      state = state.copyWith(activeSession: null);
      await load();
    } catch (_) {}
  }

  Future<void> refresh() async {
    await load();
  }
}

final activeSessionProvider = FutureProvider<EmergencySession?>((ref) async {
  final doctorId = ref.read(currentDoctorIdProvider) ?? '';
  return ref.read(emergencyRepositoryProvider).getActiveSession(doctorId);
});

final emergencyHistoryProvider = FutureProvider<List<EmergencySession>>((ref) async {
  final doctorId = ref.read(currentDoctorIdProvider) ?? '';
  return ref.read(emergencyRepositoryProvider).getEmergencyHistory(doctorId);
});