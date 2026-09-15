import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/network/auth_providers.dart';
import '../../../core/utils/localization.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_animated_mount.dart';
import '../../../shared/widgets/brand_logo.dart';

/// Step 1 of registration: collect only the phone number, verify it is not
/// already registered, then hand off to OTP. Personal information is collected
/// on the next screen (after OTP) so the user is not asked twice.
class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final _phoneController = TextEditingController();
  bool _checking = false;
  bool _phoneExists = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    if (_checking) return;
    final t = ref.read(localizationProvider(ref.read(localeProvider))).asData?.value;
    if (!isValidCameroonPhone(_phoneController.text)) {
      setState(() => _error = t?.t('registration.invalidPhone') ?? '');
      return;
    }
    final phone = normalizeCameroonPhone(_phoneController.text);
    setState(() {
      _checking = true;
      _error = null;
      _phoneExists = false;
    });
    bool exists;
    try {
      exists = await ref
          .read(authServiceProvider)
          .phoneAlreadyRegistered(phone: phone)
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = t?.t('registration.phoneCheckFailed') ?? '';
      });
      return;
    }
    if (!mounted) return;
    if (exists) {
      setState(() {
        _checking = false;
        _phoneExists = true;
      });
      return;
    }
    setState(() => _checking = false);
    context.push('/otp', extra: {
      'role': 'patient',
      'registrationData': {'phone': phone},
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final t = ref.watch(localizationProvider(locale)).asData?.value;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: 32),
              const BrandLogo(size: BrandLogoSize.sm),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 6,
                    width: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    height: 6,
                    width: 56,
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    height: 6,
                    width: 56,
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  t?.t('registration.step', params: {'current': '1', 'total': '3'}) ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AnimatedMount(
                animation: 'fadeInUp',
                delay: 0,
                child: Text(
                  t?.t('registration.phoneTitle') ?? 'Votre numéro de téléphone',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              AnimatedMount(
                animation: 'fadeInUp',
                delay: 50,
                child: Text(
                  t?.t('registration.phoneSubtitle') ??
                      'Nous utiliserons ce numéro pour vérifier votre identité.',
                  style: const TextStyle(color: AppColors.mutedForeground),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              AnimatedMount(
                animation: 'fadeInUp',
                delay: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t?.t('registration.phone') ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(9),
                      ],
                      decoration: InputDecoration(
                        prefixIcon: const Icon(LucideIcons.phone, size: 16, color: AppColors.foreground),
                        prefixText: '+237 ',
                        prefixStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                        hintText: t?.t('registration.phonePlaceholder') ?? '',
                        filled: true,
                        fillColor: AppColors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Text(
                          _error!,
                          style: const TextStyle(fontSize: 12, color: AppColors.destructive),
                        ),
                      ),
                    if (_phoneExists) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.destructive.withAlpha(13),
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(color: AppColors.destructive.withAlpha(51)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              t?.t('registration.phoneAlreadyRegistered') ??
                                  'Ce numéro est déjà utilisé.',
                              style: const TextStyle(color: AppColors.destructive),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => context.go('/signin'),
                              child: Text(t?.t('auth.login') ?? 'Se connecter'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _checking ? null : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryForeground,
                    disabledBackgroundColor: AppColors.primary.withAlpha(128),
                    disabledForegroundColor: AppColors.primaryForeground.withAlpha(128),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    minimumSize: const Size(double.infinity, 56),
                    elevation: 0,
                  ),
                  child: _checking
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryForeground,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(t?.t('registration.checkingPhone') ?? ''),
                          ],
                        )
                      : Text(t?.t('registration.continue') ?? ''),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
