import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../registration/providers/registration_provider.dart';
import '../../patient/providers/patient_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/localization.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/database/local_database.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../shared/widgets/app_animated_mount.dart';
import '../../../core/network/api_providers.dart';
const _steps = [
  ('generatingIdentity', 1500),
  ('identityCreated', 1200),
  ('generatingCard', 1200),
  ('cardGenerated', 1200),
  ('selectingHospital', 1200),
  ('complete', 1200),
];

int _totalDuration() => _steps.fold(0, (acc, s) => acc + s.$2);

class IdentityGenerationScreen extends ConsumerStatefulWidget {
  const IdentityGenerationScreen({super.key});

  @override
  ConsumerState<IdentityGenerationScreen> createState() => _IdentityGenerationScreenState();
}

class _IdentityGenerationScreenState extends ConsumerState<IdentityGenerationScreen> {
  int _step = 0;
  double _progress = 0;
  Timer? _progressTimer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startProgressBar();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startPipeline();
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _startPipeline() async {
    final reg = ref.read(registrationProvider);
    final firstName = reg.firstName.trim();
    final lastName = reg.lastName.trim();
    final gender = reg.gender;
    final dateOfBirth = reg.dateOfBirth;
    final city = reg.city;
    final phone = reg.phone.trim();
    final role = reg.role.isEmpty ? 'patient' : reg.role;
    final name = '$firstName $lastName'.trim();

    if (phone.isEmpty || firstName.isEmpty || lastName.isEmpty) {
      if (mounted) {
        final t = ref.read(localizationProvider(ref.read(localeProvider))).asData?.value;
        setState(() => _error = t?.t('identityGeneration.missingData') ?? '');
      }
      return;
    }

    final authState = ref.read(authProvider);
    if (authState.status != AuthStatus.authenticated) {
      // Only create the account once. If a previous attempt already succeeded
      // (e.g. retry after onboarding failed), reuse the existing session
      // instead of registering again (which would hit the duplicate-phone 409).
      try {
        final ok = await ref.read(authProvider.notifier).register(
          name: name,
          email: 'patient${phone.replaceAll(RegExp(r'[\s+\-]'), '')}@tosumo.cm',
          password: 'Tosumo@${DateTime.now().year}',
          role: role,
          gender: gender,
          dateOfBirth: dateOfBirth,
          city: city,
          phone: phone,
          firstName: firstName,
          lastName: lastName,
        ).timeout(const Duration(seconds: 20), onTimeout: () {
          throw Exception('Délai d\'attente dépassé. Vérifiez votre connexion internet.');
        });
        if (!mounted) return;
        final postAuth = ref.read(authProvider);
        if (!ok || postAuth.status != AuthStatus.authenticated) {
          throw Exception(postAuth.error ?? 'Registration failed');
        }
      } catch (e) {
        // ignore: avoid_print
        print('[REGISTER] account creation failed: $e');
        if (mounted) {
          final t = ref.read(localizationProvider(ref.read(localeProvider))).asData?.value;
          setState(() => _error = t?.t('identityGeneration.accountError') ?? '');
        }
        return;
      }
    }
    final auth = ref.read(authProvider);
    final userId = auth.patient?.id ?? '';
    if (userId.isEmpty) {
      if (mounted) {
        final t = ref.read(localizationProvider(ref.read(localeProvider))).asData?.value;
        setState(() => _error = t?.t('identityGeneration.accountError') ?? '');
      }
      return;
    }

    // Onboard (creates the Patient record + Medical Card). The backend returns
    // the real Patient id, which differs from the User id — use it.
    String realPatientId;
    try {
      final apiClient = ref.read(apiClientProvider);
      final onboard = await apiClient.post('/api/v1/patients/onboard', data: {
        'firstName': firstName,
        'lastName': lastName,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        'city': city,
      }).timeout(const Duration(seconds: 20), onTimeout: () {
        throw Exception('Délai d\'attente dépassé. Vérifiez votre connexion internet.');
      });
      final onboardData = onboard.data;
      final payload = (onboardData is Map && onboardData['data'] is Map)
          ? onboardData['data'] as Map
          : (onboardData is Map ? onboardData : <String, dynamic>{});
      final extractedId = (payload['id'] as String? ?? payload['_id'] as String? ?? '').trim();
      if (extractedId.isNotEmpty) {
        realPatientId = extractedId;
      } else {
        realPatientId = await _safeLoadPatientId(auth.patient?.id ?? '');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[ONBOARD] failed: $e');
      if (mounted) {
        final t = ref.read(localizationProvider(ref.read(localeProvider))).asData?.value;
        setState(() => _error = t?.t('identityGeneration.onboardingError') ?? '');
      }
      return;
    }

    if (!mounted) return;
    if (realPatientId.isEmpty) {
      if (mounted) {
        final t = ref.read(localizationProvider(ref.read(localeProvider))).asData?.value;
        setState(() => _error = t?.t('identityGeneration.patientError') ?? '');
      }
      return;
    }

    // Single source of truth for the session id — persisted deterministically.
    final db = ref.read(localDatabaseProvider);
    try {
      await db.setActivePatientId(realPatientId);
      await ref.read(patientProvider.notifier).loadPatientData(realPatientId)
          .timeout(const Duration(seconds: 20), onTimeout: () {
        throw Exception('Délai d\'attente dépassé lors du chargement du profil.');
      });
      ref.read(authProvider.notifier).markOnboarded();
    } catch (e) {
      // ignore: avoid_print
      print('[PATIENT] load after onboard failed: $e');
      if (mounted) {
        final t = ref.read(localizationProvider(ref.read(localeProvider))).asData?.value;
        setState(() => _error = t?.t('identityGeneration.patientError') ?? '');
      }
      return;
    }

    if (!mounted) return;
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 500));

