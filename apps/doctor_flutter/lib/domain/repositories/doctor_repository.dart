import '../models/doctor.dart';
import '../models/dashboard_stats.dart';
import '../models/appointment.dart';

abstract class DoctorRepository {
  Future<Doctor> getProfile(String doctorId);
  Future<Doctor> updateProfile(Doctor doctor);
  Future<DashboardStats> getDashboardStats(String doctorId);
  Future<List<Appointment>> getTodayAppointments(String doctorId);
  Future<List<Appointment>> getWeeklyAppointments(String doctorId);
}
