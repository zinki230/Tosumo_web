import '../models/appointment.dart';

abstract class AppointmentRepository {
  Future<List<Appointment>> getAppointments(
    String doctorId, {
    String? status,
    int? page,
    int? limit,
  });
  Future<Appointment> getAppointment(String id);
  Future<void> approveAppointment(String id);
  Future<void> rejectAppointment(String id, {String? reason});
  Future<void> rescheduleAppointment(
    String id,
    DateTime newDate,
    String newTimeSlot,
  );
  Future<void> completeAppointment(String id);
  Future<void> cancelAppointment(String id, {String? reason});
  Future<void> markNoShow(String id);
  Future<Appointment> bookAppointment(
    String patientId,
    String doctorId,
    DateTime date,
    String timeSlot,
    String type,
  );
}
