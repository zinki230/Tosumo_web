import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/providers/patient_provider.dart';
import '../../../core/utils/localization.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static String _safeVal(String? value) {
    if (value == null || value.trim().isEmpty) return 'Non renseigné';
    return value.trim();
  }

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
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          title: Text(t?.t('profile.title') ?? 'Profil', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                t?.t('auth.loading') ?? 'Chargement du profil...',
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
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          title: Text(t?.t('profile.title') ?? 'Profil', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.alertCircle, size: 48, color: AppColors.destructive),
                const SizedBox(height: 16),
                Text(
                  state.error ?? 'Impossible de charger votre profil.',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Veuillez vérifier votre connexion internet et réessayez.',
                  style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => ref.read(patientProvider.notifier).refreshPatientData(),
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Format date of birth - now DateTime instead of String
    final formattedDob = AppFormatters.formatDate(patient.dateOfBirth);

    final consultations = state.bookletEntries
        .where((e) => e.consultationType == 'consultation' || e.summary.isNotEmpty)
        .toList()
      ..sort((a, b) => (DateTime.tryParse(b.visitDate)?.millisecondsSinceEpoch ?? 0)
          .compareTo(DateTime.tryParse(a.visitDate)?.millisecondsSinceEpoch ?? 0));
    final lastConsultation = consultations.isEmpty ? null : consultations.first;
    final prescriptionsCount = state.prescriptions.isNotEmpty
        ? state.prescriptions.length
        : state.bookletEntries.fold<int>(0, (sum, e) => sum + e.prescriptions.length);
    final treatmentList = state.prescriptions.isNotEmpty
        ? state.prescriptions.map((p) => p.drugName).toList()
        : state.bookletEntries
            .expand((e) => e.prescriptions)
            .map((p) => p.drugName)
            .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(t?.t('profile.title') ?? 'Profil', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(patientProvider.notifier).refreshPatientData(),
        color: AppColors.primary,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              color: AppColors.white,
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.cardBlueStart, AppColors.cardBlueEnd]),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        AppFormatters.getInitials(patient.name.isNotEmpty ? patient.name : 'Patient'),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(_safeVal(patient.name), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.mapPin, size: 14, color: AppColors.mutedForeground),
                      const SizedBox(width: 4),
                      Text(
                        patient.nationalId.isNotEmpty
                            ? (t?.t('profile.nid', params: {'id': patient.nationalId}) ?? 'NID: ${patient.nationalId}')
                            : 'NID: Non renseigné',
                        style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Section(
              title: t?.t('profile.personalInfo') ?? 'Informations personnelles',
              children: [
                _infoTile(LucideIcons.calendar, t?.t('registration.birthday') ?? 'Date de naissance', formattedDob),
                _infoTile(LucideIcons.user, t?.t('registration.gender') ?? 'Genre', _safeVal(patient.gender)),
                _infoTile(LucideIcons.phone, t?.t('profile.phone') ?? 'Téléphone', _safeVal(patient.phone)),
                _infoTile(LucideIcons.mail, t?.t('profile.email') ?? 'Email', _safeVal(patient.email)),
                _infoTile(LucideIcons.mapPin, t?.t('profile.city') ?? 'Ville', _safeVal(patient.city)),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              title: t?.t('profile.medicalInfo') ?? 'Informations médicales',
              children: [
                _infoTile(LucideIcons.droplets, t?.t('consultation.bloodType') ?? 'Groupe sanguin', _safeVal(patient.bloodType)),
                _infoTile(
                  LucideIcons.alertTriangle,
                  t?.t('emergency.allergies') ?? 'Allergies',
                  patient.allergies.isNotEmpty ? patient.allergies.join(', ') : 'Aucune allergie renseignée',
                ),
                _infoTile(
                  LucideIcons.activity,
                  t?.t('emergency.chronicConditions') ?? 'Conditions chroniques',
                  patient.chronicConditions.isNotEmpty ? patient.chronicConditions.join(', ') : 'Aucune condition renseignée',
                ),
                _infoTile(
                  LucideIcons.pill,
                  t?.t('emergency.currentMeds') ?? 'Traitements',
                  treatmentList.isNotEmpty ? treatmentList.join(', ') : 'Aucun traitement en cours',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              title: t?.t('profile.consultationSummary') ?? 'Résumé de santé',
              children: [
                _summaryTile(
                  LucideIcons.calendarCheck,
                  t?.t('profile.totalConsultations') ?? 'Consultations',
                  '${consultations.length}',
                ),
                const SizedBox(height: 8),
                if (lastConsultation != null) ...[
                  _infoTile(
                    LucideIcons.stethoscope,
                    t?.t('profile.lastConsultation') ?? 'Dernière consultation',
                    lastConsultation.doctorName?.isNotEmpty ?? false
                        ? lastConsultation.doctorName!
                        : (lastConsultation.facility.isNotEmpty ? lastConsultation.facility : lastConsultation.summary),
                  ),
                  const SizedBox(height: 8),
                  if (lastConsultation.visitDate.isNotEmpty)
                    _infoTile(
                      LucideIcons.calendar,
                      t?.t('profile.lastConsultationDate') ?? 'Date',
                      AppFormatters.formatDate(lastConsultation.visitDate),
                    ),
                  if (lastConsultation.diagnosis?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 8),
                    _infoTile(
                      LucideIcons.fileText,
                      t?.t('profile.lastDiagnosis') ?? 'Diagnostic',
                      lastConsultation.diagnosis!,
                    ),
                  ],
                ],
                _infoTile(
                  LucideIcons.pill,
                  t?.t('profile.activePrescriptions') ?? 'Prescriptions en cours',
                  '$prescriptionsCount',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              title: t?.t('settings.emergencyContact') ?? 'Contact d\'urgence',
              children: [
                _infoTile(LucideIcons.user, t?.t('settings.name') ?? 'Nom', _safeVal(patient.emergencyContactName)),
                _infoTile(LucideIcons.users, t?.t('settings.relationship') ?? 'Relation', _safeVal(patient.emergencyContactRelationship)),
                _infoTile(LucideIcons.phone, t?.t('settings.phone') ?? 'Téléphone', _safeVal(patient.emergencyContactPhone)),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push('/patient/settings'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(LucideIcons.settings, size: 18, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            t?.t('settings.title') ?? 'Paramètres',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.mutedForeground),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                const SizedBox(height: 2),
                Text(value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
