import 'package:freezed_annotation/freezed_annotation.dart';
import 'medication_item.dart';

part 'prescription.freezed.dart';
part 'prescription.g.dart';

@freezed
sealed class Prescription with _$Prescription {
  const factory Prescription({
    required String id,
    required String patientId,
    required String doctorId,
    required String consultationId,
    @Default(<MedicationItem>[]) List<MedicationItem> medications,
    @Default('') String notes,
    required DateTime issueDate,
    required DateTime expiryDate,
    @Default(false) bool isRenewed,
    @Default('active') String status,
    required DateTime createdAt,
    Map<String, dynamic>? signature,
    DateTime? signedAt,
  }) = _Prescription;

  factory Prescription.fromJson(Map<String, dynamic> json) =>
      _$PrescriptionFromJson(json);
}
