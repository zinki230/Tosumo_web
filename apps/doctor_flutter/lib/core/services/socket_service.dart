import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';
import '../network/doctor_api_endpoints.dart';
import 'token_storage_service.dart';

class SocketService {
  io.Socket? _socket;
  final TokenStorageService _tokenStorage;
  bool _isConnected = false;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  final _appointmentController = StreamController<Map<String, dynamic>>.broadcast();
  final _emergencyController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _chatReadController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onNotification => _notificationController.stream;
  Stream<Map<String, dynamic>> get onAppointment => _appointmentController.stream;
  Stream<Map<String, dynamic>> get onEmergency => _emergencyController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onChatRead => _chatReadController.stream;
  Stream<bool> get onConnectionChange => _connectionController.stream;
  bool get isConnected => _isConnected;

  SocketService(this._tokenStorage);

  Future<void> connect() async {
    if (_socket != null) return;

    final token = await _tokenStorage.getToken();
    if (token == null) return;

    try {
      final uri = DoctorApiEndpoints.baseUrl.replaceFirst('https', 'wss').replaceFirst('http', 'ws');
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
        if (kDebugMode) debugPrint('Socket connect error: $data');
      });

      _socket!.on('message:new', (data) {
        _messageController.add(data as Map<String, dynamic>);
      });

      _socket!.on('notification:new', (data) {
        _notificationController.add(data as Map<String, dynamic>);
      });

      _socket!.on('notification:updated', (data) {
        _notificationController.add(data as Map<String, dynamic>);
      });

      _socket!.on('appointment:new', (data) {
        _appointmentController.add(data as Map<String, dynamic>);
      });

      _socket!.on('appointment:updated', (data) {
        _appointmentController.add(data as Map<String, dynamic>);
      });

      _socket!.on('appointment:cancelled', (data) {
        _appointmentController.add(data as Map<String, dynamic>);
      });

      _socket!.on('appointment:completed', (data) {
        _appointmentController.add(data as Map<String, dynamic>);
      });

      _socket!.on('appointment:rescheduled', (data) {
        _appointmentController.add(data as Map<String, dynamic>);
      });

      _socket!.on('emergency:new-session', (data) {
        _emergencyController.add(data as Map<String, dynamic>);
      });

      _socket!.on('emergency:session-updated', (data) {
        _emergencyController.add(data as Map<String, dynamic>);
      });

      _socket!.on('emergency:contact-alert', (data) {
        _emergencyController.add(data as Map<String, dynamic>);
      });

      _socket!.on('chat:read', (data) {
        _chatReadController.add(data as Map<String, dynamic>);
      });

      _socket!.on('typing:start', (data) {
        _typingController.add(data as Map<String, dynamic>);
      });

      _socket!.on('typing:stop', (data) {
        _typingController.add(data as Map<String, dynamic>);
      });

      _socket!.connect();
    } catch (e) {
      if (kDebugMode) debugPrint('Socket connection error: $e');
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
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _notificationController.close();
    _appointmentController.close();
    _emergencyController.close();
    _typingController.close();
    _chatReadController.close();
    _connectionController.close();
  }
}
