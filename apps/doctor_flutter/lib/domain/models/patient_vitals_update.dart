import 'package:freezed_annotation/freezed_annotation.dart';

import 'emergency_contact_info.dart';

part 'patient_vitals_update.freezed.dart';
part 'patient_vitals_update.g.dart';

@freezed
sealed class PatientVitalsUpdate with _$PatientVitalsUpdate {
  const factory PatientVitalsUpdate({
    String? bloodType,
    @Default(<String>[]) List<String> allergies,
    @Default(<String>[]) List<String> chronicConditions,
    @Default(<String>[]) List<String> currentMeds,
    EmergencyContactInfo? emergencyContact,
    String? signedByDoctorId,
    String? signedByDoctorName,
    @Default(false) bool signed,
  }) = _PatientVitalsUpdate;

  factory PatientVitalsUpdate.fromJson(Map<String, dynamic> json) =>
      _$PatientVitalsUpdateFromJson(json);
}
