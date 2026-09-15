import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/providers/patient_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/localization.dart';
import '../../../shared/widgets/app_animated_mount.dart';
import '../../../shared/widgets/app_back_button.dart';

class EmergencyModeScreen extends ConsumerStatefulWidget {
  const EmergencyModeScreen({super.key});

  @override
  ConsumerState<EmergencyModeScreen> createState() => _EmergencyModeScreenState();
}

class _EmergencyModeScreenState extends ConsumerState<EmergencyModeScreen> {
  String _callState = 'idle';
  int _contactsNotified = 0;
  int _nearbyHospitals = 0;

  void _startCall() {
    setState(() => _callState = 'confirming');
  }

  void _confirmCall() async {
    setState(() {
      _callState = 'calling';
      _contactsNotified = 0;
      _nearbyHospitals = 0;
    });
    final result = await ref.read(patientProvider.notifier).triggerSos();
    if (!mounted) return;
    if (result == null) {
      setState(() => _callState = 'idle');
      final locale = ref.read(localeProvider);
      final locAsync = ref.read(localizationProvider(locale));
      final t = locAsync.asData?.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t?.t('emergency.sendFailed') ?? 'Échec de l\'envoi de l\'alerte. Vérifiez votre connexion.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _callState = 'connected';
      _contactsNotified = (result['contactsNotified'] as num?)?.toInt() ?? _contactsNotified;
      _nearbyHospitals = (result['nearbyHospitals'] as num?)?.toInt() ?? _nearbyHospitals;
    });
  }

  void _cancelCall() {
    setState(() => _callState = 'idle');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(patientProvider);
    final patient = state.patient;
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;

    return Scaffold(
      backgroundColor: AppColors.destructive,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  const AppBackButton(color: Colors.white),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text((t?.t('emergency.protocolActive') ?? 'ACTIF').toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96, height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.white.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: _callState == 'calling'
                          ? const CircularProgressIndicator(color: AppColors.white, strokeWidth: 3)
                          : _callState == 'connected'
                            ? const Icon(LucideIcons.checkCircle, size: 48, color: AppColors.white)
                            : const Icon(LucideIcons.ambulance, size: 48, color: AppColors.white),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        t?.t('emergency.title') ?? 'Urgence Médicale',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _callState == 'connected'
                          ? ((t?.t('emergency.connected') ?? 'Connecté aux services d\'urgence. L\'aide est en route.')
                              .replaceAll('{contacts}', '$_contactsNotified')
                              .replaceAll('{hospitals}', '$_nearbyHospitals'))
                          : _callState == 'calling'
                            ? (t?.t('emergency.calling') ?? 'Appel des services d\'urgence...')
                            : (t?.t('emergency.description') ?? 'Disponible 24h/24 — Assistance immédiate.'),
                        style: TextStyle(fontSize: 15, color: AppColors.white.withAlpha(204)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (_callState == 'confirming')
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: _confirmCall,
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.white, foregroundColor: AppColors.destructive, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                              child: Text(t?.t('emergency.callNow') ?? 'Appeler maintenant'),
                            ),
                            const SizedBox(width: 16),
                            OutlinedButton(
                              onPressed: _cancelCall,
                              style: OutlinedButton.styleFrom(foregroundColor: AppColors.white, side: const BorderSide(color: AppColors.white), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                              child: Text(t?.t('common.cancel') ?? 'Annuler'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedMount(
              animation: 'fadeInUp',
              delay: 140,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _infoRow(LucideIcons.user, t?.t('emergency.patientLabel') ?? 'Patient', patient?.name ?? ''),
                    const SizedBox(height: 8),
                    if (patient != null) ...[
                      _infoRow(LucideIcons.droplets, t?.t('emergency.bloodType') ?? 'Groupe sanguin', patient.bloodType),
                      if (patient.allergies.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _infoRow(LucideIcons.alertTriangle, t?.t('emergency.allergies') ?? 'Allergies', patient.allergies.join(', ')),
                        ),
                      if (patient.chronicConditions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _infoRow(LucideIcons.activity, t?.t('emergency.conditions') ?? 'Pathologies', patient.chronicConditions.join(', ')),
                        ),
                      if (patient.currentMeds.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _infoRow(LucideIcons.pill, t?.t('emergency.medications') ?? 'Traitements', patient.currentMeds.join(', ')),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _infoRow(LucideIcons.phoneCall, t?.t('emergency.emergencyContact') ?? 'Contact urgence', '${patient.emergencyContactName} (${patient.emergencyContactRelationship}) — ${patient.emergencyContactPhone}'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _callState == 'idle' ? _startCall : null,
                  icon: const Icon(LucideIcons.phone, size: 20),
                  label: Text(t?.t('emergency.callEmergency') ?? 'Appeler les urgences', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.white,
                    side: const BorderSide(color: AppColors.white, width: 2),
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.white.withAlpha(204)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: AppColors.white),
              children: [
                TextSpan(text: '$label: ', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.white.withAlpha(179))),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
