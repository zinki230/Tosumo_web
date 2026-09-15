import 'package:freezed_annotation/freezed_annotation.dart';

part 'emergency_contact_info.freezed.dart';
part 'emergency_contact_info.g.dart';

@freezed
sealed class EmergencyContactInfo with _$EmergencyContactInfo {
  const factory EmergencyContactInfo({
    required String name,
    required String relationship,
    required String phone,
  }) = _EmergencyContactInfo;

  factory EmergencyContactInfo.fromJson(Map<String, dynamic> json) =>
      _$EmergencyContactInfoFromJson(json);
}
