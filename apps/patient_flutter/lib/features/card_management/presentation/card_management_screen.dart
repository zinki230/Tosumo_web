import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/providers/patient_provider.dart';
import '../../../core/utils/localization.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_back_button.dart';

class CardManagementScreen extends ConsumerWidget {
  const CardManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;
    final state = ref.watch(patientProvider);
    final card = state.card;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(t?.t('cardManagement.title') ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          if (card != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.cardBlueStart, AppColors.cardBlueMid, AppColors.cardBlueEnd]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.creditCard, color: AppColors.white, size: 20),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: card.status == 'ACTIVE' ? const Color(0xFF22C55E).withAlpha(25) : AppColors.destructive.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(card.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: card.status == 'ACTIVE' ? const Color(0xFF22C55E) : AppColors.destructive)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(card.token, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.white, letterSpacing: 2)),
                  const SizedBox(height: 16),
                  Text(t?.t('cardManagement.issued') ?? '', style: TextStyle(fontSize: 11, color: AppColors.white.withAlpha(179))),
                  Text(card.issuedAt, style: const TextStyle(fontSize: 13, color: AppColors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          const SizedBox(height: 24),
          _ActionTile(
            icon: LucideIcons.refreshCw,
            title: t?.t('card.reissue') ?? '',
            subtitle: t?.t('cardManagement.reissueSubtitle') ?? '',
            onTap: () => ref.read(patientProvider.notifier).reissueCard(),
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: LucideIcons.eyeOff,
            title: t?.t('cardManagement.freeze') ?? '',
            subtitle: t?.t('cardManagement.freezeSubtitle') ?? '',
            onTap: () => _freezeCard(context, ref),
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: LucideIcons.shield,
            title: t?.t('cardManagement.security') ?? '',
            subtitle: t?.t('cardManagement.securitySubtitle') ?? '',
            onTap: () => _showSecurity(context, card?.token ?? ''),
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: LucideIcons.helpCircle,
            title: t?.t('cardManagement.help') ?? '',
            subtitle: t?.t('cardManagement.helpSubtitle') ?? '',
            onTap: () => _showHelp(context),
          ),
        ],
      ),
    );
  }

  void _freezeCard(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Geler la carte'),
        content: const Text(
            'Le gel de la carte vous protège en cas de perte ou de vol. '
            'Cette action n\'est pour l\'instant réalisable que par le support. '
            'Vous pouvez demander un renouvellement pour une nouvelle carte.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(patientProvider.notifier).reissueCard();
            },
            child: const Text('Renouveler'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

  void _showSecurity(BuildContext context, String token) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Informations de sécurité'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Votre carte est protégée. Conservez vos données confidentielles et ne les partagez jamais.'),
            const SizedBox(height: 12),
            Text('Identifiant : $token', style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assistance'),
        content: const Text(
            'Notre équipe d\'assistance est disponible au +237 222 12 34 56 '
            '(du lundi au vendredi, 8h-18h).'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
        trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.mutedForeground),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}