import 'package:freezed_annotation/freezed_annotation.dart';

part 'patient.freezed.dart';
part 'patient.g.dart';

@freezed
sealed class Patient with _$Patient {
  const factory Patient({
    required String id,
    required String name,
    required DateTime dateOfBirth,  // Changed from String to DateTime for consistency
    required String nationalId,
    required String phone,  // Flattened from ContactInfo
    required String email,  // Flattened from ContactInfo
    @Default('') String bloodType,
    @Default([]) List<String> allergies,
    @Default([]) List<String> chronicConditions,
    @Default([]) List<String> currentMeds,
    required String emergencyContactName,  // Flattened from EmergencyContact
    required String emergencyContactRelationship,  // Flattened from EmergencyContact
    required String emergencyContactPhone,  // Flattened from EmergencyContact
    @Default('ACTIVE') String status,
    @Default(false) bool verified,
    String? gender,
    String? photoUrl,
    @Default('') String city,
    @Default('') String address,
  }) = _Patient;

  factory Patient.fromJson(Map<String, dynamic> json) =>
      _$PatientFromJson(json);
}
