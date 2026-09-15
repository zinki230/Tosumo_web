import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../domain/models/appointment.dart';

class AppointmentsState {
  final List<Appointment> appointments;
  final String? statusFilter;
  final int currentPage;
  final bool loading;
  final String? error;

  const AppointmentsState({
    this.appointments = const [],
    this.statusFilter,
    this.currentPage = 0,
    this.loading = false,
    this.error,
  });

  AppointmentsState copyWith({
    List<Appointment>? appointments,
    String? statusFilter,
    int? currentPage,
    bool? loading,
    String? error,
  }) {
    return AppointmentsState(
      appointments: appointments ?? this.appointments,
      statusFilter: statusFilter ?? this.statusFilter,
      currentPage: currentPage ?? this.currentPage,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  List<Appointment> get filteredAppointments {
    if (statusFilter == null) return appointments;
    return appointments.where((a) => a.status == statusFilter).toList();
  }

  Map<String, List<Appointment>> get groupedByStatus {
    final map = <String, List<Appointment>>{};
    for (final a in appointments) {
      map.putIfAbsent(a.status, () => []).add(a);
    }
    return map;
  }
}

class AppointmentsNotifier extends AsyncNotifier<AppointmentsState> {
  String get _doctorId => ref.read(currentDoctorIdProvider) ?? '';

  @override
  Future<AppointmentsState> build() async {
    await _fetchAppointments();
    return state.value ?? const AppointmentsState();
  }

  Future<void> _fetchAppointments({String? status, int page = 0, bool append = false}) async {
    try {
      final repo = ref.read(appointmentRepositoryProvider);
      final results = await repo.getAppointments(_doctorId, status: status, page: page, limit: 20);
      final current = state.value ?? const AppointmentsState();
      if (append) {
        state = AsyncData(current.copyWith(
          appointments: [...current.appointments, ...results],
          currentPage: page,
          loading: false,
        ));
      } else {
        state = AsyncData(current.copyWith(
          appointments: results,
          currentPage: page,
          loading: false,
          error: null,
        ));
      }
    } catch (e) {
      state = AsyncData((state.value ?? const AppointmentsState()).copyWith(
        loading: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> setFilter(String? status) async {
    state = AsyncData((state.value ?? const AppointmentsState()).copyWith(
      statusFilter: status,
      loading: true,
    ));
    await _fetchAppointments(status: status);
  }

  Future<void> refresh() async {
    state = AsyncData((state.value ?? const AppointmentsState()).copyWith(loading: true));
    await _fetchAppointments();
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loading) return;
    await _fetchAppointments(
      status: current.statusFilter,
      page: current.currentPage + 1,
      append: true,
    );
  }

  Future<void> approveAppointment(String id) async {
    try {
      await ref.read(appointmentRepositoryProvider).approveAppointment(id);
      await refresh();
    } catch (_) {}
  }

  Future<void> rejectAppointment(String id, {String? reason}) async {
    try {
      await ref.read(appointmentRepositoryProvider).rejectAppointment(id, reason: reason);
      await refresh();
    } catch (_) {}
  }

  Future<void> completeAppointment(String id) async {
    try {
      await ref.read(appointmentRepositoryProvider).completeAppointment(id);
      await refresh();
    } catch (_) {}
  }

  Future<void> cancelAppointment(String id, {String? reason}) async {
    try {
      await ref.read(appointmentRepositoryProvider).cancelAppointment(id, reason: reason);
      await refresh();
    } catch (_) {}
  }

  Future<void> rescheduleAppointment(String id, DateTime newDate, String newTimeSlot) async {
    try {
      await ref.read(appointmentRepositoryProvider).rescheduleAppointment(id, newDate, newTimeSlot);
      await refresh();
    } catch (_) {}
  }
}

final appointmentsProvider = AsyncNotifierProvider<AppointmentsNotifier, AppointmentsState>(() {
  return AppointmentsNotifier();
});
