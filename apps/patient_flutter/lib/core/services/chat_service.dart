import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../network/api_providers.dart';
import '../../shared/models/chat_conversation.dart';

enum MessageStatus { sending, sent, delivered, read, failed }

class MessageDeliveryInfo {
  final String messageId;
  final MessageStatus status;
  final DateTime timestamp;

  MessageDeliveryInfo({
    required this.messageId,
    required this.status,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatService {
  final ApiClient _client;
  final StreamController<ChatMessage> _messageController = StreamController<ChatMessage>.broadcast();
  final StreamController<MessageDeliveryInfo> _deliveryController = StreamController<MessageDeliveryInfo>.broadcast();
  StreamSubscription? _socketSubscription;

  Stream<ChatMessage> get onMessage => _messageController.stream;
  Stream<MessageDeliveryInfo> get onDeliveryUpdate => _deliveryController.stream;

  ChatService(this._client);

  Future<List<ChatConversation>> getConversations(String patientId) async {
    final response = await _client.get(ApiEndpoints.chat);
    return (response.data as List)
        .map((e) => ChatConversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChatConversation?> getConversation(String chatId) async {
    final response = await _client.get(ApiEndpoints.chatById(chatId));
    return ChatConversation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ChatMessage>> getMessages(String chatId, {int page = 1, int limit = 50}) async {
    final response = await _client.get(
      ApiEndpoints.chatMessages(chatId),
      queryParameters: {'page': page, 'limit': limit},
    );
    return (response.data as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> sendMessage({
    required String chatId,
    required String text,
    String type = 'text',
  }) async {
    final response = await _client.post(ApiEndpoints.chatMessages(chatId), data: {
      'text': text,
      'type': type,
    });
    return ChatMessage.fromJson(response.data as Map<String, dynamic>);
  }

  void connectToSocket(String chatId) {
    // Socket connection placeholder for WebSocket implementation
  }

  void disconnectFromSocket() {
    _socketSubscription?.cancel();
  }

  void dispose() {
    _messageController.close();
    _deliveryController.close();
    _socketSubscription?.cancel();
  }
}

final chatServiceProvider = Provider<ChatService>((ref) {
  final service = ChatService(ref.read(apiClientProvider));
  ref.onDispose(() => service.dispose());
  return service;
});
