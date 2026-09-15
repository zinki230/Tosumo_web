import '../models/chat_message.dart';
import '../models/chat_conversation.dart';

abstract class ChatRepository {
  Future<List<ChatConversation>> getConversations(String doctorId);
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int? page,
    int? limit,
  });
  Future<ChatMessage> sendMessage(
    String conversationId,
    String text, {
    String? type,
    Map<String, dynamic>? metadata,
  });
  Future<void> markChatRead(String conversationId);
  Future<void> markMessageDelivered(String messageId);
}
