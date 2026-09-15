import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';
import 'api_endpoints.dart';
import 'token_manager.dart';

class SocketService {
  io.Socket? _socket;
  final TokenManager _tokenManager;
  bool _isConnected = false;
  bool _disposed = false;
  bool _connecting = false;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  final _appointmentController = StreamController<Map<String, dynamic>>.broadcast();
  final _emergencyController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onNotification => _notificationController.stream;
  Stream<Map<String, dynamic>> get onAppointment => _appointmentController.stream;
  Stream<Map<String, dynamic>> get onEmergency => _emergencyController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<bool> get onConnectionChange => _connectionController.stream;
  bool get isConnected => _isConnected;

  SocketService(this._tokenManager);

  Map<String, dynamic> _safeData(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  void _safeAdd(StreamController<Map<String, dynamic>> controller, dynamic data) {
    if (!controller.isClosed) {
      controller.add(_safeData(data));
    }
  }

  Future<void> connect() async {
    if (_disposed || _connecting) return;
    _connecting = true;
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
    }

    final token = await _tokenManager.getAccessToken();
    if (token == null) {
      _connectionController.add(false);
      _connecting = false;
      return;
    }

    try {
      final uri = ApiEndpoints.baseUrl.replaceFirst('https', 'wss').replaceFirst('http', 'ws');
      _socket = io.io(
        uri,
        io.OptionBuilder()
          .setTransports(['websocket'])
          .setPath('/ws')
          .setAuth({'token': token})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .enableForceNew()
          .disableAutoConnect()
          .build(),
      );

      _socket!.onConnect((_) {
        _isConnected = true;
        _connectionController.add(true);
        if (kDebugMode) debugPrint('Socket connected');
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        _connectionController.add(false);
        if (kDebugMode) debugPrint('Socket disconnected');
      });

      _socket!.onConnectError((data) {
        _isConnected = false;
        _connectionController.add(false);
        if (kDebugMode) debugPrint('Socket connect error: $data');
      });

      _socket!.on('message:new', (data) {
        _safeAdd(_messageController, data);
      });

      _socket!.on('notification:new', (data) {
        _safeAdd(_notificationController, data);
      });

      _socket!.on('notification:updated', (data) {
        _safeAdd(_notificationController, data);
      });

      _socket!.on('appointment:new', (data) {
        _safeAdd(_appointmentController, data);
      });

      _socket!.on('appointment:updated', (data) {
        _safeAdd(_appointmentController, data);
      });

      _socket!.on('appointment:cancelled', (data) {
        _safeAdd(_appointmentController, data);
      });

      _socket!.on('appointment:completed', (data) {
        _safeAdd(_appointmentController, data);
      });

      _socket!.on('emergency:sos', (data) {
        _safeAdd(_emergencyController, data);
      });

      _socket!.on('typing:start', (data) {
        _safeAdd(_typingController, data);
      });

      _socket!.on('typing:stop', (data) {
        _safeAdd(_typingController, data);
      });

      _socket!.connect();
    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
      if (kDebugMode) debugPrint('Socket connection error: $e');
    } finally {
      _connecting = false;
    }
  }

  void joinChat(String chatId) {
    _socket?.emit('join:chat', chatId);
  }

  void leaveChat(String chatId) {
    _socket?.emit('leave:chat', chatId);
  }

  void emitTypingStart(String chatId) {
    _socket?.emit('typing:start', {'chatId': chatId});
  }

  void emitTypingStop(String chatId) {
    _socket?.emit('typing:stop', {'chatId': chatId});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
    _connectionController.add(false);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    disconnect();
    _messageController.close();
    _notificationController.close();
    _appointmentController.close();
    _emergencyController.close();
    _typingController.close();
    _connectionController.close();
  }
}
