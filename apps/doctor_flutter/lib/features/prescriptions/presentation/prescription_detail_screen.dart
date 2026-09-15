import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/prescription.dart';
import '../../../domain/models/medication_item.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';

class PrescriptionDetailScreen extends StatelessWidget {
  final Prescription prescription;
  final String patientName;

  const PrescriptionDetailScreen({
    super.key,
    required this.prescription,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ordonnance'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
        children: [
          const SizedBox(height: 8),
          _buildHeader(),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Médicaments prescrits'),
                const SizedBox(height: 8),
                ...prescription.medications.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MedicationRow(medication: m),
                )),
                if (prescription.medications.isEmpty)
                  const Text(
                    'Aucun médicament',
                    style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
                  ),
              ],
            ),
          ),
          if (prescription.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Instructions'),
                  const SizedBox(height: 8),
                  Text(
                    prescription.notes,
                    style: const TextStyle(fontSize: 14, color: AppColors.foreground),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Informations'),
                const SizedBox(height: 8),
                _InfoRow(LucideIcons.calendar, 'Date d\'émission',
                    DateFormat('dd/MM/yyyy').format(prescription.issueDate)),
                const Divider(height: 20),
                _InfoRow(LucideIcons.calendarX, 'Expiration',
                    DateFormat('dd/MM/yyyy').format(prescription.expiryDate)),
                if (prescription.isRenewed) ...[
                  const Divider(height: 20),
                  const _InfoRow(LucideIcons.refreshCw, 'Statut', 'Renouvelée'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final active = prescription.status == 'active';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.cardBlueMid],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(LucideIcons.pill, size: 22, color: AppColors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${prescription.medications.length} médicament(s) prescrit(s)',
                      style: TextStyle(fontSize: 12, color: AppColors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.success.withValues(alpha: 0.25)
                      : AppColors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  active ? 'Actif' : 'Inactif',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MedicationRow extends StatelessWidget {
  final MedicationItem medication;

  const _MedicationRow({required this.medication});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Icon(LucideIcons.pill, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                medication.drugName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                medication.dosage.isEmpty
                    ? 'Fréquence: ${medication.frequency}'
                    : medication.dosage,
                style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (medication.frequency.isNotEmpty) medication.frequency,
                  if (medication.duration.isNotEmpty) medication.duration,
                ].join(' · '),
                style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
              ),
              if (medication.route.isNotEmpty && medication.route != 'oral') ...[
                const SizedBox(height: 2),
                Text(
                  'Voie: ${medication.route}',
                  style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                ),
              ],
              if (medication.instructions.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  medication.instructions,
                  style: const TextStyle(fontSize: 12, color: AppColors.darkText),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.mutedForeground),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.foreground,
          ),
        ),
      ],
    );
  }
}