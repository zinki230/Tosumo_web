import 'package:freezed_annotation/freezed_annotation.dart';

part 'appointment.freezed.dart';
part 'appointment.g.dart';

@freezed
sealed class Appointment with _$Appointment {
  const factory Appointment({
    required String id,
    required String patientId,
    required String patientName,
    required String doctorId,
    required DateTime date,
    required String timeSlot,
    required String type,
    required String status,
    @Default('') String reason,
    @Default('') String notes,
    @Default(false) bool isUrgent,
    required DateTime createdAt,
  }) = _Appointment;

  factory Appointment.fromJson(Map<String, dynamic> json) =>
      _$AppointmentFromJson(json);
}
