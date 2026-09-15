import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';
import '../../../core/utils/localization.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  /// Edit the text here. Animations are shown in order: onboarding_01 -> onboarding_04.
  static const List<_OnboardingSlide> _slides = [
    _OnboardingSlide(
      animation: 'assets/animations/onboarding_01.webm',
      image: 'assets/images/splash_01.jpg',
      title: 'Bienvenue chez TOSUMO',
      description:
          'Votre médecin vous accueille. TOSUMO centralise tout votre dossier médical en un seul endroit sécurisé, toujours à portée de main.',
    ),
    _OnboardingSlide(
      animation: 'assets/animations/onboarding_02.webm',
      image: 'assets/images/splash_02.jpg',
      title: 'Votre carte patient',
      description:
          'Toutes vos informations de santé réunies sur un seul support.',
    ),
    _OnboardingSlide(
      animation: 'assets/animations/onboarding_03.webm',
      image: 'assets/images/splash_03.jpg',
      title: 'Accès instantané par QR',
      description:
          'Un simple code QR suffit pour ouvrir votre dossier médical en quelques secondes, en toute sécurité.',
    ),
    _OnboardingSlide(
      animation: 'assets/animations/onboarding_04.webm',
      image: 'assets/images/splash_04.jpg',
      title: 'Ensemble pour la santé',
      description:
          'Avec TOSUMO, votre médecin vous accompagne au quotidien. Prenez vos rendez-vous, consultations et ordonnances en toute confiance.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => context.go('/welcome'),
                child: Text(
                  t?.t('onboarding.skip') ?? 'Passer',
                  style: const TextStyle(color: AppColors.mutedForeground, fontSize: 14),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final s = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 5,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            child: s.animation == null
                                ? Image.asset(
                                    s.image,
                                    fit: BoxFit.contain,
                                  )
                                : _OnboardingAnimation(
                                    asset: s.animation!,
                                    fallbackImage: s.image,
                                  ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.foreground,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          s.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.mutedForeground,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
              child: Row(
                children: [
                  Row(
                    children: List.generate(
                      _slides.length,
                      (i) => Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: i == _currentPage ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _currentPage ? AppColors.primary : AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLast
                                ? (t?.t('onboarding.getStarted') ?? 'Commencer')
                                : (t?.t('onboarding.next') ?? 'Suivant'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 6),
                          Icon(isLast ? LucideIcons.check : LucideIcons.arrowRight, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  final String? animation;
  final String image;
  final String title;
  final String description;

  const _OnboardingSlide({
    this.animation,
    required this.image,
    required this.title,
    required this.description,
  });
}

class _OnboardingAnimation extends StatefulWidget {
  final String asset;
  final String fallbackImage;

  const _OnboardingAnimation({
    required this.asset,
    required this.fallbackImage,
  });

  @override
  State<_OnboardingAnimation> createState() => _OnboardingAnimationState();
}

class _OnboardingAnimationState extends State<_OnboardingAnimation> {
  late final VideoPlayerController _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.asset);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      await _controller.setVolume(0);
      if (!mounted) return;
      await _controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Image.asset(
        widget.fallbackImage,
        fit: BoxFit.contain,
      );
    }

    if (!_controller.value.isInitialized) {
      return Image.asset(
        widget.fallbackImage,
        fit: BoxFit.contain,
      );
    }

    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: _controller.value.size.width,
          height: _controller.value.size.height,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}