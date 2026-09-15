import 'package:freezed_annotation/freezed_annotation.dart';

part 'booklet_entry.freezed.dart';
part 'booklet_entry.g.dart';

@freezed
sealed class BookletEntry with _$BookletEntry {
  const factory BookletEntry({
    required String id,
    required String patientId,
    required String visitDate,
    required String facility,
    required String summary,
    required String details,
    String? doctorName,
    String? doctorSpecialty,
    String? diagnosis,
    String? prescription,
    int? attachments,
    String? status,
    String? consultationType,
    String? symptoms,
    String? doctorNotes,
    @Default([]) List<TestRequest> testsRequested,
    @Default([]) List<LabResult> labResults,
    @Default([]) List<PrescribedMedication> prescriptions,
    String? recommendations,
    DoctorSignature? signature,
  }) = _BookletEntry;

  factory BookletEntry.fromJson(Map<String, dynamic> json) =>
      _$BookletEntryFromJson(json);
}

@freezed
sealed class TestRequest with _$TestRequest {
  const factory TestRequest({
    required String name,
    required String status,
  }) = _TestRequest;

  factory TestRequest.fromJson(Map<String, dynamic> json) =>
      _$TestRequestFromJson(json);
}

@freezed
sealed class LabResult with _$LabResult {
  const factory LabResult({
    required String testName,
    required String resultValue,
    required String referenceRange,
    required String interpretation,
    required String dateReceived,
  }) = _LabResult;

  factory LabResult.fromJson(Map<String, dynamic> json) =>
      _$LabResultFromJson(json);
}

@freezed
sealed class PrescribedMedication with _$PrescribedMedication {
  const factory PrescribedMedication({
    required String drugName,
    required String dosage,
    required String frequency,
    required String duration,
    required String instructions,
    @Default('') String id,
    @Default('') String consultationId,
    @Default('') String doctorName,
    @Default(false) bool isCompleted,
  }) = _PrescribedMedication;

  factory PrescribedMedication.fromJson(Map<String, dynamic> json) =>
      _$PrescribedMedicationFromJson(json);
}

@freezed
sealed class DoctorSignature with _$DoctorSignature {
  const factory DoctorSignature({
    required String doctorName,
    required String licenseId,
    required String hospitalName,
    required String signedAt,
  }) = _DoctorSignature;

  factory DoctorSignature.fromJson(Map<String, dynamic> json) =>
      _$DoctorSignatureFromJson(json);
}
