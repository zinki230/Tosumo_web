import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Persists the token pair to secure storage with a file-backed fallback.
///
/// Mirrors the TOSUMO Patient app's TokenManager: secure storage
/// (EncryptedSharedPreferences) can fail to persist across restarts, so the
/// session is mirrored into a private JSON file in the app documents
/// directory. Secure storage remains the primary source where it works; the
/// file guarantees a stored session can always be restored on cold start.
class TokenStorageService {
  final FlutterSecureStorage _storage;
  static const String _fileName = 'tosumo_doctor_session.json';
  File? _cachedFile;

  TokenStorageService(this._storage);

  Future<File> _file() async {
    if (_cachedFile != null) return _cachedFile!;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_fileName');
    _cachedFile = file;
    return file;
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _writeFile({
      'access_token': accessToken,
      'refresh_token': refreshToken,
    });
    try {
      await Future.wait([
        _storage.write(key: 'access_token', value: accessToken),
        _storage.write(key: 'refresh_token', value: refreshToken),
      ]);
    } catch (_) {}
  }

  Future<void> saveToken(String token) async {
    await saveTokens(accessToken: token, refreshToken: await getRefreshToken() ?? '');
  }

  Future<void> saveRefreshToken(String token) async {
    await saveTokens(accessToken: await getAccessToken() ?? '', refreshToken: token);
  }

  Future<String?> getToken() async => getAccessToken();

  Future<String?> getAccessToken() async {
    try {
      final token = await _storage.read(key: 'access_token');
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}
    return _readFile('access_token');
  }

  Future<String?> getRefreshToken() async {
    try {
      final token = await _storage.read(key: 'refresh_token');
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}
    return _readFile('refresh_token');
  }

  Future<bool> hasTokens() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> saveUserId(String userId) async {
    try {
      await _storage.write(key: 'user_id', value: userId);
    } catch (_) {}
    await _writeFile({'user_id': userId});
  }

  Future<String?> getUserId() async {
    try {
      final userId = await _storage.read(key: 'user_id');
      if (userId != null && userId.isNotEmpty) return userId;
    } catch (_) {}
    return _readFile('user_id');
  }

  Future<void>? _lastRefresh;

  /// Serializes token refreshes so concurrent 401s never issue parallel
  /// refresh calls using the same refresh token. The server rotates the token
  /// on every refresh and rejects a second one with the now-stale token, which
  /// previously wiped the session. Callers share one refresh at a time and
  /// always operate on the freshest stored token.
  Future<void> runRefreshLocked(Future<void> Function() action) {
    final previous = _lastRefresh ?? Future<void>.value();
    final result = previous.then((_) => action());
    _lastRefresh = result.catchError((_) {});
    return result;
  }

  Future<void> deleteToken() => clearTokens();

  Future<void> deleteRefreshToken() => clearTokens();

  Future<void> deleteUserData() => clearTokens();

  Future<void> clearTokens() async {
    try {
      await Future.wait([
        _storage.delete(key: 'access_token'),
        _storage.delete(key: 'refresh_token'),
        _storage.delete(key: 'user_id'),
      ]);
    } catch (_) {}
    await _deleteFile();
  }

  Future<void> clearAll() => clearTokens();

  Future<void> _writeFile(Map<String, String> values) async {
    try {
      final file = await _file();
      final existing = <String, String>{};
      if (await file.exists()) {
        try {
          final decoded = jsonDecode(await file.readAsString());
          if (decoded is Map) {
            existing.addAll(decoded.cast<String, String>());
          }
        } catch (_) {}
      }
      existing.addAll(values);
      await file.writeAsString(jsonEncode(existing));
    } catch (_) {}
  }

  Future<String?> _readFile(String key) async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final value = decoded[key];
      return (value is String && value.isNotEmpty) ? value : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteFile() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        await file.delete();
      }
      _cachedFile = null;
    } catch (_) {}
  }
}
