import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/providers/patient_provider.dart';
import '../../../core/utils/localization.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_animated_mount.dart';
import '../../../shared/widgets/app_back_button.dart';

class PrescriptionsScreen extends ConsumerWidget {
  const PrescriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;
    final state = ref.watch(patientProvider);
    final prescriptions = state.prescriptions.isNotEmpty
        ? state.prescriptions
        : state.bookletEntries
            .expand((e) => e.prescriptions)
            .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(t?.t('recipes.title') ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: prescriptions.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.pill, size: 64, color: AppColors.mutedForeground.withAlpha(77)),
                    const SizedBox(height: 16),
                    Text(t?.t('recipes.noPrescriptions') ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(t?.t('recipes.noPrescriptionsDesc') ?? '', style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.push('/patient/doctor-search'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        elevation: 0,
                      ),
                      child: Text(t?.t('booklet.bookAppointment') ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: prescriptions.length,
              itemBuilder: (context, index) {
                final presc = prescriptions[index];
                return AnimatedMount(
                  delay: index * 40,
                  animation: 'fadeInUp',
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(LucideIcons.pill, size: 24, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(presc.drugName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('${presc.dosage} - ${presc.instructions}', style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(LucideIcons.clock, size: 14, color: AppColors.mutedForeground),
                                  const SizedBox(width: 4),
                                  Text('${presc.frequency} - ${presc.duration}', style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                                ],
                              ),
                            ],
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
