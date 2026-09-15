import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/providers/patient_provider.dart';
import '../../../core/utils/localization.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_animated_mount.dart';
import '../../../shared/widgets/app_back_button.dart';

class AccessDashboardScreen extends ConsumerWidget {
  const AccessDashboardScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'ACTIVE': return const Color(0xFF22C55E);
      case 'PENDING': return const Color(0xFFF59E0B);
      case 'REVOKED': return AppColors.destructive;
      case 'EXPIRED': return AppColors.mutedForeground;
      default: return AppColors.mutedForeground;
    }
  }

  IconData _scopeIcon(String scope) {
    switch (scope) {
      case 'FULL': return LucideIcons.shieldCheck;
      case 'EMERGENCY': return LucideIcons.ambulance;
      case 'LAB_RESULTS': return LucideIcons.flaskConical;
      case 'PRESCRIPTIONS': return LucideIcons.pill;
      case 'APPOINTMENTS': return LucideIcons.calendar;
      default: return LucideIcons.eye;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;
    final state = ref.watch(patientProvider);
    final grants = state.accessGrants;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(t?.t('access.title') ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: grants.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.shield, size: 48, color: AppColors.mutedForeground.withAlpha(77)),
                  const SizedBox(height: 16),
                  Text(t?.t('access.noTrusted') ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: grants.length,
              itemBuilder: (context, index) {
                final grant = grants[index];
                final statusColor = _statusColor(grant.status);

                return AnimatedMount(
                  delay: index * 50,
                  animation: 'fadeInUp',
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withAlpha(51)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_scopeIcon(grant.scope), size: 22, color: statusColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(grant.institutionName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor.withAlpha(25),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(grant.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(LucideIcons.moreVertical, size: 18),
                              onSelected: (value) {
                                if (value == 'revoke') {
                                  ref.read(patientProvider.notifier).revokeAccess(grant.id);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(value: 'revoke', child: Text(t?.t('access.revoke') ?? '', style: const TextStyle(color: AppColors.destructive))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(LucideIcons.shield, size: 14, color: AppColors.mutedForeground),
                            const SizedBox(width: 4),
                            Text('${t?.t('access.scope') ?? 'Scope'}: ${grant.scope}', style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(LucideIcons.clock, size: 14, color: AppColors.mutedForeground),
                            const SizedBox(width: 4),
                            Text(AppFormatters.formatDate(grant.grantedAt), style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
                          ],
                        ),
                        if (grant.expiresAt != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(LucideIcons.calendar, size: 14, color: AppColors.mutedForeground),
                              const SizedBox(width: 4),
                              Text('${t?.t('access.expires') ?? 'Expires'}: ${AppFormatters.formatDate(grant.expiresAt!)}', style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
                            ],
                          ),
                        ],
                        if (grant.status == 'PENDING')
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      ref.read(patientProvider.notifier).revokeAccess(grant.id);
                                    },
                                    icon: const Icon(LucideIcons.x, size: 16),
                                    label: Text(t?.t('access.deny') ?? '', style: const TextStyle(color: AppColors.destructive)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: AppColors.destructive),
                                      foregroundColor: AppColors.destructive,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      ref.read(patientProvider.notifier).approveAccess(grant.id);
                                    },
                                    icon: const Icon(LucideIcons.check, size: 16),
                                    label: Text(t?.t('access.approve') ?? ''),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (grant.status == 'ACTIVE' || grant.status == 'EXPIRED')
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  ref.read(patientProvider.notifier).revokeAccess(grant.id);
                                },
                                icon: const Icon(LucideIcons.shieldOff, size: 16),
                                label: Text(t?.t('access.revoke') ?? ''),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.destructive,
                                  side: const BorderSide(color: AppColors.destructive),
                                ),
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
