import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/local_database.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/network/auth_providers.dart';
import '../../../core/network/socket_provider.dart';
import '../../../core/network/sync_engine.dart';
import '../../../shared/models/patient.dart';
import '../../patient/providers/patient_provider.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading, refreshing, error }

class AuthState {
  final AuthStatus status;
  final Patient? patient;
  final String role;
  final String? error;
  final bool needsOnboarding;
  final bool isOnboarded;

  const AuthState({
    this.status = AuthStatus.initial,
    this.patient,
    this.role = '',
    this.error,
    this.needsOnboarding = false,
    this.isOnboarded = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    Patient? patient,
    String? role,
    String? error,
    bool? needsOnboarding,
    bool? isOnboarded,
  }) {
    return AuthState(
      status: status ?? this.status,
      patient: patient ?? this.patient,
      role: role ?? this.role,
      error: error,
      needsOnboarding: needsOnboarding ?? this.needsOnboarding,
      isOnboarded: isOnboarded ?? this.isOnboarded,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  bool _onboardingCompleted = false;

  @override
  AuthState build() => const AuthState();

  AuthService get _authService => ref.read(authServiceProvider);

  Future<void> _bootstrapSession(String patientId, String role) async {
    try {
      await ref
          .read(socketServiceProvider)
          .connect()
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
    final loadId = await _effectivePatientId(patientId);
    if (loadId.isNotEmpty) {
      try {
        await ref.read(patientProvider.notifier).loadPatientData(loadId);
      } catch (_) {}
    }
    // The bootstrap may run before onboarding persisted the real patient id,
    // so always re-sync the authoritative patient (resolved from the backend)
    // into the auth state. This replaces the token-derived stub (which lacks
    // city/dob/gender) with the real profile.
    _syncPatientFromState(role);
    try {
      ref.read(syncEngineProvider);
    } catch (_) {}
  }

  /// Copies the real patient resolved by [PatientNotifier.loadPatientData] into
  /// the auth state, so every screen can read the genuine backend profile. Also
  /// flags whether onboarding is still required: a user the backend reports as
  /// onboarded must never be pushed back into the personal-info flow, even if
  /// the local profile hasn't finished loading yet.
  void _syncPatientFromState(String role) {
    final loaded = ref.read(patientProvider).patient;
    final backendOnboarded = state.isOnboarded;
    final needs = !backendOnboarded &&
        !_onboardingCompleted &&
        (loaded == null ||
            loaded.name.isEmpty ||
            loaded.dateOfBirth.year < 1900 ||  // Check for valid date instead of isEmpty
            (loaded.gender?.isEmpty ?? true) ||
            loaded.city.isEmpty);
    if (loaded != null && loaded.id.isNotEmpty) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        patient: loaded,
        role: role,
        needsOnboarding: needs,
      );
    } else {
      state = state.copyWith(role: role, needsOnboarding: needs);
    }
  }

  /// Marks onboarding as complete so the router stops redirecting to the
  /// profile-completion screen.
  void markOnboarded() {
    _onboardingCompleted = true;
    state = state.copyWith(needsOnboarding: false, isOnboarded: true);
  }

  /// Resolves the real patient id for the current session. On first auth the
  /// caller only knows the JWT userId, but the authoritative patient id is the
  /// one persisted to Hive after a successful remote profile load.
  Future<String> _effectivePatientId(String fallback) async {
    try {
      final active = await ref.read(localDatabaseProvider).getActivePatientId();
      if (active.isNotEmpty) return active;
    } catch (_) {}
    return fallback;
  }

  /// Clears any stale active-patient id before a brand-new authentication so a
  /// previous user's cached id can never resolve into the new session.
  Future<void> _prepareFreshSession() async {
    try {
      await ref.read(localDatabaseProvider).clearActivePatientId();
    } catch (_) {}
  }

  Future<void> tryAutoLogin() async {
    // ignore: avoid_print
    print('[AUTH] startup');
    final bool hasSession;
    try {
      hasSession = await _authService.tryAutoLogin();
    } catch (e) {
      // ignore: avoid_print
      print('[AUTH] stored session check failed: $e');
      state = state.copyWith(status: AuthStatus.error);
      return;
    }
    // ignore: avoid_print
    print('[AUTH] stored session found: $hasSession');
    if (!hasSession) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    state = state.copyWith(status: AuthStatus.refreshing);
    // ignore: avoid_print
    print('[AUTH] refreshing token');
    final AuthResult? refreshed = await _refreshOrNull();
    if (refreshed != null) {
      // ignore: avoid_print
      print('[AUTH] refresh successful');
      state = state.copyWith(
        status: AuthStatus.authenticated,
        patient: refreshed.patient,
        role: refreshed.role,
        isOnboarded: refreshed.isOnboarded,
      );
      unawaited(_bootstrapSession(refreshed.patient.id, refreshed.role));
      return;
    }

    // ignore: avoid_print
    print('[AUTH] refresh failed — trying cached session');
    final bool restored = await _restoreCachedSession();
    if (!restored) {
      try {
        await _authService.logout();
      } catch (_) {}
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  /// Attempts to refresh the stored token pair. Returns the resolved session
  /// on success, or null when the network/backend is unavailable.
  Future<AuthResult?> _refreshOrNull() async {
    try {
      return await _authService
          .refreshSession()
          .timeout(const Duration(seconds: 10));
    } on DioException catch (e) {
      final rejected = e.response?.statusCode == 401 || e.response?.statusCode == 403;
      if (rejected) {
        try {
          await _authService.logout();
        } catch (_) {}
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Restores the last cached session (offline-first) when the backend is not
  /// reachable. Returns true when a cached patient matching the current
  /// session was found.
  Future<bool> _restoreCachedSession() async {
    try {
      final db = ref.read(localDatabaseProvider);
      final activeId = await _effectivePatientId('');
      Patient? patient;
      if (activeId.isNotEmpty) {
        patient = await db.getById('medicard_patient', activeId, Patient.fromJson);
      }
      if (patient == null) {
        final all = await db.getAll('medicard_patient', Patient.fromJson);
        for (final p in all) {
          if (p.id == activeId) {
            patient = p;
            break;
          }
        }
      }
      if (patient != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          patient: patient,
          role: 'patient',
        );
        unawaited(_bootstrapSession(patient.id, 'patient'));
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    await _prepareFreshSession();
    try {
      final result = await _authService.login(identifier: identifier, password: password);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        patient: result.patient,
        role: result.role,
        isOnboarded: result.isOnboarded,
      );
      await _bootstrapSession(result.patient.id, result.role);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _friendlyError(e),
      );
      return false;
    }
  }

  /// Sends an OTP to the patient's phone for passwordless login. Returns null
  /// on success (with the backend mode), or a friendly error message.
  Future<String?> sendLoginOtp(String phone) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      return await _authService.sendOtp(phone: phone);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _friendlyError(e),
      );
      return null;
    }
  }

  /// Completes passwordless login with the OTP code the patient received.
  Future<bool> loginWithOtp({
    required String phone,
    required String code,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    await _prepareFreshSession();
    try {
      final result = await _authService.otpLogin(phone: phone, code: code);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        patient: result.patient,
        role: result.role,
        isOnboarded: result.isOnboarded,
      );
      await _bootstrapSession(result.patient.id, result.role);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _friendlyError(e),
      );
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? gender,
    String? dateOfBirth,
    String? city,
    String? phone,
    String? firstName,
    String? lastName,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    await _prepareFreshSession();
    try {
      final result = await _authService.register(
        name: name,
        email: email,
        password: password,
        role: role,
        gender: gender,
        dateOfBirth: dateOfBirth,
        city: city,
        phone: phone,
        firstName: firstName,
        lastName: lastName,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        patient: result.patient,
        role: result.role,
        isOnboarded: result.isOnboarded,
      );
      await _bootstrapSession(result.patient.id, result.role);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _friendlyError(e),
      );
      return false;
    }
  }

  Future<void> logout() async {
    _onboardingCompleted = false;
    try {
      ref.read(socketServiceProvider).disconnect();
    } catch (_) {}
    try {
      await ref.read(localDatabaseProvider).clearUserCache();
    } catch (_) {}
    try {
      ref.read(patientProvider.notifier).resetState();
    } catch (_) {}
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Returns the backend error `code` (e.g. PHONE_ALREADY_REGISTERED) when the
  /// request failed with a typed API error, otherwise null.
  static String? backendErrorCode(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final code = data['code'];
        if (code is String && code.isNotEmpty) return code;
      }
    }
    return null;
  }

