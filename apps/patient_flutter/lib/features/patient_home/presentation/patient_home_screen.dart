import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../patient/providers/patient_provider.dart';
import '../../../../core/utils/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_animated_mount.dart';
import '../../../../shared/widgets/safe_top_spacer.dart';
import '../../../../shared/models/booklet_entry.dart';
import '../../card/presentation/widgets/premium_medical_card.dart';

class PatientHomeScreen extends ConsumerWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;
    final state = ref.watch(patientProvider);
    final patient = state.patient;

    if (state.loading && patient == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                t?.t('auth.loading') ?? 'Chargement...',
                style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground),
              ),
            ],
          ),
        ),
      );
    }

    if (patient == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.wifiOff, size: 40, color: AppColors.mutedForeground),
                const SizedBox(height: 16),
                Text(
                  state.error ?? (t?.t('common.profileError') ?? 'Unable to load your data'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.read(patientProvider.notifier).refreshPatientData(),
                  icon: const Icon(LucideIcons.refreshCw),
                  label: Text(t?.t('common.retry') ?? 'Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final rawName = patient.name.trim();
    final firstName = rawName.isNotEmpty ? rawName.split(' ').first : '';
    final bloodType = patient.bloodType;
    final allergies = patient.allergies;
    final chronicConditions = patient.chronicConditions;

    final healthScore = _calculateHealthScore(
      chronicConditions.length,
      allergies.length,
      verified: patient.verified,
      hasVitals: bloodType.isNotEmpty,
    );
    final hasAllergies = allergies.isNotEmpty;
    final hasConditions = chronicConditions.isNotEmpty;
    final effectivePrescriptions = state.prescriptions.isNotEmpty
        ? state.prescriptions
        : state.bookletEntries.expand((e) => e.prescriptions).toList();
    BookletEntry? lastConsultation;
    if (state.bookletEntries.isNotEmpty) {
      final sorted = [...state.bookletEntries]
        ..sort((a, b) =>
            (DateTime.tryParse(b.visitDate)?.millisecondsSinceEpoch ?? 0).compareTo(
                DateTime.tryParse(a.visitDate)?.millisecondsSinceEpoch ?? 0));
      lastConsultation = sorted.first;
    }
    final hasConsultation = lastConsultation != null;
    final hasTreatment = effectivePrescriptions.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () async => ref.read(patientProvider.notifier).refreshPatientData(),
      color: AppColors.primary,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 80),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SafeTopSpacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AnimatedMount(
                    animation: 'fadeInUp',
                    delay: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstName.isNotEmpty ? 'Bonjour, $firstName 👋' : 'Bonjour 👋',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t?.t('home.greetingSubtitle') ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                IconButton(
                  onPressed: () => context.push('/patient/notifications'),
                  icon: const Icon(LucideIcons.bell, size: 22),
                  color: AppColors.mutedForeground,
                  tooltip: t?.t('common.notifications') ?? '',
                ),
                const SizedBox(width: AppSpacing.xs),
                Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: healthScore >= 80
                            ? const Color(0xFFECFDF5)
                            : healthScore >= 60
                                ? const Color(0xFFFFFBEB)
                                : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(
                          color: healthScore >= 80
                              ? const Color(0xFFA7F3D0)
                              : healthScore >= 60
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0xFFFECACA),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$healthScore',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: healthScore >= 80
                                ? const Color(0xFF059669)
                                : healthScore >= 60
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t?.t('home.healthScore') ?? '',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mutedForeground,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (!patient.verified)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
              child: _VerificationBanner(t: t),
            ),
          if (!patient.verified) const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
            child: PremiumMedicalCard(
              name: patient.name,
              nationalId: patient.nationalId,
              dateOfBirth: patient.dateOfBirth,
              bloodType: bloodType,
              status: patient.status,
              verified: patient.verified,
              cardToken: state.card?.token ?? (t?.t('card.pendingToken') ?? 'PENDING'),
              allergies: allergies,
              chronicConditions: chronicConditions,
              emergencyContact: patient.emergencyContact,
              gender: patient.gender,
              t: t,
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
            child: _HealthStatusGrid(
              lastConsultation: lastConsultation,
              prescriptionsCount: effectivePrescriptions.length,
              hasAllergies: hasAllergies,
              hasConsultation: hasConsultation,
              hasTreatment: hasTreatment,
              t: t,
            ),
          ),
          const SizedBox(height: 24),
          if (hasAllergies || hasConditions)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
              child: _HealthInfoCard(
                allergies: allergies,
                chronicConditions: chronicConditions,
                bloodType: bloodType,
                t: t,
              ),
            ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
            child: _AppointmentsPreview(t: t),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
            child: _QuickActionsGrid(t: t),
          ),
        ],
      ),
    ),
    );
  }

  int _calculateHealthScore(int chronicCount, int allergyCount, {required bool verified, required bool hasVitals}) {
    var score = 85;
    if (!verified) score -= 25;
    if (!hasVitals) score -= 10;
    if (chronicCount > 0) score -= chronicCount * 5;
    if (allergyCount > 2) score -= 5;
    return score.clamp(20, 100);
  }
}

class _VerificationBanner extends StatelessWidget {
  final AppLocalization? t;

