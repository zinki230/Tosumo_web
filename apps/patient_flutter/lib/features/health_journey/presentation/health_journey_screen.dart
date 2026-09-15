import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/providers/patient_provider.dart';
import '../../../core/utils/localization.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_animated_mount.dart';
import '../../../shared/widgets/app_back_button.dart';

class HealthJourneyScreen extends ConsumerWidget {
  const HealthJourneyScreen({super.key});

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'record': return LucideIcons.stethoscope;
      case 'appointment': return LucideIcons.calendar;
      case 'lab': return LucideIcons.flaskConical;
      case 'procedure': return LucideIcons.heartPulse;
      case 'surgery': return LucideIcons.activity;
      case 'vaccination': return LucideIcons.syringe;
      case 'discharge': return LucideIcons.home;
      default: return LucideIcons.fileText;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'record': return AppColors.primary;
      case 'appointment': return const Color(0xFF8B5CF6);
      case 'lab': return const Color(0xFF22C55E);
      case 'procedure': return const Color(0xFFF97316);
      case 'surgery': return AppColors.destructive;
      case 'vaccination': return const Color(0xFF06B6D4);
      case 'discharge': return const Color(0xFFD4A72C);
      default: return AppColors.mutedForeground;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;
    final state = ref.watch(patientProvider);
    final entries = state.healthJourney;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(t?.t('journey.title') ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: entries.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.map, size: 48, color: AppColors.mutedForeground.withAlpha(77)),
                  const SizedBox(height: 16),
                  Text(t?.t('journey.noEntries') ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final icon = _categoryIcon(entry.category);
                final color = _categoryColor(entry.category);

                return AnimatedMount(
                  delay: index * 40,
                  animation: 'fadeInUp',
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 48,
                          child: Column(
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
                                child: Icon(icon, size: 18, color: color),
                              ),
                              if (index < entries.length - 1)
                                Expanded(
                                  child: Container(width: 2, color: AppColors.border),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withAlpha(25),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(entry.category, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                                    ),
                                    const Spacer(),
                                    Text(AppFormatters.formatDate(entry.date), style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(entry.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                if (entry.subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(entry.subtitle, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
                                ],
                                if (entry.description.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(entry.description, style: const TextStyle(fontSize: 13, color: AppColors.foreground)),
                                ],
                                if (entry.institution.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(LucideIcons.hospital, size: 14, color: AppColors.mutedForeground),
                                      const SizedBox(width: 4),
                                      Text(entry.institution, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                                    ],
                                  ),
                                ],
                                if (entry.doctorName != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(LucideIcons.user, size: 14, color: AppColors.mutedForeground),
                                      const SizedBox(width: 4),
                                      Text(entry.doctorName!, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
