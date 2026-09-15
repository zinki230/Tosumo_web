import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../domain/models/dashboard_stats.dart';
import '../../../domain/models/appointment.dart';
import '../../../domain/models/doctor.dart';

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final repo = ref.read(doctorRepositoryProvider);
  return repo.getDashboardStats(ref.watch(currentDoctorIdProvider) ?? '');
});

final todayAppointmentsProvider = FutureProvider<List<Appointment>>((ref) async {
  final repo = ref.read(doctorRepositoryProvider);
  return repo.getTodayAppointments(ref.watch(currentDoctorIdProvider) ?? '');
});

final doctorProfileProvider = FutureProvider<Doctor>((ref) async {
  final repo = ref.read(doctorRepositoryProvider);
  return repo.getProfile(ref.watch(currentDoctorIdProvider) ?? '');
});

final weeklyAppointmentsProvider = FutureProvider<List<Appointment>>((ref) async {
  final repo = ref.read(doctorRepositoryProvider);
  return repo.getWeeklyAppointments(ref.watch(currentDoctorIdProvider) ?? '');
});
