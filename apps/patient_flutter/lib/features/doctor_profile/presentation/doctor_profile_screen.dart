import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/utils/localization.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/doctor_profile.dart';
import '../../../shared/widgets/app_animated_mount.dart';
import '../../../shared/widgets/app_back_button.dart';

class DoctorProfileScreen extends ConsumerWidget {
  final DoctorProfile doctor;
  const DoctorProfileScreen({super.key, required this.doctor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        title: Text(doctor.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              color: AppColors.white,
              child: Column(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(color: AppColors.primary.withAlpha(25), shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        doctor.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase(),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(doctor.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(doctor.specialty, style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.star, size: 16, color: AppColors.gold),
                      const SizedBox(width: 4),
                      Text(doctor.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      Text(t?.t('doctorSearch.reviewCount', params: {'count': doctor.reviewCount.toString()}) ?? '', style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
                      const SizedBox(width: 16),
                      Icon(LucideIcons.users, size: 16, color: AppColors.mutedForeground),
                      const SizedBox(width: 4),
                      Text(t?.t('doctorSearch.patientCount', params: {'count': doctor.patientCount.toString()}) ?? '', style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Section(
              title: t?.t('doctorProfile.about') ?? '',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doctor.bio, style: const TextStyle(fontSize: 14, color: AppColors.foreground)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(LucideIcons.briefcase, size: 16, color: AppColors.mutedForeground),
                      const SizedBox(width: 6),
                      Text(t?.t('doctorSearch.expYears', params: {'count': doctor.yearsExperience.toString()}) ?? '', style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(LucideIcons.hospital, size: 16, color: AppColors.mutedForeground),
                      const SizedBox(width: 6),
                      Expanded(child: Text(doctor.hospital, style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin, size: 16, color: AppColors.mutedForeground),
                      const SizedBox(width: 6),
                      Expanded(child: Text(doctor.hospitalLocation, style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground))),
                    ],
                  ),
                ],
              ),
            ),
            if (doctor.expertise.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Section(
                title: t?.t('doctorProfile.expertise') ?? '',
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: doctor.expertise.map((e) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(20)),
                    child: Text(e, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                  )).toList(),
                ),
              ),
            ],
            if (doctor.languages.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Section(
                title: t?.t('doctorProfile.languages') ?? '',
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: doctor.languages.map((l) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(20)),
                    child: Text(l, style: const TextStyle(fontSize: 12)),
                  )).toList(),
                ),
              ),
            ],
            if (doctor.reviews.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Section(
                title: t?.t('doctorProfile.reviews') ?? '',
                child: Column(
                  children: doctor.reviews.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: AppColors.muted, shape: BoxShape.circle),
                          child: Center(child: Text(r.name[0], style: const TextStyle(fontWeight: FontWeight.w600))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(r.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  const Spacer(),
                                  Row(children: List.generate(5, (i) => Icon(i < r.rating.toInt() ? LucideIcons.star : LucideIcons.star, size: 12, color: i < r.rating.toInt() ? AppColors.gold : AppColors.border))),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(r.text, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () => context.push('/patient/booking', extra: doctor),
              icon: const Icon(LucideIcons.calendarPlus, size: 18),
              label: Text(t?.t('doctorProfile.bookAppointment') ?? ''),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedMount(
      animation: 'fadeInUp',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
