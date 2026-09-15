import 'package:freezed_annotation/freezed_annotation.dart';

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
    required String lastMessageDate,
    @Default(0) int unread,
    @Default(false) bool online,
    @Default([]) List<ChatMessage> messages,
  }) = _ChatConversation;

  factory ChatConversation.fromJson(Map<String, dynamic> json) =>
      _$ChatConversationFromJson(json);
}

@freezed
sealed class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    required String senderId,
    required String senderName,
    required String text,
    required String timestamp,
    @Default('text') String type,
    MessageMetadata? metadata,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
}

@freezed
sealed class MessageMetadata with _$MessageMetadata {
  const factory MessageMetadata({
    String? attachmentUrl,
    String? duration,
    String? fileName,
    String? fileSize,
    String? prescriptionName,
    String? labType,
  }) = _MessageMetadata;

  factory MessageMetadata.fromJson(Map<String, dynamic> json) =>
      _$MessageMetadataFromJson(json);
}
