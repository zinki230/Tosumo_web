import 'package:freezed_annotation/freezed_annotation.dart';
import 'chat_message.dart';

part 'chat_conversation.freezed.dart';
part 'chat_conversation.g.dart';

@freezed
sealed class ChatConversation with _$ChatConversation {
  const factory ChatConversation({
    required String id,
    required String participantName,
    required String participantRole,
    required String participantInitials,
    required String lastMessage,
    required DateTime lastMessageDate,
    @Default(0) int unread,
    @Default(false) bool online,
    @Default(<ChatMessage>[]) List<ChatMessage> messages,
  }) = _ChatConversation;

  factory ChatConversation.fromJson(Map<String, dynamic> json) =>
      _$ChatConversationFromJson(json);
}
