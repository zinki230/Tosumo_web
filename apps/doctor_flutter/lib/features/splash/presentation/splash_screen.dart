import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/app_button.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _checkingAuth = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) setState(() => _checkingAuth = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (authState.status == AuthStatus.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/dashboard');
      });
      return const _SplashScaffold(loading: true);
    }

    if (authState.status == AuthStatus.unknown && _checkingAuth) {
      return const _SplashScaffold(loading: true);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const BrandLogo(size: BrandLogoSize.lg, showTagline: true),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Se connecter',
                      onPressed: () => context.go('/login'),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _SplashScaffold extends StatelessWidget {
  final bool loading;

  const _SplashScaffold({required this.loading});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: loading
              ? const CircularProgressIndicator(color: AppColors.primary)
              : const BrandLogo(size: BrandLogoSize.lg, showTagline: true),
        ),
      ),
    );
  }
}
