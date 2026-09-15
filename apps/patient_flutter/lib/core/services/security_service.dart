import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityService {
  final FlutterSecureStorage _storage;

  SecurityService(this._storage);

  Future<void> setPinCode(String pin) async {
    await _storage.write(key: 'app_pin', value: pin);
  }

  Future<bool> verifyPinCode(String pin) async {
    final stored = await _storage.read(key: 'app_pin');
    return stored == pin;
  }

  Future<bool> hasPinCode() async {
    final pin = await _storage.read(key: 'app_pin');
    return pin != null && pin.isNotEmpty;
  }

  Future<void> removePinCode() async {
    await _storage.delete(key: 'app_pin');
  }

  Future<void> enableBiometric() async {
    await _storage.write(key: 'biometric_enabled', value: 'true');
  }

  Future<void> disableBiometric() async {
    await _storage.delete(key: 'biometric_enabled');
  }

  Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: 'biometric_enabled');
    return val == 'true';
  }

  bool isDeviceSecure() {
    // Placeholder for root/jailbreak detection
    // In production, use root_detector or similar package
    return true;
  }

  Future<void> setSessionTimeout(int minutes) async {
    await _storage.write(key: 'session_timeout', value: minutes.toString());
  }

  Future<int> getSessionTimeout() async {
    final val = await _storage.read(key: 'session_timeout');
    return int.tryParse(val ?? '') ?? 15;
  }

  bool shouldProtectScreenshots() {
    // Placeholder - in production, use FlutterWindowManager or similar
    return true;
  }
}

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService(const FlutterSecureStorage());
});
