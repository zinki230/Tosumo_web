import 'package:freezed_annotation/freezed_annotation.dart';

part 'emergency_session.freezed.dart';
part 'emergency_session.g.dart';

@freezed
sealed class EmergencySession with _$EmergencySession {
  const factory EmergencySession({
    required String id,
    required String doctorId,
    required String patientId,
    required String timestamp,
    required String justification,
    @Default(false) bool active,
  }) = _EmergencySession;

  factory EmergencySession.fromJson(Map<String, dynamic> json) =>
      _$EmergencySessionFromJson(json);
}
