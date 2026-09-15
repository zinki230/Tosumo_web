import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/utils/localization.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../shared/widgets/app_animated_mount.dart';
import '../providers/auth_provider.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _otpStep = false;
  bool _loading = false;
  bool _otpVerified = false;
  int _timeLeft = 130;
  Timer? _timer;
  String _otpMode = '';
  String? _fieldError;

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  String get _normalizedPhone => normalizeCameroonPhone(_phoneController.text);

  bool get _phoneValid => isValidCameroonPhone(_phoneController.text);

  String get _maskedPhone => _normalizedPhone.length >= 10
      ? '${_normalizedPhone.substring(0, 8)}••••'
      : _normalizedPhone;

  String get _otpCode => _otpControllers.map((c) => c.text).join();
  bool get _otpComplete => _otpCode.length == 6;

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = 130;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_timeLeft <= 0) {
        timer.cancel();
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  Future<void> _sendCode() async {
    if (!_phoneValid) {
      setState(() => _fieldError = 'auth.invalidPhone');
      return;
    }
    setState(() {
      _loading = true;
      _fieldError = null;
    });
    final mode = await ref
        .read(authProvider.notifier)
        .sendLoginOtp(_normalizedPhone);
    if (!mounted) return;
    final authState = ref.read(authProvider);
    if (mode == null) {
      setState(() => _loading = false);
      if (authState.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authState.error!), backgroundColor: Colors.red),
        );
      }
      return;
    }
    setState(() {
      _loading = false;
      _otpMode = mode;
      _otpStep = true;
      _fieldError = null;
    });
    _startTimer();
  }

  Future<void> _verifyCode() async {
    if (!_otpComplete) return;
    setState(() => _loading = true);
    final ok = await ref
        .read(authProvider.notifier)
        .loginWithOtp(phone: _normalizedPhone, code: _otpCode);
    if (!mounted) return;
    setState(() => _loading = false);
    final authState = ref.read(authProvider);
    if (ok && authState.status == AuthStatus.authenticated) {
      setState(() => _otpVerified = true);
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      context.go('/patient/home');
    } else if (authState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authState.error!), backgroundColor: Colors.red),
      );
      _clearOtp();
    }
  }

  void _clearOtp() {
    for (final c in _otpControllers) {
      c.clear();
    }
    if (mounted && _otpFocusNodes.isNotEmpty) {
      _otpFocusNodes[0].requestFocus();
    }
  }

  void _changeNumber() {
    setState(() => _otpStep = false);
    _timer?.cancel();
    _clearOtp();
  }

  void _onOtpDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    if (_otpComplete) {
      _verifyCode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: _otpStep
            ? IconButton(
                icon: const Icon(LucideIcons.arrowLeft, size: 20),
                onPressed: _loading ? null : _changeNumber,
              )
            : null,
        title: Text(
          _otpStep
              ? (t?.t('otp.title') ?? '')
              : (t?.t('auth.signInTitle') ?? ''),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: _otpStep ? _buildOtpStep(context, t) : _buildPhoneStep(context, t),
    );
  }

  Widget _buildPhoneStep(BuildContext context, AppLocalization? t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          AnimatedMount(
            animation: 'fadeInUp',
            delay: 0,
            child: Text(
              t?.t('auth.phoneLoginTitle') ?? '',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedMount(
            animation: 'fadeInUp',
            delay: 80,
            child: Text(
              t?.t('auth.phoneLoginSubtitle') ?? '',
              style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          AnimatedMount(
            animation: 'fadeInUp',
            delay: 150,
            child: TextField(
              controller: _phoneController,
              enabled: !_loading,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                labelText: t?.t('auth.phone') ?? '',
                prefixIcon: const Icon(LucideIcons.phone, size: 18),
                prefixText: '+237 ',
                prefixStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: AppColors.border.withAlpha(128)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                errorText: _fieldError != null ? t?.t(_fieldError!) : null,
              ),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedMount(
            animation: 'fadeInUp',
            delay: 220,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(LucideIcons.flaskConical, size: 16, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t?.t('otp.demoNotice') ?? '',
                    style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _sendCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.primary.withAlpha(128),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                    )
                  : Text(
                      t?.t('auth.sendCode') ?? '',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                t?.t('auth.noAccount') ?? '',
                style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => context.push('/register'),
                child: Text(
                  t?.t('auth.register') ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep(BuildContext context, AppLocalization? t) {
    final minutes = _timeLeft ~/ 60;
    final seconds = _timeLeft % 60;
    final isDemo = _otpMode.isEmpty || _otpMode == 'demo';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          AnimatedMount(
            animation: 'fadeInUp',
            delay: 0,
            child: Text(
              t?.t('otp.title') ?? '',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedMount(
            animation: 'fadeInUp',
            delay: 80,
            child: Text.rich(
              TextSpan(
                text: '${t?.t('otp.subtitle') ?? ''} ',
                style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground),
                children: [
                  TextSpan(
                    text: _maskedPhone,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          if (isDemo)
            AnimatedMount(
              animation: 'fadeInUp',
              delay: 120,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.warning.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.flaskConical, size: 18, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t?.t('otp.demoNotice') ?? '',
                        style: const TextStyle(fontSize: 12, color: AppColors.foreground),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          AnimatedMount(
            animation: 'fadeInUp',
            delay: 180,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) {
                return Padding(
                  padding: EdgeInsets.only(left: i > 0 ? 8 : 0),
                  child: SizedBox(
                    width: 46,
                    height: 54,
                    child: TextField(
                      controller: _otpControllers[i],
                      focusNode: _otpFocusNodes[i],
                      enabled: !_loading,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
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
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(1),
                      ],
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _onOtpDigitChanged(i, v),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedMount(
            animation: 'fadeInUp',
            delay: 260,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.timer,
                  size: 16,
                  color: _timeLeft <= 10 ? AppColors.destructive : AppColors.mutedForeground,
                ),
                const SizedBox(width: 8),
                Text(
                  '(${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')})',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: _timeLeft <= 10 ? AppColors.destructive : AppColors.foreground,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  t?.t('otp.resend') ?? '',
                  style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: (_timeLeft <= 0 && !_loading) ? _sendCode : null,
                  child: Text(
                    t?.t('otp.clickHere') ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _timeLeft > 0 ? AppColors.mutedForeground : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          AnimatedMount(
            animation: 'fadeInUp',
            delay: 320,
            child: _otpVerified
                ? Column(
                    children: [
                      const Icon(LucideIcons.checkCircle, size: 64, color: AppColors.accent),
                      const SizedBox(height: 12),
                      Text(
                        t?.t('otp.verified') ?? '',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _otpComplete && !_loading ? _verifyCode : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: AppColors.primary.withAlpha(128),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                            )
                          : Text(
                              t?.t('otp.verify') ?? '',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
