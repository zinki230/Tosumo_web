import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/doctor.dart';
import '../data/repositories/repository_providers.dart';
import '../services/error_mapper.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final String? userId;
  final Doctor? doctor;
  final String? token;
  final bool isOffline;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.userId,
    this.doctor,
    this.token,
    this.isOffline = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    Doctor? doctor,
    String? token,
    bool? isOffline,
  }) {
    return AuthState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      doctor: doctor ?? this.doctor,
      token: token ?? this.token,
      isOffline: isOffline ?? this.isOffline,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

class AuthNotifier extends Notifier<AuthState> {
  static const _restoreTimeout = Duration(seconds: 15);

  @override
  AuthState build() {
    _restoreSession();
    return const AuthState();
  }

  Future<void> _restoreSession() async {
    final auth = ref.read(authRepositoryProvider);
    try {
      if (!await auth.isAuthenticated().timeout(_restoreTimeout)) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }

      var token = await auth.getToken();
      var offline = false;
      try {
        await auth.refresh().timeout(_restoreTimeout);
        token = await auth.getToken() ?? token;
      } catch (e) {
        final failure = ErrorMapper.fromException(e);
        if (failure is AuthFailure && failure.statusCode == 401) {
          await auth.logout();
          state = const AuthState(status: AuthStatus.unauthenticated);
          return;
        }
        offline = true;
      }

      Doctor? doctor;
      try {
        doctor = await ref.read(doctorRepositoryProvider).getProfile('').timeout(_restoreTimeout);
        if (doctor.id.isNotEmpty) {
          // The doctor record id is the key used for the local cache and for
          // doctor-scoped lookups. The auth endpoint reports the User id, which
          // can differ, so overwrite the stored id with the authoritative
          // doctor id to keep offline restores consistent.
          await auth.saveUserId(doctor.id);
        }
      } catch (_) {
        // Offline or profile not registered yet. The remote lookup uses an
        // empty id (token-based), but the *local* cache is keyed by the doctor
        // id, so fall back to the persisted id to restore the profile from
        // disk on a fully-offline cold start.
        final storedId = await auth.getUserId();
        if (storedId != null && storedId.isNotEmpty) {
          try {
            doctor = await ref
                .read(doctorRepositoryProvider)
                .getProfile(storedId)
                .timeout(_restoreTimeout);
          } catch (_) {}
        }
      }

      state = AuthState(
        status: AuthStatus.authenticated,
        userId: await auth.getUserId(),
        doctor: doctor,
        token: token,
        isOffline: offline,
      );
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.unknown);
    try {
      await ref.read(authRepositoryProvider).login(email, password);
      await _bootstrap();
    } catch (e) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      rethrow;
    }
  }

  Future<void> otpLogin(String phone, String code) async {
    state = state.copyWith(status: AuthStatus.unknown);
    try {
      await ref.read(authRepositoryProvider).otpLogin(phone, code);
      await _bootstrap();
    } catch (e) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      rethrow;
    }
  }

  Future<void> _bootstrap() async {
    final auth = ref.read(authRepositoryProvider);
    final token = await auth.getToken();
    Doctor? doctor;
    try {
      doctor = await ref.read(doctorRepositoryProvider).getProfile('');
      if (doctor.id.isNotEmpty) {
        await auth.saveUserId(doctor.id);
      }
    } catch (_) {}
    state = AuthState(
      status: AuthStatus.authenticated,
      userId: await auth.getUserId(),
      doctor: doctor,
      token: token,
    );
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (_) {}
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void refreshDoctor(Doctor doctor) {
    state = state.copyWith(doctor: doctor);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final currentDoctorIdProvider = Provider<String?>((ref) {
  final state = ref.watch(authProvider);
  if (state.doctor != null) return state.doctor!.id;
  return state.userId;
});
