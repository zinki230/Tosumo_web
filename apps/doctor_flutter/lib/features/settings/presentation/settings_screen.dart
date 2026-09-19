import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Paramètres',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section compte
          _SectionHeader(label: 'Compte'),
          _SettingsTile(
            icon: LucideIcons.lock,
            iconColor: AppColors.primary,
            title: 'Changer le mot de passe',
            subtitle: 'Modifier votre mot de passe de connexion',
            onTap: () => context.push('/change-password'),
          ),
          const SizedBox(height: 8),

          // Section application
          _SectionHeader(label: 'Application'),
          _SettingsTile(
            icon: LucideIcons.bell,
            iconColor: Colors.orange,
            title: 'Notifications',
            subtitle: 'Gérer les préférences de notification',
            onTap: () {},
          ),
          _SettingsTile(
            icon: LucideIcons.globe,
            iconColor: Colors.teal,
            title: 'Langue',
            subtitle: 'Français',
            onTap: () {},
          ),
          const SizedBox(height: 8),

          // Section aide
          _SectionHeader(label: 'Aide'),
          _SettingsTile(
            icon: LucideIcons.helpCircle,
            iconColor: Colors.blue,
            title: 'Centre d\'aide',
            subtitle: 'Documentation et FAQ',
            onTap: () {},
          ),
          _SettingsTile(
            icon: LucideIcons.info,
            iconColor: Colors.grey,
            title: 'À propos',
            subtitle: 'Version 1.0.0',
            onTap: () {},
          ),
          const SizedBox(height: 24),

          // Déconnexion
          Container(
            decoration: BoxDecoration(
              color: AppColors.destructive.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.destructive.withValues(alpha: 0.15)),
            ),
            child: ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.destructive.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.logOut, size: 18, color: AppColors.destructive),
              ),
              title: const Text(
                'Se déconnecter',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.destructive,
                ),
              ),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Déconnexion'),
                    content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Annuler'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
                        child: const Text('Déconnecter'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                }
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.mutedForeground.withValues(alpha: 0.7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
        trailing: const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.mutedForeground),
        onTap: onTap,
      ),
    );
  }
}
