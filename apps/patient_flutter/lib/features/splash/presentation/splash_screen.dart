import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _animate = false;
  bool _checkingAuth = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _animate = true);
    });
    _checkAutoLogin();
  }

  void _advance() {
    if (mounted) context.go('/onboarding');
  }

  Future<void> _checkAutoLogin() async {
    try {
      await ref
          .read(authProvider.notifier)
          .tryAutoLogin()
          .timeout(const Duration(seconds: 15), onTimeout: () async {});
    } catch (_) {}
    if (!mounted) return;
    setState(() => _checkingAuth = false);
    // If no session was restored, show the walkthrough before the auth choice.
    if (ref.read(authProvider).status != AuthStatus.authenticated) {
      Future.delayed(const Duration(milliseconds: 1500), _advance);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final authState = ref.watch(authProvider);
    final t = locAsync.asData?.value;

    final bool waiting = _checkingAuth ||
        authState.status == AuthStatus.initial ||
        authState.status == AuthStatus.refreshing ||
        authState.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: waiting
            ? const Center(child: CircularProgressIndicator())
            : authState.status == AuthStatus.error
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 40, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            t?.t('auth.sessionError') ?? 'Impossible de restaurer votre session.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() => _checkingAuth = true);
                              _checkAutoLogin();
                            },
                            child: Text(t?.t('common.retry') ?? 'Réessayer'),
                          ),
                          TextButton(
                            onPressed: () => context.go('/signin'),
                            child: Text(t?.t('auth.logout') ?? 'Se déconnecter'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
          children: [
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: AnimatedOpacity(
                opacity: _animate ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOut,
                child: AnimatedSlide(
                  offset: _animate ? Offset.zero : const Offset(0, 0.15),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOut,
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/TOSUMO.png',
                        height: 96,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t?.t('app.tagline') ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.mutedForeground,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
