import '../config/app_environment.dart';

/// Contract for OTP verification providers.
abstract class OtpProvider {
  Future<bool> sendOtp({
    required String phone,
    String? email,
  });

  Future<bool> verifyOtp({
    required String phone,
    required String otp,
    String? email,
  });
}

/// The Android emulator/device reaches the backend through a local reverse.
///
/// The [OtpService] wraps the repository layer so the UI never needs to know
/// whether verification is demo or real. In demo mode the backend accepts a
/// well-formed code (no real SMS is sent) but the phone number submitted is
/// the patient's real number and the backend still updates phone ownership.
class OtpService {
  OtpService();

  OtpMode get mode => AppEnvironment.current.otpMode;

  bool get isDemo => mode.isDemo;

  /// Short human-readable label used by the UI to tell demo vs real delivery.
  String get deliveryLabel => isDemo ? 'Demo OTP' : 'OTP';
}