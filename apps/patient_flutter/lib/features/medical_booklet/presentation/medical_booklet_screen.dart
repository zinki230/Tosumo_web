import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/providers/patient_provider.dart';
import '../../../core/utils/localization.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../shared/widgets/app_animated_mount.dart';
import '../../../shared/widgets/safe_top_spacer.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/models/booklet_entry.dart';
import '../../../core/utils/formatters.dart';

String _guessCategory(String summary) {
  if (summary.contains('cardiaque') || summary.contains('cœur') || summary.contains('tension') || summary.contains('hypertension') || summary.contains('cardio') || summary.contains('blood')) return 'cardiologie';
  if (summary.contains('respiratoire') || summary.contains('asthme') || summary.contains('pulmon') || summary.contains('respirat') || summary.contains('peak')) return 'respiratoire';
  if (summary.contains('allergie') || summary.contains('réaction') || summary.contains('allerg')) return 'allergologie';
  if (summary.contains('dentaire') || summary.contains('dent') || summary.contains('extraction')) return 'dentaire';
  if (summary.contains('urgence') || summary.contains('crise') || summary.contains('aigu')) return 'urgence';
  if (summary.contains('sanguin') || summary.contains('bilan') || summary.contains('analyse') || summary.contains('labo')) return 'laboratoire';
  return 'generaliste';
}

Color _categoryColor(String category) {
  switch (category) {
    case 'cardiologie': return const Color(0xFFEF4444);
    case 'respiratoire': return const Color(0xFF3B82F6);
    case 'allergologie': return const Color(0xFFA855F7);
    case 'dentaire': return const Color(0xFFF59E0B);
    case 'urgence': return const Color(0xFFEF4444);
    case 'laboratoire': return const Color(0xFF8B5CF6);
    default: return const Color(0xFF1677D2);
  }
}

IconData _categoryIcon(String category) {
  switch (category) {
    case 'cardiologie': return LucideIcons.heart;
    case 'respiratoire': return LucideIcons.alertTriangle;
    case 'allergologie': return LucideIcons.eye;
    case 'dentaire': return LucideIcons.activity;
    case 'urgence': return LucideIcons.alertTriangle;
    case 'laboratoire': return LucideIcons.flaskConical;
    default: return LucideIcons.stethoscope;
  }
}

Color _typeColor(String type) {
  switch (type) {
    case 'Urgence': return const Color(0xFFEF4444);
    case 'Suivi': return const Color(0xFFA855F7);
    default: return const Color(0xFF1677D2);
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'completed': return const Color(0xFFD4A72C);
    case 'ongoing': return const Color(0xFFF59E0B);
    case 'follow-up': return const Color(0xFFEF4444);
    default: return const Color(0xFF64748B);
  }
}

