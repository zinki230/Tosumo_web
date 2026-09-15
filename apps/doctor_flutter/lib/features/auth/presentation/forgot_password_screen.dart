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

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _stepCode = false;
  bool _isDone = false;
  String? _errorMessage;
  int _countdown = 60;
  Timer? _timer;
  bool _canResend = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _timer?.cancel();
    super.dispose();
  }

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

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendOtp(_phoneController.text.trim());
      if (mounted) {
        setState(() {
          _stepCode = true;
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

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).resetPassword(
        _phoneController.text.trim(),
        _codeController.text.trim(),
        _passwordController.text,
      );
      if (mounted) {
        setState(() => _isDone = true);
      }
    } catch (e) {
      final failure = ErrorMapper.fromException(e);
      if (mounted) {
        setState(() {
          _errorMessage = failure.message;
          _isLoading = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            const BrandLogo(size: BrandLogoSize.md),
            const SizedBox(height: 32),
            Text(
              _isDone ? 'Mot de passe réinitialisé' : 'Mot de passe oublié',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isDone
                  ? 'Vous pouvez vous connecter avec votre nouveau mot de passe'
                  : _stepCode
                      ? 'Entrez le code reçu et votre nouveau mot de passe'
                      : 'Entrez votre numéro pour recevoir un code de réinitialisation',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.mutedForeground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_isDone)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: [AppShadows.soft],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: const Icon(
                        LucideIcons.checkCircle,
                        size: 32,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Réinitialisation réussie!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Se connecter',
                      onPressed: () => context.go('/login'),
                    ),
                  ],
                ),
              )
            else
              Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: [AppShadows.soft],
                  ),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        enabled: !_stepCode,
                        decoration: const InputDecoration(
                          labelText: 'Numéro de téléphone',
                          hintText: '+237 6XX XX XX XX',
                          prefixIcon: Icon(LucideIcons.phone, size: 20),
                        ),
                        validator: _phoneValidator,
                      ),
                      if (_stepCode) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Code de vérification',
                            hintText: '6 chiffres',
                            prefixIcon: Icon(LucideIcons.keyRound, size: 20),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().length != 6) return 'Code à 6 chiffres requis';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Nouveau mot de passe',
                            hintText: 'Minimum 8 caractères',
                            prefixIcon: Icon(LucideIcons.lock, size: 20),
                          ),
                          validator: (v) {
                            if (v == null || v.length < 8) return 'Au moins 8 caractères';
                            return null;
                          },
                        ),
                      ],
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
                        label: _stepCode ? 'Réinitialiser' : 'Envoyer le code',
                        loading: _isLoading,
                        onPressed: _stepCode ? _resetPassword : _sendCode,
                      ),
                      if (_stepCode && !_isDone) ...[
                        const SizedBox(height: 12),
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
                                onTap: _sendCode,
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
              ),
          ],
        ),
      ),
    );
  }
}
