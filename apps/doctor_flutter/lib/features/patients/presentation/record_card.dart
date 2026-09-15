import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../domain/models/consultation.dart';
import '../../../domain/models/imaging_request.dart';
import '../../../domain/models/lab_request.dart';
import '../../../domain/models/prescription.dart';
import '../../../domain/models/vital_signs.dart';
import '../../../shared/widgets/app_card.dart';

enum RecordType { consultation, lab, imaging, prescription }

Color recordStatusColor(String status) {
  switch (status) {
    case 'completed':
    case 'finalized':
    case 'active':
      return AppColors.success;
    case 'pending':
    case 'draft':
    case 'ordered':
      return AppColors.accent;
    case 'cancelled':
      return AppColors.mutedForeground;
    default:
      return AppColors.mutedForeground;
  }
}

String recordStatusLabel(String status) {
  switch (status) {
    case 'completed':
    case 'finalized':
      return 'Terminé';
    case 'active':
      return 'Actif';
    case 'pending':
    case 'ordered':
      return 'En attente';
    case 'draft':
      return 'Brouillon';
    case 'cancelled':
      return 'Annulé';
    default:
      return status;
  }
}

/// Tappable card used in the doctor's patient "Dossier" timeline.
class RecordCard extends StatelessWidget {
  final dynamic record;
  final RecordType type;
  final VoidCallback? onTap;

  const RecordCard({
    required this.record,
    required this.type,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(onTap: onTap, child: _RecordBody(record: record, type: type));
  }
}

/// Full content of a record, without the surrounding tappable card.
/// Used by the dedicated record detail screen.
class RecordDetailContent extends StatelessWidget {
  final dynamic record;
  final RecordType type;

  const RecordDetailContent({
    required this.record,
    required this.type,
    super.key,
  });

  @override
  Widget build(BuildContext context) => _RecordBody(record: record, type: type);
}

class _RecordBody extends StatelessWidget {
  final dynamic record;
  final RecordType type;

  const _RecordBody({required this.record, required this.type});

  @override
  Widget build(BuildContext context) {
    return switch (type) {
      RecordType.consultation => _consultationDocument(record as Consultation),
      RecordType.lab => _labCard(record as LabRequest),
      RecordType.imaging => _imagingCard(record as ImagingRequest),
      RecordType.prescription => _prescriptionCard(record as Prescription),
    };
  }
}

Widget _recordHeader(IconData icon, Color color, DateTime date, String status) {
  return Row(
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(
        DateFormat('dd/MM/yyyy').format(date),
        style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
      ),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: recordStatusColor(status).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          recordStatusLabel(status),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: recordStatusColor(status),
          ),
        ),
      ),
    ],
  );
}

Widget _consultationDocument(Consultation c) {
  final typeLabel = switch (c.consultationType) {
    'Urgence' => 'Urgence',
    'Suivi' => 'Suivi',
    'Routine' => 'Routine',
    _ => c.consultationType.isEmpty ? 'Routine' : c.consultationType,
  };
  final typeColor = switch (c.consultationType) {
    'Urgence' => AppColors.destructive,
    'Suivi' => AppColors.accent,
    _ => AppColors.primary,
  };
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(LucideIcons.stethoscope, size: 20, color: typeColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consultation du ${DateFormat('dd/MM/yyyy').format(c.date)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.foreground),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: typeColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const Divider(height: 28),
      _docSection('Motif de consultation', c.chiefComplaint.isNotEmpty ? c.chiefComplaint : null),
      if (c.symptoms.isNotEmpty) ...[
        _docSection('Symptômes', c.symptoms.join(' • ')),
      ],
      if (c.vitals != null && _hasVitals(c.vitals!)) ...[
        _docSectionHeader('Constantes vitales'),
        const SizedBox(height: 8),
        _buildVitalsGrid(c.vitals!),
      ],
      if (c.diagnosis.isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            border: Border.all(color: const Color(0xFFBBF7D0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DIAGNOSTIC',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: const Color(0xFF15803D)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c.diagnosis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF166534)),
                ),
              ),
            ],
          ),
        ),
      ],
      if (c.differentialDiagnosis.isNotEmpty)
        _docSection('Diagnostic différentiel', c.differentialDiagnosis),
      if (c.physicalExamination.isNotEmpty)
        _docSection('Examen clinique', c.physicalExamination),
      if (c.treatment.isNotEmpty)
        _docSection('Traitement', c.treatment),
      if (c.followUpPlan.isNotEmpty)
        _docSection('Plan de suivi', c.followUpPlan),
      if (c.recommendations.isNotEmpty)
        _docSection('Recommandations', c.recommendations),
      if (c.doctorNotes.isNotEmpty)
        _docSection('Notes du médecin', c.doctorNotes),
      if (c.status == 'finalized' && c.signedAt != null) ...[
        const Divider(height: 28),
        Row(
          children: [
            const Icon(LucideIcons.badgeCheck, size: 16, color: AppColors.success),
            const SizedBox(width: 8),
            Text(
              'Signé le ${DateFormat('dd/MM/yyyy').format(c.signedAt!)}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success),
            ),
          ],
        ),
      ],
    ],
  );
}

