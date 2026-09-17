import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/error_mapper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/doctor.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/avatar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'complete_profile_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Doctor? _doctor;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  String? get _doctorId => ref.read(currentDoctorIdProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doctorId = _doctorId ?? '';
    setState(() { _loading = true; _error = null; });
    try {
      final doctor = await ref.read(doctorRepositoryProvider).getProfile(doctorId);
      if (mounted) setState(() { _doctor = doctor; _loading = false; });
    } catch (e) {
      final failure = ErrorMapper.fromException(e);
      if (mounted) setState(() { _error = failure.message; _loading = false; });
    }
  }

  Future<void> _completeProfile() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const CompleteProfileScreen(),
      ),
    );
    if (result == true && mounted) {
      _load();
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    setState(() => _saving = true);
    try {
      await ref.read(settingsRepositoryProvider).updateAvailability(value);
      if (mounted) setState(() { _doctor = _doctor?.copyWith(isAvailable: value); _saving = false; });
    } catch (e) {
      final failure = ErrorMapper.fromException(e);
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      }
    }
  }

  Future<void> _editProfile() async {
    final doctor = _doctor;
    if (doctor == null) return;
    final nameController = TextEditingController(text: doctor.name);
    final specialtyController = TextEditingController(text: doctor.specialty);
    final bioController = TextEditingController(text: doctor.credentials.join(', '));
    final languagesController = TextEditingController(text: doctor.languages.join(', '));

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Modifier le profil',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom complet',
                  prefixIcon: Icon(LucideIcons.user, size: 20),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: specialtyController,
                decoration: const InputDecoration(
                  labelText: 'Spécialité',
                  prefixIcon: Icon(LucideIcons.stethoscope, size: 20),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bioController,
                decoration: const InputDecoration(
                  labelText: 'Diplômes (séparés par virgule)',
                  prefixIcon: Icon(LucideIcons.graduationCap, size: 20),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: languagesController,
                decoration: const InputDecoration(
                  labelText: 'Langues (séparées par virgule)',
                  prefixIcon: Icon(LucideIcons.languages, size: 20),
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Enregistrer',
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );

    if (saved == true && mounted) {
      setState(() => _saving = true);
      try {
        final updated = _doctor!.copyWith(
          name: nameController.text.trim(),
          specialty: specialtyController.text.trim(),
          credentials: bioController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          languages: languagesController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
        );
        final result = await ref.read(doctorRepositoryProvider).updateProfile(updated);
        ref.read(authProvider.notifier).refreshDoctor(result);
        if (mounted) {
          setState(() { _doctor = result; _saving = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil mis à jour')),
          );
        }
      } catch (e) {
        final failure = ErrorMapper.fromException(e);
        if (mounted) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.foreground,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.pageHorizontal),
        child: Column(
          children: [
            Skeleton(height: 120, borderRadius: AppRadius.xl),
            SizedBox(height: 16),
            Skeleton(height: 220, borderRadius: AppRadius.xl),
          ],
        ),
      );
    }

    if (_error != null || _doctor == null) {
      return EmptyState(
        icon: LucideIcons.userCircle,
        message: _error ?? 'Profil médecin non trouvé',
        subtitle: 'Complétez votre profil pour commencer à utiliser l\'application',
        actionLabel: 'Compléter mon profil',
        onAction: _completeProfile,
      );
    }

    final doctor = _doctor!;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: Column(
                children: [
                  Avatar(
                    initials: _initials(doctor.name),
                    photoUrl: doctor.photoUrl.isEmpty ? null : doctor.photoUrl,
                    size: 72,
                    online: doctor.isAvailable,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    doctor.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doctor.specialty,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doctor.hospitalName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedForeground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Modifier le profil',
                    variant: ButtonVariant.secondary,
                    loading: _saving,
                    onPressed: _editProfile,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                children: [
                  _InfoRow(icon: LucideIcons.mail, label: 'Email', value: doctor.email),
                  _InfoRow(icon: LucideIcons.phone, label: 'Téléphone', value: doctor.phone),
                  _InfoRow(icon: LucideIcons.badgeCheck, label: 'Licence', value: doctor.licenseNumber),
                  _InfoRow(
                    icon: LucideIcons.star,
                    label: 'Note',
                    value: '${doctor.rating.toStringAsFixed(1)} (${doctor.reviewCount} avis)',
                  ),
                  if (doctor.languages.isNotEmpty)
                    _InfoRow(
                      icon: LucideIcons.languages,
                      label: 'Langues',
                      value: doctor.languages.join(', '),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: SwitchListTile(
                value: doctor.isAvailable,
                onChanged: _saving ? null : _toggleAvailability,
                activeTrackColor: AppColors.primary,
                title: const Text(
                  'Disponible pour les patients',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                subtitle: Text(
                  doctor.isAvailable
                      ? 'Vous êtes visible et recevez des demandes'
                      : 'Vous êtes masqué pour les patients',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.mutedForeground),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
