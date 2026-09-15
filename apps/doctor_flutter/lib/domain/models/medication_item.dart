import 'package:freezed_annotation/freezed_annotation.dart';

part 'medication_item.freezed.dart';
part 'medication_item.g.dart';

@freezed
sealed class MedicationItem with _$MedicationItem {
  const factory MedicationItem({
    @JsonKey(name: 'name') required String drugName,
    required String dosage,
    required String frequency,
    required String duration,
    @Default('oral') String route,
    @Default('') String instructions,
    @Default(<String>[]) List<String> warnings,
    @Default(<String>[]) List<String> interactions,
  }) = _MedicationItem;

  factory MedicationItem.fromJson(Map<String, dynamic> json) =>
      _$MedicationItemFromJson(json);
}
