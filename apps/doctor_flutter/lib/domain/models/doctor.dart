import 'package:freezed_annotation/freezed_annotation.dart';
import 'working_hour.dart';

part 'doctor.freezed.dart';
part 'doctor.g.dart';

@freezed
sealed class Doctor with _$Doctor {
  const factory Doctor({
    required String id,
    required String name,
    required String email,
    required String phone,
    required String specialty,
    required String hospitalId,
    required String hospitalName,
    required String licenseNumber,
    @Default('') String photoUrl,
    @Default(0.0) double rating,
    @Default(0) int reviewCount,
    @Default(<String>[]) List<String> languages,
    @Default(<String>[]) List<String> credentials,
    @Default(<String>[]) List<String> expertise,
    @Default(<WorkingHour>[]) List<WorkingHour> workingHours,
    @Default(true) bool isAvailable,
    required DateTime createdAt,
  }) = _Doctor;

  factory Doctor.fromJson(Map<String, dynamic> json) => _$DoctorFromJson(json);
}
