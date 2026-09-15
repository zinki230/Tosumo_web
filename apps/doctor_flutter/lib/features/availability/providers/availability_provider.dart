import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../domain/models/working_hour.dart';

class AvailabilityState {
  final List<WorkingHour> workingHours;
  final bool isAvailable;
  final bool loading;
  final bool saving;
  final String? error;

  const AvailabilityState({
    this.workingHours = const [],
    this.isAvailable = true,
    this.loading = false,
    this.saving = false,
    this.error,
  });

  AvailabilityState copyWith({
    List<WorkingHour>? workingHours,
    bool? isAvailable,
    bool? loading,
    bool? saving,
    String? error,
  }) {
    return AvailabilityState(
      workingHours: workingHours ?? this.workingHours,
      isAvailable: isAvailable ?? this.isAvailable,
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      error: error,
    );
  }

  List<WorkingHour> get weekdayHours => workingHours.where((h) => h.dayOfWeek <= 5).toList();
  List<WorkingHour> get weekendHours => workingHours.where((h) => h.dayOfWeek > 5).toList();
  bool get hasAnyAvailable => workingHours.any((h) => h.isAvailable);
}

final availabilityProvider = NotifierProvider<AvailabilityNotifier, AvailabilityState>(AvailabilityNotifier.new);

class AvailabilityNotifier extends Notifier<AvailabilityState> {
  String get _doctorId => ref.read(currentDoctorIdProvider) ?? '';

  @override
  AvailabilityState build() => AvailabilityState(
        workingHours: List.generate(7, (i) => WorkingHour(
          dayOfWeek: i + 1,
          startTime: '09:00',
          endTime: '17:00',
          isAvailable: i < 5,
        )),
      );

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final doctor = await ref.read(doctorRepositoryProvider).getProfile(_doctorId);
      state = state.copyWith(
        workingHours: doctor.workingHours.isNotEmpty ? doctor.workingHours : state.workingHours,
        isAvailable: doctor.isAvailable,
        loading: false,
      );
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  void toggleDayAvailability(int dayOfWeek) {
    final updated = state.workingHours.map((h) {
      if (h.dayOfWeek == dayOfWeek) {
        return WorkingHour(
          dayOfWeek: h.dayOfWeek,
          startTime: h.startTime,
          endTime: h.endTime,
          isAvailable: !h.isAvailable,
        );
      }
      return h;
    }).toList();
    state = state.copyWith(workingHours: updated);
  }

  void setDayHours(int dayOfWeek, String startTime, String endTime) {
    final updated = state.workingHours.map((h) {
      if (h.dayOfWeek == dayOfWeek) {
        return WorkingHour(
          dayOfWeek: h.dayOfWeek,
          startTime: startTime,
          endTime: endTime,
          isAvailable: h.isAvailable,
        );
      }
      return h;
    }).toList();
    state = state.copyWith(workingHours: updated);
  }

  void applyToWeekdays() {
    final firstWeekday = state.workingHours.firstWhere((h) => h.dayOfWeek == 1);
    final updated = state.workingHours.map((h) {
      if (h.dayOfWeek >= 1 && h.dayOfWeek <= 5) {
        return WorkingHour(
          dayOfWeek: h.dayOfWeek,
          startTime: firstWeekday.startTime,
          endTime: firstWeekday.endTime,
          isAvailable: firstWeekday.isAvailable,
        );
      }
      return h;
    }).toList();
    state = state.copyWith(workingHours: updated);
  }

  void setAvailability(bool isAvailable) {
    state = state.copyWith(isAvailable: isAvailable);
  }

  Future<void> save() async {
    state = state.copyWith(saving: true, error: null);
    try {
      await ref.read(settingsRepositoryProvider).updateWorkingHours(state.workingHours);
      final currentDoctor = await ref.read(doctorRepositoryProvider).getProfile(_doctorId);
      await ref.read(doctorRepositoryProvider).updateProfile(
        currentDoctor.copyWith(
          workingHours: state.workingHours,
          isAvailable: state.isAvailable,
        ),
      );
      state = state.copyWith(saving: false);
    } catch (e) {
      state = state.copyWith(saving: false, error: e.toString());
    }
  }
}