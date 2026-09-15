import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';
import 'token_manager.dart';

final tokenManagerProvider = Provider<TokenManager>((ref) {
  return TokenManager(const FlutterSecureStorage());
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(tokenManager: ref.read(tokenManagerProvider));
});
