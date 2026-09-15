import 'package:freezed_annotation/freezed_annotation.dart';

part 'lab_request.freezed.dart';
part 'lab_request.g.dart';

@freezed
sealed class LabRequest with _$LabRequest {
  const factory LabRequest({
    required String id,
    required String patientId,
    required String doctorId,
    required String consultationId,
    required String testName,
    required String testType,
    @Default('pending') String status,
    @Default('') String resultValue,
    @Default('') String referenceRange,
    @Default('') String interpretation,
    @Default(<Map<String, dynamic>>[]) List<Map<String, dynamic>> attachments,
    required DateTime orderedAt,
    DateTime? completedAt,
    @Default('') String notes,
    Map<String, dynamic>? signature,
    DateTime? signedAt,
  }) = _LabRequest;

  factory LabRequest.fromJson(Map<String, dynamic> json) =>
      _$LabRequestFromJson(json);
}
