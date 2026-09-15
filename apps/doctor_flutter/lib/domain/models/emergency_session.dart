import 'package:freezed_annotation/freezed_annotation.dart';
import 'emergency_contact_info.dart';

part 'emergency_session.freezed.dart';
part 'emergency_session.g.dart';

@freezed
sealed class EmergencyPatientSummary with _$EmergencyPatientSummary {
  const factory EmergencyPatientSummary({
    required String name,
    required int age,
    required String bloodType,
    required String gender,
    @Default(<String>[]) List<String> allergies,
    @Default(<String>[]) List<String> chronicConditions,
    EmergencyContactInfo? emergencyContact,
    @Default('') String chiefComplaint,
    @Default('') String triageNotes,
  }) = _EmergencyPatientSummary;

  factory EmergencyPatientSummary.fromJson(Map<String, dynamic> json) =>
      _$EmergencyPatientSummaryFromJson(json);
}

@freezed
sealed class EmergencySession with _$EmergencySession {
  const factory EmergencySession({
    required String id,
    required String patientId,
    required String doctorId,
    required DateTime startedAt,
    @Default('active') String status,
    required EmergencyPatientSummary patientSummary,
  }) = _EmergencySession;

  factory EmergencySession.fromJson(Map<String, dynamic> json) =>
      _$EmergencySessionFromJson(json);
}
