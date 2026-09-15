import 'package:freezed_annotation/freezed_annotation.dart';

part 'hospital_info.freezed.dart';
part 'hospital_info.g.dart';

@freezed
sealed class HospitalInfo with _$HospitalInfo {
  const factory HospitalInfo({
    required String id,
    required String name,
    required String distance,
    required String address,
    @Default(false) bool emergencyAvailable,
    @Default(false) bool digitalIdentityEnabled,
    @Default(false) bool laboratory,
    @Default(false) bool pharmacy,
    @Default(false) bool openNow,
    required String openHours,
    required String averageWaitTime,
    @Default([]) List<String> specialists,
    @Default([]) List<String> acceptedInsurance,
    required String phone,
  }) = _HospitalInfo;

  factory HospitalInfo.fromJson(Map<String, dynamic> json) =>
      _$HospitalInfoFromJson(json);
}
