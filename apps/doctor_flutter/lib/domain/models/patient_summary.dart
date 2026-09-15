import 'package:freezed_annotation/freezed_annotation.dart';

part 'patient_summary.freezed.dart';
part 'patient_summary.g.dart';

@freezed
sealed class PatientSummary with _$PatientSummary {
  const factory PatientSummary({
    required String id,
    required String name,
    required String nationalId,
    required DateTime dateOfBirth,
    required String bloodType,
    required String gender,
    @Default('') String photoUrl,
    DateTime? lastVisit,
    @Default(false) bool isFavorite,
    @Default(<String>[]) List<String> conditions,
    @Default(<String>[]) List<String> allergies,
    @Default(false) bool verified,
  }) = _PatientSummary;

  factory PatientSummary.fromJson(Map<String, dynamic> json) =>
      _$PatientSummaryFromJson(json);
}
