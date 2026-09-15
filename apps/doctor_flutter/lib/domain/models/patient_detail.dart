import 'package:freezed_annotation/freezed_annotation.dart';
import 'emergency_contact_info.dart';

part 'patient_detail.freezed.dart';
part 'patient_detail.g.dart';

@freezed
sealed class PatientDetail with _$PatientDetail {
  const factory PatientDetail({
    required String id,
    required String name,
    required DateTime dateOfBirth,
    required String nationalId,
    required String bloodType,
    required String gender,
    @Default('') String photoUrl,
    @Default('') String phone,
    @Default('') String email,
    @Default(<String>[]) List<String> allergies,
    @Default(<String>[]) List<String> chronicConditions,  // Aligned with backend
    @Default(<String>[]) List<String> currentMeds,
    EmergencyContactInfo? emergencyContact,
    @Default('') String insuranceProvider,
    @Default('') String insuranceNumber,
    @Default(0) int healthScore,
    @Default(false) bool verified,
    DateTime? lastVisit,
  }) = _PatientDetail;

  factory PatientDetail.fromJson(Map<String, dynamic> json) =>
      _$PatientDetailFromJson(json);
}
