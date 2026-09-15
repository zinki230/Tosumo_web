import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/providers/patient_provider.dart';
import '../../../core/utils/localization.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_animated_mount.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../core/utils/formatters.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _typeIcon(String type) {
    switch (type) {
      case 'card_update': return LucideIcons.creditCard;
      case 'access_request': return LucideIcons.shield;
      case 'appointment': return LucideIcons.calendar;
      case 'lab_result': return LucideIcons.flaskConical;
      default: return LucideIcons.bell;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'card_update': return AppColors.primary;
      case 'access_request': return AppColors.accent;
      case 'appointment': return const Color(0xFF8B5CF6);
      case 'lab_result': return const Color(0xFF22C55E);
      default: return AppColors.mutedForeground;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;
    final state = ref.watch(patientProvider);
    final notifications = state.notifications;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(t?.t('common.notifications') ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          if (notifications.any((n) => !n.read))
            TextButton(
              onPressed: () => ref.read(patientProvider.notifier).markAllNotificationsRead(),
              child: Text(t?.t('common.markAllRead') ?? '', style: TextStyle(fontSize: 13, color: AppColors.primary)),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.bell, size: 48, color: AppColors.mutedForeground.withAlpha(77)),
                  const SizedBox(height: 16),
                  Text(t?.t('common.noNotifications') ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, _) => Container(height: 1, color: AppColors.border.withAlpha(77), margin: const EdgeInsets.symmetric(horizontal: 60)),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                final icon = _typeIcon(notif.type);
                final color = _typeColor(notif.type);

                return AnimatedMount(
                  delay: index * 50,
                  animation: 'fadeInUp',
                  child: InkWell(
                    onTap: () {
                      ref.read(patientProvider.notifier).markNotificationRead(notif.id);
                      if (notif.type == 'card_update') { context.push('/patient/card'); }
                      else if (notif.type == 'appointment') { context.go('/patient/home'); }
                      else if (notif.type == 'access_request') { context.push('/patient/access'); }
                      else if (notif.type == 'lab_result') { context.push('/patient/booklet'); }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(14)),
                                child: Icon(icon, size: 22, color: color),
                              ),
                              if (!notif.read)
                                Positioned(
                                  top: 4, right: 4,
                                  child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.destructive, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: AppColors.white, width: 2)))),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notif.title,
                                  style: TextStyle(fontSize: 14, fontWeight: notif.read ? FontWeight.w500 : FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  notif.message,
                                  style: TextStyle(fontSize: 13, color: notif.read ? AppColors.mutedForeground : AppColors.foreground),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppFormatters.formatRelativeTime(notif.time),
                                  style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
