import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_providers.dart';
import '../../patient/providers/patient_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/localization.dart';

/// Lets an authenticated user whose patient profile is still a stub (e.g. they
/// signed in instead of completing registration) finish onboarding by supplying
/// the missing identity fields. Posts to /patients/onboard and reloads.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _day = TextEditingController();
  final _month = TextEditingController();
  final _year = TextEditingController();
  String? _gender;
  String _city = 'Yaounde';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _day.dispose();
    _month.dispose();
    _year.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final day = int.tryParse(_day.text.trim()) ?? 0;
    final month = int.tryParse(_month.text.trim()) ?? 0;
    final year = int.tryParse(_year.text.trim()) ?? 0;
    if (day < 1 || day > 31 || month < 1 || month > 12 || year < 1900 || year > DateTime.now().year) {
      setState(() => _error = 'Date de naissance invalide');
      return;
    }
    setState(() => _saving = true);
    try {
      final dateOfBirth = DateTime(year, month, day).toIso8601String();
      await ref.read(apiClientProvider).post(ApiEndpoints.patientOnboard, data: {
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'dateOfBirth': dateOfBirth,
        'gender': _gender,
        'city': _city,
      });
      final pid = ref.read(patientProvider).patientId ?? '';
      final id = pid.isNotEmpty ? pid : (ref.read(authProvider).patient?.id ?? '');
      if (id.isNotEmpty) {
        await ref.read(patientProvider.notifier).loadPatientData(id);
      }
      ref.read(authProvider.notifier).markOnboarded();
      if (mounted) context.go('/patient/home');
    } catch (e) {
      if (mounted) setState(() => _error = 'Erreur lors de l\'enregistrement. Veuillez réessayer.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(localizationProvider(ref.watch(localeProvider))).asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(t?.t('onboarding.completeProfile') ?? 'Compléter votre profil'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t?.t('onboarding.completeProfileDesc') ??
                    'Quelques informations sont nécessaires pour finaliser votre dossier patient.',
                style: const TextStyle(color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _firstName,
                decoration: InputDecoration(
                  labelText: t?.t('registration.firstName') ?? 'Prénom',
                  prefixIcon: const Icon(LucideIcons.user, size: 16),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastName,
                decoration: InputDecoration(
                  labelText: t?.t('registration.lastName') ?? 'Nom',
                  prefixIcon: const Icon(LucideIcons.user, size: 16),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _day,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: t?.t('registration.day') ?? 'Jour',
                        prefixIcon: const Icon(LucideIcons.calendar, size: 16),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'JJ' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _month,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: t?.t('registration.month') ?? 'Mois',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'MM' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _year,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: t?.t('registration.year') ?? 'Année',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'AAAA' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: InputDecoration(
                  labelText: t?.t('registration.gender') ?? 'Genre',
                  prefixIcon: const Icon(LucideIcons.user, size: 16),
                ),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Homme')),
                  DropdownMenuItem(value: 'Female', child: Text('Femme')),
                ],
                onChanged: (v) => setState(() => _gender = v),
                validator: (v) => v == null ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _city,
                decoration: InputDecoration(
                  labelText: t?.t('registration.city') ?? 'Ville',
                  prefixIcon: const Icon(LucideIcons.mapPin, size: 16),
                ),
                items: const [
                  DropdownMenuItem(value: 'Yaounde', child: Text('Yaoundé')),
                  DropdownMenuItem(value: 'Douala', child: Text('Douala')),
                ],
                onChanged: (v) => setState(() => _city = v ?? 'Yaounde'),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: const TextStyle(color: AppColors.destructive)),
                ),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(t?.t('onboarding.saveProfile') ?? 'Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
