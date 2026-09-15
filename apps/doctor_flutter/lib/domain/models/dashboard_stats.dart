import 'package:freezed_annotation/freezed_annotation.dart';
import 'appointment.dart';

part 'dashboard_stats.freezed.dart';
part 'dashboard_stats.g.dart';

@freezed
sealed class DashboardStats with _$DashboardStats {
  const factory DashboardStats({
    @Default(0) int totalAppointments,
    @Default(0) int todayAppointments,
    @Default(0) int pendingApprovals,
    @Default(0) int totalPatients,
    @Default(<Appointment>[]) List<Appointment> recentAppointments,
    @Default(<Appointment>[]) List<Appointment> upcomingAppointments,
  }) = _DashboardStats;

  factory DashboardStats.fromJson(Map<String, dynamic> json) =>
      _$DashboardStatsFromJson(json);
}
