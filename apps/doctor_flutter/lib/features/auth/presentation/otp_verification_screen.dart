import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/services/error_mapper.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String? phone;

  const OtpVerificationScreen({super.key, this.phone});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _isVerified = false;
  bool _otpSent = false;
  String? _errorMessage;
  int _countdown = 60;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    if (widget.phone != null) {
      _phoneController.text = widget.phone!;
      _startCountdown();
      _otpSent = true;
      _sendOtp();
    }
  }

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

  String get _phone => _phoneController.text.trim();

  void _startCountdown() {
    _canResend = false;
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 0) {
        timer.cancel();
        if (mounted) setState(() => _canResend = true);
      } else {
        if (mounted) setState(() => _countdown--);
      }
    });
  }

  void _onOtpChange(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
  }

  Future<void> _sendOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendOtp(_phone);
      if (mounted) {
        setState(() {
          _otpSent = true;
          _isLoading = false;
        });
        _startCountdown();
      }
    } catch (e) {
      final failure = ErrorMapper.fromException(e);
      if (mounted) {
        setState(() {
          _errorMessage = failure.message;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Veuillez entrer le code à 6 chiffres');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).otpLogin(_phone, code);
      if (mounted) {
        setState(() => _isVerified = true);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) context.go('/dashboard');
        });
      }
    } catch (e) {
      final failure = ErrorMapper.fromException(e);
      if (mounted) setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    await _sendOtp();
    if (mounted) {
      for (final c in _otpControllers) {
        c.clear();
      }
      _otpFocusNodes[0].requestFocus();
    }
  }

  String? _phoneValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Numéro requis';
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 9 || digits.length > 13) return 'Numéro invalide';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isVerified) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.checkCircle, size: 40, color: AppColors.success),
              ),
              const SizedBox(height: 24),
              const Text(
                'Vérifié avec succès!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Redirection en cours...',
                style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => context.pop(),
          color: AppColors.foreground,
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const BrandLogo(size: BrandLogoSize.sm),
            const SizedBox(height: 32),
            const Text(
              'Vérification OTP',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _otpSent
                  ? 'Un code à 6 chiffres a été envoyé à\n$_phone'
                  : 'Entrez votre numéro pour recevoir un code',
              style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: [AppShadows.soft],
              ),
              child: Column(
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (!_otpSent) ...[
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Numéro de téléphone',
                              hintText: '+237 6XX XX XX XX',
                              prefixIcon: Icon(LucideIcons.phone, size: 20),
                            ),
                            validator: _phoneValidator,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_otpSent)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(6, (index) {
                              return SizedBox(
                                width: 48,
                                child: TextField(
                                  controller: _otpControllers[index],
                                  focusNode: _otpFocusNodes[index],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  maxLength: 1,
                                  decoration: InputDecoration(
                                    counterText: '',
                                    filled: true,
                                    fillColor: AppColors.background,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      borderSide: const BorderSide(color: AppColors.border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.foreground,
                                  ),
                                  onChanged: (v) => _onOtpChange(index, v),
                                ),
                              );
                            }),
                          ),
                      ],
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.destructive.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.alertCircle, size: 16, color: AppColors.destructive),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(fontSize: 13, color: AppColors.destructive),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  AppButton(
                    label: _otpSent ? 'Vérifier' : 'Envoyer le code',
                    loading: _isLoading,
                    onPressed: _otpSent ? _verifyOtp : _sendOtp,
                  ),
                  if (_otpSent) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _canResend ? 'Vous n\'avez pas reçu le code?' : 'Renvoyer dans ',
                          style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
                        ),
                        if (!_canResend)
                          Text(
                            '$_countdown s',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        if (_canResend)
                          GestureDetector(
                            onTap: _resendCode,
                            child: const Text(
                              'Renvoyer',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text(
                'Retour à la connexion',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
