import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'socket_service.dart';
import 'api_providers.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  final tokenManager = ref.read(tokenManagerProvider);
  final service = SocketService(tokenManager);
  ref.onDispose(() => service.dispose());
  return service;
});
