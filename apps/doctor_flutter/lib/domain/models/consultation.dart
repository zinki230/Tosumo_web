import 'package:freezed_annotation/freezed_annotation.dart';
import 'vital_signs.dart';

part 'consultation.freezed.dart';
part 'consultation.g.dart';

@freezed
sealed class Consultation with _$Consultation {
  const factory Consultation({
    required String id,
    required String patientId,
    required String doctorId,
    required String appointmentId,
    required DateTime date,
    @Default(<String>[]) List<String> symptoms,
    @Default('') String diagnosis,
    @Default('') String clinicalNotes,
    VitalSigns? vitals,
    @Default('') String physicalExamination,
    @Default('') String treatment,
    @Default('') String followUpPlan,
    @Default('mild') String severity,
    @Default('Routine') String consultationType,
    @Default('') String facility,
    @Default('') String chiefComplaint,
    @Default('') String differentialDiagnosis,
    @Default('') String doctorNotes,
    @Default('') String recommendations,
    @Default(<Map<String, dynamic>>[]) List<Map<String, dynamic>> orderedExams,
    Map<String, dynamic>? signature,
    @Default('draft') String status,
    DateTime? signedAt,
    required DateTime createdAt,
  }) = _Consultation;

  factory Consultation.fromJson(Map<String, dynamic> json) =>
      _$ConsultationFromJson(json);
}
