import 'package:freezed_annotation/freezed_annotation.dart';
import 'message_metadata.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

@freezed
sealed class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    required String conversationId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String text,
    @Default('text') String type,
    MessageMetadata? metadata,
    @Default('sent') String status,
    required DateTime timestamp,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
}