  const _VerificationBanner({required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withAlpha(25),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(LucideIcons.hospital, size: 20, color: Color(0xFFD97706)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t?.t('home.verificationBannerTitle') ?? 'Complétez votre carte',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t?.t('home.verificationBannerBody') ??
                      'Vos informations vitales (groupe sanguin, allergies…) ne sont pas encore enregistrées. Rendez-vous à l\'hôpital le plus proche pour que le médecin les saisisse et vérifie votre carte.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthStatusGrid extends StatelessWidget {
  final BookletEntry? lastConsultation;
  final int prescriptionsCount;
  final bool hasAllergies;
  final bool hasConsultation;
  final bool hasTreatment;
  final AppLocalization? t;

  const _HealthStatusGrid({
    required this.lastConsultation,
    required this.prescriptionsCount,
    required this.hasAllergies,
    required this.hasConsultation,
    required this.hasTreatment,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final consultationValue = lastConsultation == null
        ? (t?.t('home.noConsultation') ?? '')
        : (lastConsultation!.summary.isNotEmpty
            ? lastConsultation!.summary
            : (lastConsultation!.facility.isNotEmpty
                ? lastConsultation!.facility
                : (t?.t('home.noConsultation') ?? '')));
    final consultationSub = lastConsultation?.visitDate ?? '';

    return AnimatedMount(
      animation: 'fadeInUp',
      delay: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t?.t('home.healthStatus') ?? '',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statusTile(
                  icon: LucideIcons.clock,
                  label: t?.t('home.lastConsultation') ?? '',
                  value: consultationValue,
                  subText: consultationSub,
                  color: lastConsultation != null
                      ? const Color(0xFF2563EB)
                      : AppColors.mutedForeground,
                  onTap: lastConsultation == null
                      ? null
                      : () => context.push('/patient/booklet/${lastConsultation!.id}'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _statusTile(
                  icon: LucideIcons.pill,
                  label: t?.t('home.currentTreatment') ?? '',
                  value: hasTreatment
                      ? '$prescriptionsCount ${t?.t('home.treatments') ?? 'traitement(s)'}'
                      : (t?.t('home.noTreatment') ?? ''),
                  color: hasTreatment
                      ? const Color(0xFFF59E0B)
                      : AppColors.mutedForeground,
                  onTap: () => context.push('/patient/recipes'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? subText,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border.withAlpha(128)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                if (onTap != null)
                  const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.mutedForeground),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (subText != null && subText.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subText,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HealthInfoCard extends StatelessWidget {
  final List<String> allergies;
  final List<String> chronicConditions;
  final String bloodType;
  final AppLocalization? t;

  const _HealthInfoCard({
    required this.allergies,
    required this.chronicConditions,
    required this.bloodType,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedMount(
      animation: 'fadeInUp',
      delay: 300,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          onTap: () => context.push('/patient/profile'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.border.withAlpha(128)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.heart, size: 16, color: AppColors.destructive),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t?.t('home.medicalInfo') ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.mutedForeground),
                  ],
                ),
                const SizedBox(height: 12),
                if (allergies.isNotEmpty) ...[
                  _infoRow(t?.t('home.allergies') ?? '', allergies.join(', ')),
                  const SizedBox(height: 8),
                ],
                if (chronicConditions.isNotEmpty) ...[
                  _infoRow(t?.t('home.conditions') ?? '', chronicConditions.join(', ')),
                  const SizedBox(height: 8),
                ],
                _infoRow(t?.t('home.bloodType') ?? '', bloodType),
                const SizedBox(height: 10),
                Text(
                  t?.t('home.viewFullMedicalInfo') ?? 'Voir toutes les informations médicales',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _AppointmentsPreview extends ConsumerWidget {
  final AppLocalization? t;
  const _AppointmentsPreview({required this.t});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(patientProvider);
    final upcoming = state.appointments.where((a) => a.isUpcoming).toList()
      ..sort((a, b) => (DateTime.tryParse(a.date)?.millisecondsSinceEpoch ?? 0)
          .compareTo(DateTime.tryParse(b.date)?.millisecondsSinceEpoch ?? 0));
    final next = upcoming.isEmpty ? null : upcoming.first;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(13),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.primary.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.calendarCheck, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                t?.t('home.appointments') ?? '',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push('/patient/appointments'),
                child: Text(
                  t?.t('common.viewAll') ?? '',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (next == null) ...[
            Text(
              t?.t('home.noAppointments') ?? '',
              style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push('/patient/doctor-search'),
                icon: const Icon(LucideIcons.calendarPlus),
                label: Text(t?.t('home.bookAppointment') ?? ''),
              ),
            ),
          ]
          else
            InkWell(
              onTap: () => context.push('/appointment/${next.id}'),
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        next.startTime.isNotEmpty ? next.startTime : '--',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          next.doctorName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          next.specialty,
                          style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                  const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.mutedForeground),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final AppLocalization? t;

  const _QuickActionsGrid({required this.t});

  @override
  Widget build(BuildContext context) {
    return AnimatedMount(
      animation: 'fadeInUp',
      delay: 350,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _actionCard(
                  icon: LucideIcons.creditCard,
                  label: t?.t('home.quickActionCard') ?? '',
                  color: AppColors.primary,
                  onTap: () => context.push('/patient/card'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _actionCard(
                  icon: LucideIcons.fileText,
                  label: t?.t('home.quickActionBooklet') ?? '',
                  color: AppColors.accent,
                  onTap: () => context.push('/patient/booklet'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _actionCard(
                  icon: LucideIcons.shield,
                  label: t?.t('home.quickActionAccess') ?? '',
                  color: AppColors.warning,
                  onTap: () => context.push('/patient/access'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _actionCard(
                  icon: LucideIcons.phone,
                  label: t?.t('home.quickActionEmergency') ?? '',
                  color: AppColors.destructive,
                  onTap: () => context.push('/patient/emergency'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: color.withAlpha(13),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: color.withAlpha(51)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
