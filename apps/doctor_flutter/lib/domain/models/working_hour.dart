import 'package:freezed_annotation/freezed_annotation.dart';

part 'working_hour.freezed.dart';
part 'working_hour.g.dart';

@freezed
sealed class WorkingHour with _$WorkingHour {
  const factory WorkingHour({
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    @Default(true) bool isAvailable,
  }) = _WorkingHour;

  factory WorkingHour.fromJson(Map<String, dynamic> json) =>
      _$WorkingHourFromJson(json);
}