    var totalOffset = 0;
    for (var i = 0; i < _steps.length; i++) {
      final offset = totalOffset;
      final stepIndex = i;
      Timer(Duration(milliseconds: offset), () {
        if (mounted) setState(() => _step = stepIndex + 1);
      });
      totalOffset += _steps[i].$2;
    }
    Timer(Duration(milliseconds: totalOffset), () {
      if (!mounted) return;
      context.go('/patient/home');
    });
  }

  /// Fallback: reload the real Patient id from the backend when the onboard
  /// response does not include it.
  Future<String> _safeLoadPatientId(String fallback) async {
    if (!mounted) return fallback;
    try {
      final profile = await ref.read(patientRepositoryProvider).getPatientProfile(fallback);
      if (profile != null && profile.id.isNotEmpty) return profile.id;
    } catch (_) {}
    return fallback;
  }

  void _startProgressBar() {
    final total = _totalDuration();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      setState(() {
        _progress = (_progress + 100.0 / (total / 50)).clamp(0, 100);
      });
    });
  }

  void _restartPipeline() {
    _progressTimer?.cancel();
    setState(() {
      _error = null;
      _step = 0;
      _progress = 0;
    });
    _startProgressBar();
    _startPipeline();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.alertCircle, size: 48, color: AppColors.destructive),
                const SizedBox(height: 16),
                Text(t?.t('identityGeneration.errorTitle') ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _restartPipeline,
                  child: Text(t?.t('identityGeneration.retry') ?? ''),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              Color(0xFFF1F5FE),
              AppColors.background,
            ],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 48),
                    _PulseLogo(),
                    const SizedBox(height: 32),
                    if (_step >= 1 && _step < 2)
                      _buildGeneratingIdentity(t),
                    if (_step >= 2 && _step < 3)
                      _buildIdentityCreated(t),
                    if (_step >= 3 && _step < 4)
                      _buildGeneratingCard(t),
                    if (_step >= 4 && _step < 5)
                      _buildCardGenerated(t),
                    if (_step >= 5 && _step < 6)
                      _buildSelectingHospital(t),
                    if (_step >= 6)
                      _buildComplete(t),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_steps.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 6,
                    width: _step > i ? 32 : (_step == i ? 32 : 6),
                    decoration: BoxDecoration(
                      color: _step > i
                          ? AppColors.primary
                          : _step == i
                              ? AppColors.primary.withAlpha(102)
                              : AppColors.muted,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratingIdentity(AppLocalization? t) {
    return AnimatedMount(
      animation: 'fadeInUp',
      duration: 600,
      child: Column(
        children: [
          Text(
            t?.t('identityGeneration.generatingIdentity') ?? '',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 240,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_progress * 1.2 / 100).clamp(0, 1),
                backgroundColor: AppColors.muted,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF22C55E),
                ),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                t?.t('identityGeneration.encrypting') ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityCreated(AppLocalization? t) {
    return AnimatedMount(
      animation: 'fadeInUp',
      duration: 600,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.accent.withAlpha(51),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withAlpha(13),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.check,
                    size: 24,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t?.t('identityGeneration.identityCreated') ?? '',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              t?.t('identityGeneration.identityCreatedDesc') ?? '',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.mutedForeground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.shield, size: 14, color: AppColors.accent),
                const SizedBox(width: 6),
                Text(
                  t?.t('identityGeneration.encryptedStorage') ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratingCard(AppLocalization? t) {
    return AnimatedMount(
      animation: 'fadeInUp',
      duration: 600,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              LucideIcons.creditCard,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            t?.t('identityGeneration.generatingCard') ?? '',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _bouncingDot(0),
              const SizedBox(width: 6),
              _bouncingDot(150),
              const SizedBox(width: 6),
              _bouncingDot(300),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bouncingDot(int delayMs) {
    return TimerBuilder(delayMs: delayMs, builder: (context) {
      return Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      );
    });
  }

  Widget _buildCardGenerated(AppLocalization? t) {
    return AnimatedMount(
      animation: 'fadeInUp',
      duration: 600,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary.withAlpha(51),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(13),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                LucideIcons.creditCard,
                size: 32,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t?.t('identityGeneration.cardGenerated') ?? '',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.shield, size: 12, color: AppColors.accent),
                const SizedBox(width: 4),
                Text(
                  t?.t('identityGeneration.encrypted') ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 16),
                Container(width: 1, height: 12, color: AppColors.mutedForeground.withAlpha(128)),
                const SizedBox(width: 16),
                Icon(LucideIcons.sparkles, size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  t?.t('identityGeneration.secure') ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectingHospital(AppLocalization? t) {
    return AnimatedMount(
      animation: 'fadeInUp',
      duration: 600,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.mapPin,
              size: 32,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            t?.t('identityGeneration.selectingHospital') ?? '',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 200,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: 0.7,
                backgroundColor: AppColors.muted,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF22C55E),
                ),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplete(AppLocalization? t) {
    return AnimatedMount(
      animation: 'fadeInScale',
      duration: 800,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, Color(0xFF4ADE80)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withAlpha(77),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(
              LucideIcons.check,
              size: 40,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            t?.t('identityGeneration.complete') ?? '',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            t?.t('identityGeneration.completeDesc') ?? '',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.mutedForeground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                t?.t('identityGeneration.redirecting') ?? '',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PulseLogo extends StatefulWidget {
  @override
  State<_PulseLogo> createState() => _PulseLogoState();
}

class _PulseLogoState extends State<_PulseLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ScaleTransition(
            scale: TweenSequence<double>([
              TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 1),
              TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 1),
            ]).animate(_controller),
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                shape: BoxShape.circle,
              ),
            ),
          ),
          ScaleTransition(
            scale: TweenSequence<double>([
              TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 1),
              TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 1),
            ]).animate(_controller),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(51),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF60A5FA)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(77),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'T',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TimerBuilder extends StatelessWidget {
  final int delayMs;
  final Widget Function(BuildContext) builder;

  const TimerBuilder({
    super.key,
    required this.delayMs,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return _TimerWidget(delayMs: delayMs, builder: builder);
  }
}

class _TimerWidget extends StatefulWidget {
  final int delayMs;
  final Widget Function(BuildContext) builder;

  const _TimerWidget({required this.delayMs, required this.builder});

  @override
  State<_TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<_TimerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_controller.value * 8),
          child: Opacity(
            opacity: 1.0 - _controller.value * 0.3,
            child: widget.builder(context),
          ),
        );
      },
    );
  }
}