Widget _docSectionHeader(String label) {
  return Text(
    label.toUpperCase(),
    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.mutedForeground),
  );
}

Widget _docSection(String label, String? value) {
  if (value == null || value.trim().isEmpty) {
    return const SizedBox.shrink();
  }
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _docSectionHeader(label),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 13, color: AppColors.foreground, height: 1.4),
        ),
      ],
    ),
  );
}

bool _hasVitals(VitalSigns v) {
  return v.bloodPressureSystolic != 0 || v.heartRate != 0 || v.temperature != 0 || v.respiratoryRate != 0 || v.oxygenSaturation != 0;
}

Widget _buildVitalsGrid(VitalSigns v) {
  return Row(
    children: [
      _docVital('TAS', v.bloodPressureSystolic != 0 ? '${v.bloodPressureSystolic}/${v.bloodPressureDiastolic}' : '—'),
      const SizedBox(width: 8),
      _docVital('FC', v.heartRate != 0 ? '${v.heartRate}' : '—'),
      const SizedBox(width: 8),
      _docVital('T°', v.temperature != 0 ? v.temperature.toStringAsFixed(1) : '—'),
      const SizedBox(width: 8),
      _docVital('FR', v.respiratoryRate != 0 ? '${v.respiratoryRate}' : '—'),
    ],
  );
}

Widget _docVital(String label, String value) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.muted.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.foreground),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}

Widget _labCard(LabRequest l) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _recordHeader(LucideIcons.flaskConical, AppColors.accent, l.orderedAt, l.status),
      const SizedBox(height: 8),
      Text(
        l.testName,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground),
      ),
      if (l.testType.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(l.testType, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
      ],
      if (l.resultValue.isNotEmpty) ...[
        const SizedBox(height: 6),
        _InfoRow(icon: LucideIcons.activity, label: 'Résultat', value: l.resultValue),
        if (l.interpretation.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l.interpretation,
              style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
            ),
          ),
      ],
    ],
  );
}

Widget _imagingCard(ImagingRequest i) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _recordHeader(LucideIcons.scan, AppColors.alert, i.orderedAt, i.status),
      const SizedBox(height: 8),
      Text(
        i.imagingType,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground),
      ),
      if (i.bodyPart.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(i.bodyPart, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
      ],
      if (i.findings.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(
          i.findings,
          style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ],
  );
}

Widget _prescriptionCard(Prescription p) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _recordHeader(LucideIcons.pill, AppColors.success, p.issueDate, p.status),
      const SizedBox(height: 8),
      ...p.medications.map((m) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.drugName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground),
            ),
            const SizedBox(height: 2),
            Text(
              [m.dosage, m.frequency, m.duration].where((e) => e.isNotEmpty).join(' · '),
              style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
            ),
          ],
        ),
      )),
      if (p.notes.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          p.notes,
          style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
      const SizedBox(height: 4),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Icon(LucideIcons.eye, size: 12, color: AppColors.mutedForeground),
          const SizedBox(width: 4),
          Text(
            'Voir l\'ordonnance',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.mutedForeground),
          ),
        ],
      ),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.mutedForeground),
          const SizedBox(width: 8),
          Text(
            '$label : ',
            style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.foreground),
            ),
          ),
        ],
      ),
    );
  }
}
