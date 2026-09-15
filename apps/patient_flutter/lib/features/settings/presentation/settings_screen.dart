import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/providers/patient_provider.dart';
import '../../../core/utils/localization.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/app_back_button.dart';

final _settingsStorage = FlutterSecureStorage();

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pushEnabled = true;
  bool _emailEnabled = false;
  bool _twoFactorEnabled = false;
  String _emergencyName = '';
  String _emergencyRelationship = '';
  String _emergencyPhone = '';
  bool _showToast = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final storage = _settingsStorage;
      final push = await storage.read(key: 'tosumo_push_enabled');
      final email = await storage.read(key: 'tosumo_email_enabled');
      final twofa = await storage.read(key: 'tosumo_twofactor_enabled');
      final emergencyJson = await storage.read(key: 'tosumo_emergency_contact');
      if (mounted) {
        setState(() {
          _pushEnabled = push != 'false';
          _emailEnabled = email == 'true';
          _twoFactorEnabled = twofa == 'true';
          if (emergencyJson != null) {
            try {
              final data = Map<String, dynamic>.from(
                  const JsonDecoder().convert(emergencyJson));
              _emergencyName = data['name']?.toString() ?? '';
              _emergencyRelationship = data['relationship']?.toString() ?? '';
              _emergencyPhone = data['phone']?.toString() ?? '';
            } catch (_) {}
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    try {
      final storage = _settingsStorage;
      await storage.write(key: 'tosumo_push_enabled', value: _pushEnabled.toString());
      await storage.write(key: 'tosumo_email_enabled', value: _emailEnabled.toString());
      await storage.write(key: 'tosumo_twofactor_enabled', value: _twoFactorEnabled.toString());
      await storage.write(key: 'tosumo_emergency_contact', value: const JsonEncoder().convert({
        'name': _emergencyName,
        'relationship': _emergencyRelationship,
        'phone': _emergencyPhone,
      }));
      final synced = await ref.read(patientProvider.notifier).updateEmergencyContact(
        name: _emergencyName,
        relationship: _emergencyRelationship,
        phone: _emergencyPhone,
      );
      if (!mounted) return;
      if (!synced) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paramètres enregistrés localement — synchronisation du contact d\'urgence impossible.')),
        );
      }
      setState(() {
        _saved = true;
        _showToast = true;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showToast = false);
      });
    } catch (_) {}
  }

  Future<void> _changePin() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Changer le code PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Saisissez un nouveau code à 6 chiffres. Il est stocké en local sur cet appareil.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Nouveau PIN',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) return;
    await _settingsStorage.write(key: 'tosumo_pin', value: result);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN mis à jour (local)')),
      );
    }
  }

  Future<void> _exportData() async {
    final state = ref.read(patientProvider);
    final data = {
      'patientId': state.patientId,
      'name': state.patient?.name,
      'bloodType': state.patient?.bloodType,
      'allergies': state.patient?.allergies,
      'chronicConditions': state.patient?.chronicConditions,
      'notifications': state.notifications.length,
      'appointments': state.appointments.length,
      'grants': state.accessGrants.length,
      'exportedAt': DateTime.now().toIso8601String(),
    };
    await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Données exportées en JSON — copiées dans le presse-papiers.')),
      );
    }
  }

  Future<void> _signOut() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/signin');
  }

  Future<void> _requestDeleteAccount() async {
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le compte'),
        content: const Text('La suppression définitive du compte n\'est pas disponible dans cette version. Vous pouvez continuer à utiliser l\'application en mode démonstration.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Fermer')),
        ],
      ),
    );
  }

  void _showLanguagePicker() {
    final locale = ref.read(localeProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              _LanguageOption(
                label: 'Français',
                subtitle: 'Langue par défaut',
                selected: locale == 'fr',
                onTap: () {
                  ref.read(localeProvider.notifier).setLocale('fr');
                  saveLanguage('fr');
                  Navigator.pop(ctx);
                },
              ),
              _LanguageOption(
                label: 'English',
                subtitle: 'Default language',
                selected: locale == 'en',
                onTap: () {
                  ref.read(localeProvider.notifier).setLocale('en');
                  saveLanguage('en');
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(t?.t('settings.title') ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              // Language
              _SettingsSection(
                title: t?.t('settings.language') ?? '',
                children: [
                  _SettingsTile(
                    icon: LucideIcons.globe,
                    title: locale == 'fr' ? (t?.t('settings.languageFr') ?? 'Français') : (t?.t('settings.languageEn') ?? 'English'),
                    trailing: const Icon(LucideIcons.chevronDown, size: 18, color: AppColors.mutedForeground),
                    onTap: _showLanguagePicker,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Emergency Contact
              _SettingsSection(
                title: t?.t('settings.emergencyContact') ?? '',
                description: t?.t('settings.emergencyContactDesc') ?? '',
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t?.t('settings.name') ?? '', style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: TextEditingController.fromValue(TextEditingValue(text: _emergencyName)),
                          onChanged: (v) => _emergencyName = v,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: t?.t('settings.name') ?? '',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border.withAlpha(128))),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(t?.t('settings.relationship') ?? '', style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: TextEditingController.fromValue(TextEditingValue(text: _emergencyRelationship)),
                          onChanged: (v) => _emergencyRelationship = v,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: t?.t('settings.relationship') ?? '',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border.withAlpha(128))),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(t?.t('settings.phone') ?? '', style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: TextEditingController.fromValue(TextEditingValue(text: _emergencyPhone)),
                          onChanged: (v) => _emergencyPhone = v,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: t?.t('settings.phone') ?? '',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border.withAlpha(128))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Notifications
              _SettingsSection(
                title: t?.t('settings.notifications') ?? '',
                children: [
                  _SettingsTile(
                    icon: LucideIcons.bell,
                    title: t?.t('settings.pushNotifications') ?? '',
                    trailing: Switch(value: _pushEnabled, onChanged: (v) => setState(() => _pushEnabled = v)),
                  ),
                  _SettingsTile(
                    icon: LucideIcons.mail,
                    title: t?.t('settings.emailNotifications') ?? '',
                    trailing: Switch(value: _emailEnabled, onChanged: (v) => setState(() => _emailEnabled = v)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Security
              _SettingsSection(
                title: t?.t('settings.security') ?? '',
                children: [
                  _SettingsTile(
                    icon: LucideIcons.lock,
                    title: t?.t('settings.changePin') ?? '',
                    trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.mutedForeground),
                    onTap: _changePin,
                  ),
                  _SettingsTile(
                    icon: LucideIcons.shield,
                    title: t?.t('settings.twoFactorAuth') ?? '',
                    trailing: Switch(value: _twoFactorEnabled, onChanged: (v) => setState(() => _twoFactorEnabled = v)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Data
              _SettingsSection(
                title: t?.t('settings.data') ?? '',
                children: [
                  _SettingsTile(
                    icon: LucideIcons.download,
                    title: t?.t('settings.exportData') ?? '',
                    trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.mutedForeground),
                    onTap: _exportData,
                  ),
                  _SettingsTile(
                    icon: LucideIcons.trash2,
                    title: t?.t('settings.deleteAccount') ?? '',
                    trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.destructive),
                    titleColor: AppColors.destructive,
                    onTap: _requestDeleteAccount,
                  ),
                  _SettingsTile(
                    icon: LucideIcons.logOut,
                    title: t?.t('settings.signOut') ?? '',
                    trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.destructive),
                    titleColor: AppColors.destructive,
                    onTap: _signOut,
                  ),
                ],
              ),

              // Save Button
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: Icon(_saved ? LucideIcons.checkCircle2 : LucideIcons.save, size: 18),
                  label: Text(_saved ? (t?.t('settings.saved') ?? '') : (t?.t('settings.save') ?? '')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Center(
                child: Text(
                  '${t?.t('settings.version') ?? 'Version'} 1.0.0',
                  style: TextStyle(fontSize: 13, color: AppColors.mutedForeground.withAlpha(153)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),

          // Toast
          if (_showToast)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                color: AppColors.card,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withAlpha(25)),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.checkCircle2, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t?.t('settings.saved') ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                      GestureDetector(
                        onTap: () => setState(() => _showToast = false),
                        child: Icon(LucideIcons.x, size: 16, color: AppColors.mutedForeground.withAlpha(153)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget> children;
  const _SettingsSection({required this.title, this.description, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(description!, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground.withAlpha(153))),
                  ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget trailing;
  final Color? titleColor;
  final VoidCallback? onTap;
  const _SettingsTile({required this.icon, required this.title, required this.trailing, this.titleColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Icon(icon, size: 20, color: AppColors.mutedForeground),
        title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: titleColor ?? AppColors.foreground)),
        trailing: trailing,
        contentPadding: EdgeInsets.zero,
        onTap: trailing is Switch ? null : onTap,
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _LanguageOption({required this.label, required this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(selected ? LucideIcons.checkCircle2 : LucideIcons.circle, color: selected ? AppColors.primary : AppColors.mutedForeground),
      title: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
      onTap: onTap,
    );
  }
}