  String _friendlyError(Object error) {
    final code = AuthNotifier.backendErrorCode(error);
    if (code == 'PHONE_ALREADY_REGISTERED') {
      return 'Ce numéro est déjà utilisé. Veuillez vous connecter ou utiliser un autre numéro.';
    }
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('incorrect password') ||
        lower.contains('invalid credentials') ||
        lower.contains('identifiants')) {
      return 'Identifiant ou mot de passe incorrect.';
    }
    if (lower.contains('already registered') || lower.contains('déjà utilisé')) {
      return 'Ce numéro est déjà utilisé. Veuillez vous connecter ou utiliser un autre numéro.';
    }
    if (lower.contains('not registered') || lower.contains('non enregistré')) {
      return 'Ce numéro de téléphone n’est pas enregistré.';
    }
    if (lower.contains('invalid or expired otp') ||
        lower.contains('code invalide') ||
        lower.contains('expired otp')) {
      return 'Code invalide ou expiré. Veuillez réessayer.';
    }
    if (lower.contains('deactivated') || lower.contains('désactivé')) {
      return 'Ce compte est désactivé. Contactez le support.';
    }
    if (lower.contains('not found') || lower.contains('introuvable')) {
      return 'Ce compte n’existe pas. Vérifiez vos identifiants.';
    }
    if (lower.contains('internet') || lower.contains('connection error') ||
        lower.contains('socketexception')) {
      return 'Pas de connexion internet. Vérifiez votre réseau puis réessayez.';
    }
    return raw;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);