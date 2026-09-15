import 'package:freezed_annotation/freezed_annotation.dart';

part 'health_journey_entry.freezed.dart';
part 'health_journey_entry.g.dart';

@freezed
sealed class HealthJourneyEntry with _$HealthJourneyEntry {
  const factory HealthJourneyEntry({
    required String id,
    required String patientId,
    required String date,
    required String title,
    required String subtitle,
    required String description,
    required String category,
    required String icon,
    required String status,
    required String institution,
    String? doctorName,
  }) = _HealthJourneyEntry;

  factory HealthJourneyEntry.fromJson(Map<String, dynamic> json) =>
      _$HealthJourneyEntryFromJson(json);
}
