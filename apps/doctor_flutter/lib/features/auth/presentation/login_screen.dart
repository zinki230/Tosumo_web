import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../core/services/error_mapper.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .login(_emailController.text.trim(), _passwordController.text)
          .timeout(const Duration(seconds: 15), onTimeout: () => throw Exception('Délai d\'attente dépassé. Vérifiez votre connexion.'));
      if (mounted) context.go('/dashboard');
    } catch (e) {
      final failure = ErrorMapper.fromException(e);
      if (mounted) setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 48),
                const BrandLogo(size: BrandLogoSize.lg, showTagline: true),
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: [AppShadows.soft],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Connexion',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Connectez-vous à votre compte',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email ou téléphone',
                          hintText: 'email@exemple.com',
                          prefixIcon: Icon(LucideIcons.mail, size: 20),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Identifiant requis';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          hintText: 'Entrez votre mot de passe',
                          prefixIcon: const Icon(LucideIcons.lock, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Mot de passe requis';
                          return null;
                        },
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
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.destructive,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      AppButton(
                        label: 'Se connecter',
                        loading: _isLoading,
                        onPressed: _login,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/forgot-password'),
                          child: const Text(
                            'Mot de passe oublié?',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.border.withValues(alpha: 0.5))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OU',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: AppColors.border.withValues(alpha: 0.5))),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/otp'),
                    icon: const Icon(LucideIcons.smartphone, size: 20),
                    label: const Text('Connexion par code SMS'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.foreground,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
