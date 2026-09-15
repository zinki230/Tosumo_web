import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../patient/providers/patient_provider.dart';
import '../../../core/utils/localization.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import 'widgets/premium_medical_card.dart';
import '../../../shared/widgets/app_back_button.dart';

class CardViewScreen extends ConsumerWidget {
  const CardViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;
    final state = ref.watch(patientProvider);
    final patient = state.patient;
    final card = state.card;

    if (patient == null) {
      return Scaffold(
        body: Center(
          child: Text(
            t?.t('common.loading') ?? '',
            style: const TextStyle(color: AppColors.mutedForeground),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: AppBackButton(color: AppColors.foreground),
              ),
              Text(
                t?.t('card.title') ?? '',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PremiumMedicalCard(
                  name: patient.name,
                  nationalId: patient.nationalId,
                  dateOfBirth: patient.dateOfBirth,
                  bloodType: patient.bloodType,
                  status: patient.status,
                  verified: patient.verified,
                  cardToken: card?.token ?? t?.t('card.pendingToken') ?? 'PENDING',
                  allergies: patient.allergies,
                  chronicConditions: patient.chronicConditions,
                  emergencyContact: patient.emergencyContact,
                  gender: patient.gender,
                  t: t,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _outlineButton(
                      icon: LucideIcons.download,
                      label: t?.t('card.download') ?? '',
                      onTap: () async {
                        final info = [
                          'TOSUMO — ${t?.t('card.title') ?? ''}',
                          'Nom : ${patient.name}',
                          'Carte : ${card?.token ?? t?.t('card.pendingToken') ?? 'PENDING'}',
                          'Groupe sanguin : ${patient.bloodType}',
                        ].join('\n');
                        await Clipboard.setData(ClipboardData(text: info));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(t?.t('card.downloadStarted') ?? ''),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(milliseconds: 2500),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _outlineButton(
                      icon: LucideIcons.printer,
                      label: t?.t('card.print') ?? '',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(t?.t('card.printNotAvailable') ?? ''),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(milliseconds: 2500),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (card != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${t?.t('card.issued') ?? ''} ${card.issuedAt}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _outlineButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.foreground,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
