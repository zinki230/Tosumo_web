import 'package:freezed_annotation/freezed_annotation.dart';

part 'access_grant.freezed.dart';
part 'access_grant.g.dart';

@freezed
sealed class AccessGrant with _$AccessGrant {
  const factory AccessGrant({
    required String id,
    required String patientId,
    required String institutionId,
    required String institutionName,
    required String mode,
    required String scope,
    required String grantedAt,
    String? expiresAt,
    @Default('PENDING') String status,
  }) = _AccessGrant;

  factory AccessGrant.fromJson(Map<String, dynamic> json) =>
      _$AccessGrantFromJson(json);
}