class MedicalBookletScreen extends ConsumerWidget {
  const MedicalBookletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;
    final state = ref.watch(patientProvider);
    final entries = state.bookletEntries;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SafeTopSpacer(extra: 0),
          AnimatedMount(
            animation: 'fadeInUp',
            delay: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t?.t('booklet.title') ?? '',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  t?.t('booklet.subtitle') ?? '',
                  style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AnimatedMount(
            delay: 80,
            animation: 'fadeInUp',
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary.withAlpha(25), AppColors.accent.withAlpha(13), AppColors.background],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primary.withAlpha(25)),
              ),
              child: Text(
                t?.t('booklet.info') ?? '',
                style: TextStyle(fontSize: 12, color: AppColors.mutedForeground.withAlpha(204)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedMount(
            delay: 120,
            animation: 'fadeInUp',
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border.withAlpha(102)),
                boxShadow: [AppShadows.soft],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        t?.t('booklet.timeline') ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.white),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push('/patient/recipes'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          t?.t('booklet.prescriptions') ?? '',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.mutedForeground),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (state.consultations.isNotEmpty) ...[
            _buildConsultationsSection(context, state.consultations, t),
            const SizedBox(height: 24),
          ],
          if (state.loading)
            ...List.generate(3, (i) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: CardSkeleton(),
            ))
          else if (entries.isEmpty && state.consultations.isEmpty)
            _buildEmptyState(context, t)
          else
            _buildTimeline(context, entries, t),
        ],
      ),
    );
  }

  Widget _buildConsultationsSection(BuildContext context, List<BookletEntry> items, dynamic t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.stethoscope, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              t?.t('booklet.consultations') ?? 'Consultations',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((c) => _buildConsultationCard(context, c, t)).toList(),
      ],
    );
  }

  Widget _buildConsultationCard(BuildContext context, BookletEntry c, dynamic t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _showConsultation(context, c, t),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withAlpha(51)),
            boxShadow: [AppShadows.card],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(LucideIcons.stethoscope, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.summary,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    if (c.doctorName != null && c.doctorName!.isNotEmpty)
                      Text(
                        c.doctorName!,
                        style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      AppFormatters.formatDate(c.visitDate),
                      style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                    ),
                    if (c.diagnosis != null && c.diagnosis!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
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
                              t?.t('booklet.dx') ?? 'DX',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF15803D), letterSpacing: 1),
                            ),
                            Expanded(
                              child: Text(
                                c.diagnosis!,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF166534)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }

  void _showConsultation(BuildContext context, BookletEntry c, dynamic t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c.summary),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (c.doctorName != null && c.doctorName!.isNotEmpty)
                _infoLine(t?.t('booklet.doctor') ?? 'Médecin', c.doctorName!),
              _infoLine(t?.t('booklet.date') ?? 'Date', AppFormatters.formatDate(c.visitDate)),
              if (c.diagnosis != null && c.diagnosis!.isNotEmpty)
                _infoLine(t?.t('booklet.dx') ?? 'Diagnostic', c.diagnosis!),
              if (c.symptoms != null && c.symptoms!.isNotEmpty)
                _infoLine(t?.t('booklet.symptoms') ?? 'Symptômes', c.symptoms!),
              if (c.details.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  c.details,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t?.t('common.close') ?? 'Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, dynamic t) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Column(
        children: [
          Icon(LucideIcons.stethoscope, size: 64, color: AppColors.mutedForeground.withAlpha(77)),
          const SizedBox(height: 16),
          Text(
            t?.t('booklet.noEntries') ?? '',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            t?.t('booklet.noEntriesDesc') ?? '',
            style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.push('/patient/doctor-search'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLight,
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
              elevation: 0,
            ),
            child: Text(t?.t('booklet.bookAppointment') ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, List<BookletEntry> entries, dynamic t) {
    return Stack(
      children: [
        Positioned(
          left: 19,
          top: 0,
          bottom: 0,
          child: Container(
            width: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.accent, AppColors.muted],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        Column(
          children: entries.map((entry) => _buildEntryCard(context, entry, t)).toList(),
        ),
      ],
    );
  }

  Widget _buildEntryCard(BuildContext context, BookletEntry entry, dynamic t) {
    final category = _guessCategory(entry.summary);
    final color = _categoryColor(category);
    final icon = _categoryIcon(category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: AnimatedMount(
        animation: 'fadeInUp',
        delay: 100,
        child: GestureDetector(
                      onTap: () => context.push('/patient/booklet/${entry.id}'),
          child: Container(
            margin: const EdgeInsets.only(left: 12),
            child: Stack(
              children: [
                Positioned(
                  left: -33,
                  top: 20,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 4),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border.withAlpha(102)),
                    boxShadow: [AppShadows.card],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, size: 20, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.summary,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                      ),
                                      if (entry.doctorName != null) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(LucideIcons.user, size: 12, color: AppColors.mutedForeground),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                entry.doctorName!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                                              ),
                                            ),
                                            if (entry.doctorSpecialty != null) ...[
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  '(${entry.doctorSpecialty})',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(fontSize: 10, color: AppColors.mutedForeground.withAlpha(153)),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(LucideIcons.chevronRight, size: 16, color: AppColors.mutedForeground.withAlpha(102)),
                              ],
                            ),
                            if (entry.diagnosis != null && entry.diagnosis!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
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
                                      t?.t('booklet.dx') ?? '',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF15803D), letterSpacing: 1),
                                    ),
                                    Expanded(
                                      child: Text(
                                        entry.diagnosis!,
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF166534)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(LucideIcons.building, size: 12, color: AppColors.mutedForeground),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        entry.facility,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text('—', style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${AppFormatters.formatDate(entry.visitDate)} ${t?.t('booklet.at') ?? ''} ${AppFormatters.formatTime(entry.visitDate)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _buildChip(t?.t('booklet.categories.$category') ?? category, color.withAlpha(25), color),
                                if (entry.consultationType != null)
                                  _buildChip(entry.consultationType!, _typeColor(entry.consultationType!).withAlpha(25), _typeColor(entry.consultationType!)),
                                if (entry.status != null)
                                  _buildChip(
                                    t?.t('booklet.${entry.status}') ?? entry.status!,
                                    _statusColor(entry.status!).withAlpha(25),
                                    _statusColor(entry.status!),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: fg),
      ),
    );
  }
}
