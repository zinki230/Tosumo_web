import 'package:freezed_annotation/freezed_annotation.dart';

part 'imaging_request.freezed.dart';
part 'imaging_request.g.dart';

@freezed
sealed class ImagingRequest with _$ImagingRequest {
  const factory ImagingRequest({
    required String id,
    required String patientId,
    required String doctorId,
    required String consultationId,
    required String imagingType,
    required String bodyPart,
    @Default('pending') String status,
    @Default('') String findings,
    @Default('') String impression,
    @Default(<Map<String, dynamic>>[]) List<Map<String, dynamic>> attachments,
    required DateTime orderedAt,
    DateTime? completedAt,
    @Default('') String notes,
    Map<String, dynamic>? signature,
    DateTime? signedAt,
  }) = _ImagingRequest;

  factory ImagingRequest.fromJson(Map<String, dynamic> json) =>
      _$ImagingRequestFromJson(json);
}
