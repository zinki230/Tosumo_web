import 'package:freezed_annotation/freezed_annotation.dart';

part 'vital_signs.freezed.dart';
part 'vital_signs.g.dart';

@freezed
sealed class VitalSigns with _$VitalSigns {
  const factory VitalSigns({
    @Default(0) int bloodPressureSystolic,
    @Default(0) int bloodPressureDiastolic,
    @Default(0) int heartRate,
    @Default(0.0) double temperature,
    @Default(0) int respiratoryRate,
    @Default(0.0) double oxygenSaturation,
    @Default(0.0) double weight,
    @Default(0.0) double height,
    @Default(0.0) double bmi,
  }) = _VitalSigns;

  factory VitalSigns.fromJson(Map<String, dynamic> json) =>
      _$VitalSignsFromJson(json);
}
