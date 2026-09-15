import 'package:freezed_annotation/freezed_annotation.dart';

part 'audit_event.freezed.dart';
part 'audit_event.g.dart';

@freezed
sealed class AuditEvent with _$AuditEvent {
  const factory AuditEvent({
    required String id,
    required String patientId,
    required String accessorId,
    required String accessorName,
    required String timestamp,
    required String mode,
    required String action,
    String? details,
    String? category,
    String? location,
    String? reason,
    String? doctorName,
    bool? patientPresent,
  }) = _AuditEvent;

  factory AuditEvent.fromJson(Map<String, dynamic> json) =>
      _$AuditEventFromJson(json);
}
