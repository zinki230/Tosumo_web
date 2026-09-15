import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/providers/patient_provider.dart';
import '../../../core/utils/localization.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_animated_mount.dart';
import '../../../shared/widgets/app_back_button.dart';

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  IconData _actionIcon(String action) {
    switch (action) {
      case 'VIEW': return LucideIcons.eye;
      case 'UPDATE': return LucideIcons.pencil;
      case 'CREATE': return LucideIcons.plusCircle;
      case 'DELETE': return LucideIcons.trash2;
      case 'ACCESS_GRANTED': return LucideIcons.shieldCheck;
      case 'ACCESS_REVOKED': return LucideIcons.shieldOff;
      case 'EMERGENCY_ACCESS': return LucideIcons.ambulance;
      default: return LucideIcons.history;
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'VIEW': return AppColors.primary;
      case 'UPDATE': return const Color(0xFFF59E0B);
      case 'CREATE': return const Color(0xFF22C55E);
      case 'DELETE': return AppColors.destructive;
      case 'ACCESS_GRANTED': return const Color(0xFF22C55E);
      case 'ACCESS_REVOKED': return AppColors.destructive;
      case 'EMERGENCY_ACCESS': return AppColors.destructive;
      default: return AppColors.mutedForeground;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;
    final state = ref.watch(patientProvider);
    final events = state.auditLogs;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(t?.t('audit.title') ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: events.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.history, size: 48, color: AppColors.mutedForeground.withAlpha(77)),
                  const SizedBox(height: 16),
                  Text(t?.t('audit.noEvents') ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                final icon = _actionIcon(event.action);
                final color = _actionColor(event.action);

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
                              if (index < events.length - 1)
                                Expanded(child: Container(width: 2, color: AppColors.border)),
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
                                      decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(4)),
                                      child: Text(event.action.replaceAll('_', ' '), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                                    ),
                                    const Spacer(),
                                    Text(AppFormatters.formatDateTime(event.timestamp), style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(LucideIcons.user, size: 14, color: AppColors.mutedForeground),
                                    const SizedBox(width: 4),
                                    Text(event.accessorName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                if (event.mode.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(LucideIcons.wifi, size: 14, color: AppColors.mutedForeground),
                                      const SizedBox(width: 4),
                                      Text(event.mode, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
                                    ],
                                  ),
                                ],
                                if (event.details != null && event.details!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(event.details!, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
                                ],
                                if (event.location != null && event.location!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(LucideIcons.mapPin, size: 14, color: AppColors.mutedForeground),
                                      const SizedBox(width: 4),
                                      Text(event.location!, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
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
