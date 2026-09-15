import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/registration_provider.dart';
import '../../../core/network/auth_providers.dart';
import '../../../core/utils/localization.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_animated_mount.dart';
import '../../../shared/widgets/brand_logo.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  final String? initialPhone;

  const RegistrationScreen({super.key, this.initialPhone});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _gender;
  final _dayController = TextEditingController();
  final _monthController = TextEditingController();
  final _yearController = TextEditingController();
  String _city = 'Yaounde';
  Map<String, String> _errors = {};
  bool _checkingPhone = false;
  bool _phoneExists = false;
  String? _phoneCheckFailed;

  bool get _profileMode => widget.initialPhone != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null) {
      _phoneController.text = widget.initialPhone!;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  bool _validate() {
    final t = ref.read(localizationProvider(ref.read(localeProvider))).asData?.value;
    final newErrors = <String, String>{};
    if (!isValidCameroonPhone(_phoneController.text)) {
      newErrors['phone'] = t?.t('registration.invalidPhone') ?? '';
    }
    if (_firstNameController.text.trim().isEmpty) {
      newErrors['firstName'] = t?.t('registration.required') ?? '';
    }
    if (_lastNameController.text.trim().isEmpty) {
      newErrors['lastName'] = t?.t('registration.required') ?? '';
    }
    if (_gender == null) {
      newErrors['gender'] = t?.t('registration.required') ?? '';
    }
    final d = int.tryParse(_dayController.text);
    final m = int.tryParse(_monthController.text);
    final y = int.tryParse(_yearController.text);
    if (_dayController.text.isEmpty || d == null || d < 1 || d > 31) {
      newErrors['day'] = t?.t('registration.invalid') ?? '';
    }
    if (_monthController.text.isEmpty || m == null || m < 1 || m > 12) {
      newErrors['month'] = t?.t('registration.invalid') ?? '';
    }
    if (_yearController.text.isEmpty || y == null || y < 1900 || y > DateTime.now().year) {
      newErrors['year'] = t?.t('registration.invalid') ?? '';
    }
    if (d != null && m != null && y != null && !newErrors.containsKey('day') && !newErrors.containsKey('month') && !newErrors.containsKey('year')) {
      try {
        DateTime(y, m, d);
      } catch (_) {
        newErrors['day'] = t?.t('registration.invalid') ?? '';
      }
    }
    if (_city.isEmpty) {
      newErrors['city'] = t?.t('registration.required') ?? '';
    }
    setState(() => _errors = newErrors);
    return newErrors.isEmpty;
  }

  Future<void> _handleContinue() async {
    if (_checkingPhone) return;
    final t = ref.read(localizationProvider(ref.read(localeProvider))).asData?.value;
    if (!_validate()) return;
    final phone = normalizeCameroonPhone(_phoneController.text);
    if (phone.isEmpty) {
      setState(() => _errors['phone'] = t?.t('registration.invalidPhone') ?? '');
      return;
    }

    // Profile mode: reached after OTP verification. The phone is already known
    // and verified, so skip the duplicate check and go straight to onboarding.
    if (_profileMode) {
      final dateOfBirth = DateTime(
        int.parse(_yearController.text),
        int.parse(_monthController.text),
        int.parse(_dayController.text),
      ).toIso8601String();
      ref.read(registrationProvider.notifier).setRegistrationData(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        gender: _gender ?? '',
        dateOfBirth: dateOfBirth,
        city: _city,
        role: 'patient',
        phone: phone,
      );
      context.push('/onboarding/identity-generation', extra: {
        'registrationData': {
          'firstName': _firstNameController.text,
          'lastName': _lastNameController.text,
          'gender': _gender,
          'day': _dayController.text,
          'month': _monthController.text,
          'year': _yearController.text,
          'city': _city,
          'phone': phone,
        },
      });
      return;
    }

    setState(() {
      _checkingPhone = true;
      _phoneExists = false;
      _phoneCheckFailed = null;
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
        _checkingPhone = false;
        _phoneCheckFailed = t?.t('registration.phoneCheckFailed') ?? '';
      });
      return;
    }
    if (!mounted) return;

    if (exists) {
      setState(() {
        _checkingPhone = false;
        _phoneExists = true;
      });
      return;
    }

    setState(() => _checkingPhone = false);

    final dateOfBirth = DateTime(
      int.parse(_yearController.text),
      int.parse(_monthController.text),
      int.parse(_dayController.text),
    ).toIso8601String();

    ref.read(registrationProvider.notifier).setRegistrationData(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      gender: _gender ?? '',
      dateOfBirth: dateOfBirth,
      city: _city,
      role: 'patient',
      phone: phone,
    );
    ref.read(registrationProvider.notifier).setStep(RegistrationStep.otp);

    context.push('/otp', extra: {
      'role': 'patient',
      'registrationData': {
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'gender': _gender,
        'day': _dayController.text,
        'month': _monthController.text,
        'year': _yearController.text,
        'city': _city,
        'phone': phone,
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;

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
                  t?.t('registration.step', params: {'current': _profileMode ? '2' : '1', 'total': '3'}) ?? '',
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
                  t?.t('registration.title') ?? '',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              if (!_profileMode) ...[
                _buildPhoneField(
                  delay: 0,
                  t: t,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              _buildField(
                delay: 50,
                label: t?.t('registration.firstName') ?? '',
                icon: LucideIcons.user,
                controller: _firstNameController,
                placeholder: t?.t('registration.firstNamePlaceholder') ?? '',
                error: _errors['firstName'],
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildField(
                delay: 100,
                label: t?.t('registration.lastName') ?? '',
                icon: LucideIcons.user,
                controller: _lastNameController,
                placeholder: t?.t('registration.lastNamePlaceholder') ?? '',
                error: _errors['lastName'],
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildGenderField(delay: 150, t: t),
              const SizedBox(height: AppSpacing.xl),
              _buildBirthdayField(delay: 200, t: t),
              const SizedBox(height: AppSpacing.xl),
              _buildLocationField(delay: 250, t: t),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _checkingPhone ? null : _handleContinue,
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
                  child: _checkingPhone
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

  Widget _buildPhoneField({required int delay, required AppLocalization? t, bool readOnly = false}) {
    return AnimatedMount(
      animation: 'fadeInUp',
      delay: delay,
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
            readOnly: readOnly,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
            onChanged: (_) {
              if (_phoneExists || _phoneCheckFailed != null) {
                setState(() {
                  _phoneExists = false;
                  _phoneCheckFailed = null;
                  if (_errors.containsKey('phone')) {
                    _errors.remove('phone');
                  }
                });
              }
            },
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
          if (_phoneExists) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.destructive.withAlpha(13),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.destructive.withAlpha(80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t?.t('registration.phoneAlreadyRegistered') ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.destructive,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _checkingPhone
                        ? null
                        : () => context.push('/signin'),
                    icon: const Icon(
                      LucideIcons.logIn,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      t?.t('registration.loginCta') ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_phoneCheckFailed != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                _phoneCheckFailed!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.destructive,
                ),
              ),
            )
          else if (_errors['phone'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                _errors['phone']!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.destructive,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildField({
    required int delay,
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String placeholder,
    String? error,
  }) {
    return AnimatedMount(
      animation: 'fadeInUp',
      delay: delay,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 16, color: AppColors.foreground),
              hintText: placeholder,
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
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                error,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.destructive,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGenderField({required int delay, required AppLocalization? t}) {
    return AnimatedMount(
      animation: 'fadeInUp',
      delay: delay,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t?.t('registration.gender') ?? '',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _genderButton(
                  label: t?.t('registration.male') ?? '',
                  icon: Icons.male,
                  isSelected: _gender == 'Male',
                  selectedColor: AppColors.primary,
                  selectedBgColor: AppColors.primary,
                  onTap: () => setState(() => _gender = 'Male'),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _genderButton(
                  label: t?.t('registration.female') ?? '',
                  icon: Icons.female,
                  isSelected: _gender == 'Female',
                  selectedColor: const Color(0xFFF472B6),
                  selectedBgColor: const Color(0xFFF472B6),
                  onTap: () => setState(() => _gender = 'Female'),
                ),
              ),
            ],
          ),
          if (_errors['gender'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                _errors['gender']!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.destructive,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _genderButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color selectedColor,
    required Color selectedBgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? selectedBgColor : AppColors.primary.withAlpha(13),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: isSelected ? selectedColor : AppColors.primary.withAlpha(51),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.white : AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isSelected ? AppColors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBirthdayField({required int delay, required AppLocalization? t}) {
    return AnimatedMount(
      animation: 'fadeInUp',
      delay: delay,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.calendar, size: 16, color: AppColors.foreground),
              const SizedBox(width: 6),
              Text(
                t?.t('registration.birthday') ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.border.withAlpha(128)),
            ),
            child: Row(
              children: [
                Expanded(child: _dateInput(
                  label: t?.t('registration.day') ?? '',
                  controller: _dayController,
                  placeholder: t?.t('registration.dayPlaceholder') ?? '',
                  maxLength: 2,
                  error: _errors['day'],
                )),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _dateInput(
                  label: t?.t('registration.month') ?? '',
                  controller: _monthController,
                  placeholder: t?.t('registration.monthPlaceholder') ?? '',
                  maxLength: 2,
                  error: _errors['month'],
                )),
                const SizedBox(width: AppSpacing.md),
                Expanded(flex: 2, child: _dateInput(
                  label: t?.t('registration.year') ?? '',
                  controller: _yearController,
                  placeholder: t?.t('registration.yearPlaceholder') ?? '',
                  maxLength: 4,
                  error: _errors['year'],
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateInput({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    required int maxLength,
    String? error,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.mutedForeground,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: maxLength,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: placeholder,
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
              horizontal: 12,
              vertical: 14,
            ),
          ),
          onChanged: (value) {
            final filtered = value.replaceAll(RegExp(r'\D'), '');
            if (filtered.length > maxLength) {
              controller.text = filtered.substring(0, maxLength);
            } else {
              controller.text = filtered;
            }
            controller.selection = TextSelection.collapsed(offset: controller.text.length);
          },
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              error,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.destructive,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildLocationField({required int delay, required AppLocalization? t}) {
    return AnimatedMount(
      animation: 'fadeInUp',
      delay: delay,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.mapPin, size: 16, color: AppColors.foreground),
              const SizedBox(width: 6),
              Text(
                t?.t('registration.location') ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _city,
            items: [
              DropdownMenuItem(
                value: 'Yaounde',
                child: Text(t?.t('registration.cityYaounde') ?? ''),
              ),
              DropdownMenuItem(
                value: 'Douala',
                child: Text(t?.t('registration.cityDouala') ?? ''),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _city = v);
            },
            decoration: InputDecoration(
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
        ],
      ),
    );
  }
}
