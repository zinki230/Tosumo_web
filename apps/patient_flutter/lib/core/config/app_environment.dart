import 'package:flutter/foundation.dart';

/// Centralized demo/production environment configuration.
///
/// Only layers that genuinely require an external provider (SMS/OTP delivery,
/// mobile-money, push notifications) may run in DEMO mode. Everything else
/// talks to the real backend.
class AppEnvironment {
  const AppEnvironment({
    required this.apiBaseUrl,
    this.otpMode = OtpMode.demo,
    this.paymentMode = PaymentMode.demo,
    this.pushMode = PushPushMode.demo,
  });

  final String apiBaseUrl;

  /// How OTP delivery is handled. [OtpMode.demo] keeps the UI clearly marked
  /// as demo while still validating through the real backend.
  final OtpMode otpMode;

  /// Which payment provider handles the (demo) payment flow.
  final PaymentMode paymentMode;

  /// Push delivery. Firebase is not configured, so the default stays demo.
  final PushPushMode pushMode;

  /// Build-time API endpoint selection.
  ///
  /// * `--dart-define=API_BASE_URL=...` always wins (use it for a physical
  ///   Android device in DEBUG mode — point it at your dev machine's LAN IP,
  ///   e.g. `http://192.168.1.23:3000`).
  /// * Flutter Web → the deployed Railway backend (debug or release) so the
  ///   demo/production web app always talks to the real API.
  /// * Android emulator (debug) → `10.0.2.2` (the host machine's loopback).
  /// * Desktop / iOS simulator (debug) → `localhost`.
  /// * Release (APK/AAB) → the deployed Railway backend.
  static const String _definedApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get _apiBaseUrl {
    if (_definedApiBaseUrl.isNotEmpty) return _definedApiBaseUrl;
    if (kIsWeb) return 'https://tosumo-production.up.railway.app';
    if (kDebugMode) {
      // A physical Android device cannot reach the emulator loopback
      // (10.0.2.2), so default debug Android traffic to the deployed Railway
      // backend. For local emulator development, override explicitly with
      // --dart-define=API_BASE_URL=http://10.0.2.2:3000.
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'https://tosumo-production.up.railway.app';
      }
      return 'http://localhost:3000';
    }
    return 'https://tosumo-production.up.railway.app';
  }

  static final AppEnvironment current = AppEnvironment(
    apiBaseUrl: _apiBaseUrl,
    otpMode: OtpMode.demo,
    paymentMode: PaymentMode.demo,
    pushMode: PushPushMode.demo,
  );
}

/// OTP delivery strategy.
enum OtpMode {
  /// SMS provider not configured: the backend accepts a well-formed code and
  /// the UI clearly states that delivery is simulated. The phone number
  /// submitted stays real.
  demo,

  /// Real SMS provider configured; requires a genuinely received code.
  real,
}

/// Payment provider strategy.
enum PaymentMode {
  demo,
  orangeMoney,
  mtnMobile,
  card,
}

/// Push notification strategy.
enum PushPushMode {
  demo,
  firebase,
}

extension OtpModeX on OtpMode {
  bool get isDemo => this == OtpMode.demo;
  bool get isReal => this == OtpMode.real;
}

extension PaymentModeX on PaymentMode {
  bool get isDemo => this == PaymentMode.demo;

  String get label {
    switch (this) {
      case PaymentMode.demo:
        return 'Demo Payment';
      case PaymentMode.orangeMoney:
        return 'Orange Money';
      case PaymentMode.mtnMobile:
        return 'MoMo';
      case PaymentMode.card:
        return 'Card';
    }
  }
}

extension PushModeX on PushPushMode {
  bool get isDemo => this == PushPushMode.demo;
}