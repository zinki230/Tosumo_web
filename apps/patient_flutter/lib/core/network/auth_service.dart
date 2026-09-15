import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'token_manager.dart';
import '../../../shared/models/patient.dart';

Map<String, dynamic> _safeJson(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return data.cast<String, dynamic>();
  return <String, dynamic>{};
}

Map<String, dynamic> _safeMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return <String, dynamic>{};
}

String _safeString(dynamic value) => value?.toString() ?? '';

bool _looksLikePhone(String identifier) =>
    identifier.contains('@') == false &&
    identifier.replaceAll(RegExp(r'[^0-9+]'), '').isNotEmpty;

class AuthService {
  final ApiClient _client;
  final TokenManager _tokenManager;

  AuthService(this._client, this._tokenManager);

  /// Logs in with either an email or a phone number.
  Future<AuthResult> login({
    required String identifier,
    required String password,
  }) async {
    final isPhone = _looksLikePhone(identifier);
    final response = await _client.post(ApiEndpoints.login, data: {
      if (isPhone) 'phone': identifier else 'email': identifier,
      'password': password,
    });
    return await _buildAuthResult(response.data);
  }

  /// Requests a one-time code for the given phone number. Returns the OTP
  /// mode reported by the backend so the UI can show the demo notice.
  Future<String> sendOtp({required String phone}) async {
    final response = await _client.post(ApiEndpoints.sendOtp, data: {
      'phone': phone,
    });
    final data = _safeJson(response.data);
    return _safeString(data['mode']);
  }

  /// Checks whether a phone number already belongs to an account. The backend
  /// (and the database unique index) remain the source of truth; this only
  /// gives the registration UI an early, clear rejection before OTP.
  Future<bool> phoneAlreadyRegistered({required String phone}) async {
    final response = await _client.post(ApiEndpoints.checkPhone, data: {
      'phone': phone,
    });
    final data = _safeJson(response.data);
    return data['exists'] == true;
  }

  /// Passwordless login: exchanges a verified OTP for a real token pair.
  Future<AuthResult> otpLogin({
    required String phone,
    required String code,
  }) async {
    final response = await _client.post(ApiEndpoints.otpLogin, data: {
      'phone': phone,
      'code': code,
    });
    return await _buildAuthResult(response.data);
  }

  Future<AuthResult> register({
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
    final response = await _client.post(ApiEndpoints.register, data: {
      'email': email,
      'phone': phone ?? email,
      'password': password,
      'role': role,
      'firstName': ?firstName,
      'lastName': ?lastName,
    });
    if (kDebugMode) print('[REGISTER] Backend registration successful');
    return await _buildAuthResult(response.data);
  }

  Future<void> logout() async {
    try {
      await _client.post(ApiEndpoints.logout);
    } catch (_) {}
    await _tokenManager.clearTokens();
  }

  Future<bool> tryAutoLogin() async {
    return _tokenManager.hasTokens();
  }

  /// Refreshes the token pair and resolves the authenticated user from the
  /// backend. Returns the sanitized auth profile (id, role, contact details).
  Future<AuthResult> refreshSession() async {
    final refreshToken = await _tokenManager.getRefreshToken();
    if (refreshToken == null) throw Exception('No refresh token available');
    final response = await _client.post(ApiEndpoints.refresh, data: {
      'refreshToken': refreshToken,
    });
    final data = _safeJson(response.data);
    final tokens = data.containsKey('tokens')
        ? _safeMap(data['tokens'])
        : data.containsKey('accessToken')
            ? data
            : const <String, dynamic>{};
    final access = _safeString(tokens['accessToken']);
    if (access.isEmpty) throw Exception('Refresh failed: no access token in response');
    await _tokenManager.saveTokens(
      accessToken: access,
      refreshToken: _safeString(tokens['refreshToken']),
    );
    if (kDebugMode) print('[TOKEN] Session refreshed & tokens persisted');

    final rest = await _client.get(ApiEndpoints.authProfile);
    return await _buildAuthResult({'user': rest.data});
  }

  /// Loads the current authenticated user full resolution for the session.
  Future<AuthResult> currentSession() async {
    final rest = await _client.get(ApiEndpoints.authProfile);
    return await _buildAuthResult({'user': rest.data});
  }

  Future<AuthResult> _buildAuthResult(dynamic raw) async {
    final data = _safeJson(raw);
    final tokens = _safeMap(data['tokens']);
    final access = _safeString(tokens['accessToken']);
    final user = _safeMap(data['user']);
    final userId = _safeString(user['id']);
    final patientId = _safeString(user['patientId']);
    final effectiveId = patientId.isNotEmpty ? patientId : userId;
    if (access.isNotEmpty) {
      await _tokenManager.saveTokens(
        accessToken: access,
        refreshToken: _safeString(tokens['refreshToken']),
      );
      await _tokenManager.saveUserId(userId);
      if (kDebugMode) {
        print('[TOKEN] Access token received: true');
        print('[TOKEN] Refresh token received: true');
        print('[TOKEN] Access token persisted: true');
        print('[TOKEN] Refresh token persisted: true');
        print('[USER] User ID: $userId');
      }
    }
    final firstName = _safeString(user['firstName']);
    final lastName = _safeString(user['lastName']);
    final userName = '$firstName $lastName'.trim();
    final isOnboarded = user['isOnboarded'] == true;
    return AuthResult(
      patient: Patient(
        id: effectiveId,
        name: userName,
        dateOfBirth: '',
        nationalId: '',
        gender: '',
        bloodType: '',
        allergies: [],
        chronicConditions: [],
        currentMeds: [],
        contactInfo: ContactInfo(
          phone: _safeString(user['phone']),
          email: _safeString(user['email']),
        ),
        emergencyContact: const EmergencyContact(name: '', relationship: '', phone: ''),
        status: _safeString(user['isActive']) == 'false' ? 'INACTIVE' : 'ACTIVE',
      ),
      role: _safeString(user['role']),
      isOnboarded: isOnboarded,
    );
  }
}

class AuthResult {
  final Patient patient;
  final String role;
  final bool isOnboarded;

  AuthResult({required this.patient, required this.role, this.isOnboarded = false});
}