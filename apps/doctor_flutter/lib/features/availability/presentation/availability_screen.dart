import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/working_hour.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/error_mapper.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_button.dart';

class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  String get _doctorId => ref.read(currentDoctorIdProvider) ?? '';
  late List<WorkingHour> _workingHours;
  bool _isAvailable = true;
  bool _isSaving = false;
  bool _isInitialized = false;

  final List<String> _dayNames = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];

  @override
  void initState() {
    super.initState();
    _workingHours = List.generate(7, (i) => WorkingHour(
      dayOfWeek: i + 1,
      startTime: '09:00',
      endTime: '17:00',
      isAvailable: i < 5,
    ));
    _loadHours();
  }

  Future<void> _loadHours() async {
    try {
      final doctor = await ref.read(doctorRepositoryProvider).getProfile(_doctorId);
      if (doctor.workingHours.isNotEmpty) {
        setState(() {
          _workingHours = doctor.workingHours;
          _isAvailable = doctor.isAvailable;
          _isInitialized = true;
        });
      } else {
        setState(() => _isInitialized = true);
      }
    } catch (_) {
      setState(() => _isInitialized = true);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(settingsRepositoryProvider).updateWorkingHours(_workingHours);
      await ref.read(settingsRepositoryProvider).updateAvailability(_isAvailable);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Disponibilités enregistrées'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMapper.fromException(e).message),
            backgroundColor: AppColors.destructive,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _applyToWeekdays() {
    setState(() {
      for (int i = 0; i < 5; i++) {
        _workingHours[i] = WorkingHour(
          dayOfWeek: _workingHours[i].dayOfWeek,
          startTime: _workingHours[0].startTime,
          endTime: _workingHours[0].endTime,
          isAvailable: _workingHours[0].isAvailable,
        );
      }
    });
  }

  Future<void> _pickTime(int index, bool isStart) async {
    final current = _workingHours[index];
    final initial = isStart ? current.startTime : current.endTime;
    final parts = initial.split(':');
    final initialTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0);

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isStart) {
          _workingHours[index] = WorkingHour(
            dayOfWeek: _workingHours[index].dayOfWeek,
            startTime: timeStr,
            endTime: _workingHours[index].endTime,
            isAvailable: _workingHours[index].isAvailable,
          );
        } else {
          _workingHours[index] = WorkingHour(
            dayOfWeek: _workingHours[index].dayOfWeek,
            startTime: _workingHours[index].startTime,
            endTime: timeStr,
            isAvailable: _workingHours[index].isAvailable,
          );
        }
      });
    }
  }

  void _showQuickUnavailable() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Se rendre indisponible',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Text('Pour combien de temps ?', style: TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
            const SizedBox(height: 12),
            ...['30 minutes', '1 heure', '2 heures', '4 heures', 'Reste de la journée'].map((label) =>
              ListTile(
                title: Text(label, style: const TextStyle(fontSize: 14)),
                trailing: const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.mutedForeground),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _isAvailable = false);
                  ref.read(settingsRepositoryProvider).updateAvailability(false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Indisponible pour $label'),
                      backgroundColor: AppColors.accent,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(
              title: 'Disponibilités',
              subtitle: 'Gérez vos horaires de travail',
              showBack: false,
              showNotification: true,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
              child: AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: _isAvailable ? AppColors.success.withValues(alpha: 0.15) : AppColors.muted,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        _isAvailable ? LucideIcons.checkCircle : LucideIcons.xCircle,
                        color: _isAvailable ? AppColors.success : AppColors.mutedForeground,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isAvailable ? 'Disponible' : 'Indisponible',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.foreground),
                          ),
                          Text(
                            _isAvailable ? 'Vous êtes actuellement disponible' : 'Vous êtes actuellement indisponible',
                            style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isAvailable,
                      onChanged: (v) {
                        setState(() => _isAvailable = v);
                        ref.read(settingsRepositoryProvider).updateAvailability(v);
                      },
                      activeThumbColor: AppColors.success,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showQuickUnavailable,
                  icon: const Icon(LucideIcons.clock, size: 16),
                  label: const Text('Se rendre indisponible pour une durée'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
              child: Row(
                children: [
                  const SectionTitle(title: 'Horaires hebdomadaires'),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _applyToWeekdays,
                    icon: const Icon(LucideIcons.copy, size: 14),
                    label: const Text('Appliquer aux jours ouvrés', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(7, (i) {
              final day = _workingHours[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal, vertical: 4),
                child: AppCard(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          _dayNames[i],
                          style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.foreground,
                          ),
                        ),
                      ),
                      Switch(
                        value: day.isAvailable,
                        onChanged: (v) {
                          setState(() {
                            _workingHours[i] = WorkingHour(
                              dayOfWeek: day.dayOfWeek,
                              startTime: day.startTime,
                              endTime: day.endTime,
                              isAvailable: v,
                            );
                          });
                        },
                        activeThumbColor: AppColors.primary,
                      ),
                      if (day.isAvailable) ...[
                        Expanded(
                          child: Row(
                            children: [
                              _TimeButton(
                                time: day.startTime,
                                onTap: () => _pickTime(i, true),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Text('-', style: TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
                              ),
                              _TimeButton(
                                time: day.endTime,
                                onTap: () => _pickTime(i, false),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Enregistrer',
                      loading: _isSaving,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.foreground),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String time;
  final VoidCallback onTap;

  const _TimeButton({required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          time,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.foreground),
        ),
      ),
    );
  }
}
