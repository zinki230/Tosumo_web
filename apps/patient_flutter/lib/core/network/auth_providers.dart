import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';
import 'api_providers.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    ref.read(apiClientProvider),
    ref.read(tokenManagerProvider),
  );
});
