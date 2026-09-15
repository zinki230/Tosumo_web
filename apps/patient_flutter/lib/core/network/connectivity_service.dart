import 'dart:async';
import 'dart:io';

import 'api_endpoints.dart';

class ConnectivityService {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  Timer? _pollTimer;

  Stream<bool> get onConnectivityChanged => _controller.stream;
  bool _isConnected = true;
  bool get isConnected => _isConnected;

  ConnectivityService() {
    _checkConnectivity();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkConnectivity());
  }

  Future<void> _checkConnectivity() async {
    try {
      final uri = Uri.parse(ApiEndpoints.baseUrl);
      final result = await InternetAddress.lookup(uri.host);
      _isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      _isConnected = false;
    }
    _controller.add(_isConnected);
  }

  Future<bool> checkNow() async {
    await _checkConnectivity();
    return _isConnected;
  }

  void dispose() {
    _pollTimer?.cancel();
    _controller.close();
  }
}
