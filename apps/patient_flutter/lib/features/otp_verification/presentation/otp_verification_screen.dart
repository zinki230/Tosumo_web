import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../registration/providers/registration_provider.dart';
import '../../../../core/utils/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/app_animated_mount.dart';
import '../../../../shared/widgets/brand_logo.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_providers.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? registrationData;

  const OtpVerificationScreen({
    super.key,
    this.registrationData,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  static const int _digitCount = 6;
  final List<TextEditingController> _controllers = List.generate(
    _digitCount,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(_digitCount, (_) => FocusNode());
  int _timeLeft = 130;
  bool _loading = false;
  bool _verified = false;
  Timer? _timer;

  String get _phone =>
      (widget.registrationData?['phone'] as String? ?? '').trim().isEmpty
          ? '+237'
          : (widget.registrationData?['phone'] as String? ?? '+237');

  @override
  void initState() {
    super.initState();
    _startTimer();
    _sendOtp();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft <= 0) {
        timer.cancel();
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  void _onDigitPressed(String digit) {
    final firstEmpty = _controllers.indexWhere((c) => c.text.isEmpty);
    if (firstEmpty < 0) return;
    setState(() => _controllers[firstEmpty].text = digit);
    if (firstEmpty < _digitCount - 1) {
      _focusNodes[firstEmpty + 1].requestFocus();
    } else {
      _focusNodes[firstEmpty].unfocus();
    }
    if (_isComplete && !_loading) {
      _verify();
    }
  }

  void _onBackspace() {
    final lastFilled = _controllers.indexWhere((c) => c.text.isEmpty);
    if (lastFilled == 0) return;
    final idx = lastFilled == -1 ? _digitCount - 1 : lastFilled - 1;
    _controllers[idx].clear();
    _focusNodes[idx].requestFocus();
  }

  String get _code => _controllers.map((c) => c.text).join();
  bool get _isComplete => _code.length == _digitCount && _code.characters.every((c) => c.isNotEmpty);

  Future<void> _sendOtp() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post(ApiEndpoints.sendOtp, data: {'phone': _phone});
    } catch (e) {
      if (mounted) {
        final t = ref.read(localizationProvider(ref.read(localeProvider))).asData?.value;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t?.t('otp.sendFailed') ?? '')),
        );
      }
    }
  }

  Future<void> _verify() async {
    if (!_isComplete) return;
    setState(() => _loading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      try {
        await apiClient.post(ApiEndpoints.verifyOtp, data: {
          'phone': _phone,
          'code': _code,
        });
      } catch (_) {
        if (!mounted) return;
        final t = ref.read(localizationProvider(ref.read(localeProvider))).asData?.value;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t?.t('otp.invalidCode') ?? '')),
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _verified = true;
      });
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      ref.read(registrationProvider.notifier).setStep(
        RegistrationStep.generatingIdentity,
      );
      context.push(
        '/onboarding/personal-info',
        extra: {
          'role': 'patient',
          'phone': (widget.registrationData?['phone'] as String?) ?? '',
        },
      );
    } catch (_) {
      if (!mounted) return;
      final t = ref.read(localizationProvider(ref.read(localeProvider))).asData?.value;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t?.t('otp.invalidCode') ?? '')),
      );
    }
  }

  Future<void> _resendOtp() async {
    _timer?.cancel();
    setState(() => _timeLeft = 130);
    _startTimer();
    await _sendOtp();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;
    final minutes = _timeLeft ~/ 60;
    final seconds = _timeLeft % 60;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            const BrandLogo(size: BrandLogoSize.sm),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 6, width: 56,
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  height: 6, width: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  height: 6, width: 56,
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
                t?.t('otp.step', params: {'current': '2', 'total': '3'}) ?? '',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    const AnimatedMount(
                      animation: 'fadeInUp',
                      delay: 0,
                      child: BrandLogo(size: BrandLogoSize.lg, showTagline: true),
                    ),
                    const SizedBox(height: 16),
                    AnimatedMount(
                      animation: 'fadeInUp',
                      delay: 100,
                      child: Column(
                        children: [
                          Text(
                            t?.t('otp.title') ?? '',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text.rich(
                            TextSpan(
                              text: '${t?.t('otp.subtitle') ?? ''} ',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.mutedForeground,
                              ),
                              children: [
                                TextSpan(
                                  text: _phone,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.foreground,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    AnimatedMount(
                      animation: 'fadeInUp',
                      delay: 150,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withAlpha(25),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.warning.withAlpha(80)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(
                              LucideIcons.flaskConical,
                              size: 18,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                t?.t('otp.demoNotice') ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.foreground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedMount(
                      animation: 'fadeInUp',
                      delay: 200,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_digitCount, (i) {
                          return Padding(
                            padding: EdgeInsets.only(
                              left: i > 0 ? 8 : 0,
                            ),
                            child: SizedBox(
                              width: 48,
                              height: 56,
                              child: TextField(
                                controller: _controllers[i],
                                focusNode: _focusNodes[i],
                                enabled: !_loading,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.muted,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.lg),
                                    borderSide: const BorderSide(color: AppColors.border, width: 2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.lg),
                                    borderSide: const BorderSide(color: AppColors.border, width: 2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.lg),
                                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(1),
                                ],
                                keyboardType: TextInputType.none,
                                onChanged: (v) {
                                  if (v.isNotEmpty && i < _digitCount - 1) {
                                    _focusNodes[i + 1].requestFocus();
                                  }
                                },
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 32),
                    AnimatedMount(
                      animation: 'fadeInUp',
                      delay: 300,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.timer,
                            size: 16,
                            color: AppColors.mutedForeground,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')})',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: _timeLeft <= 10
                                  ? AppColors.destructive
                                  : AppColors.foreground,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            t?.t('otp.resend') ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: _timeLeft <= 0 ? _resendOtp : null,
                            child: Text(
                              t?.t('otp.clickHere') ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _timeLeft > 0
                                    ? AppColors.mutedForeground
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    AnimatedMount(
                      animation: 'fadeInUp',
                      delay: 400,
                      child: _verified
                          ? Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withAlpha(25),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      decoration: const BoxDecoration(
                                        color: AppColors.accent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        LucideIcons.checkCircle,
                                        size: 32,
                                        color: AppColors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  t?.t('otp.verified') ?? '',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  t?.t('otp.redirecting') ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              ],
                            )
                          : SizedBox(
                              width: 200,
                              child: ElevatedButton(
                                onPressed: _isComplete && !_loading ? _verify : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.primaryForeground,
                                  disabledBackgroundColor: AppColors.primary.withAlpha(128),
                                  disabledForegroundColor: AppColors.primaryForeground.withAlpha(128),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.full),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  minimumSize: const Size(double.infinity, 48),
                                  elevation: 0,
                                ),
                                child: _loading
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(t?.t('otp.verifying') ?? ''),
                                        ],
                                      )
                                    : Text(t?.t('otp.verify') ?? ''),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.muted.withAlpha(128),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final row in [
                      ['1', '2', '3'],
                      ['4', '5', '6'],
                      ['7', '8', '9'],
                      ['', '0', '⌫'],
                    ])
                      Row(
                        children: row.map((n) {
                          return Expanded(
                            child: GestureDetector(
                              onTap: _loading
                                  ? null
                                  : () {
                                      if (n == '⌫') {
                                        _onBackspace();
                                      } else if (n.isNotEmpty) {
                                        _onDigitPressed(n);
                                      }
                                    },
                              child: Container(
                                height: 56,
                                alignment: Alignment.center,
                                child: n.isEmpty
                                    ? null
                                    : Text(
                                        n,
                                        style: TextStyle(
                                          fontSize: n == '⌫' ? 22 : 24,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

