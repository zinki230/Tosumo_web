import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_metadata.freezed.dart';
part 'message_metadata.g.dart';

@freezed
sealed class MessageMetadata with _$MessageMetadata {
  const factory MessageMetadata({
    @Default('') String fileName,
    @Default(0) int fileSize,
    @Default(0) int duration,
    @Default('') String mimeType,
    @Default('') String thumbnailUrl,
  }) = _MessageMetadata;

  factory MessageMetadata.fromJson(Map<String, dynamic> json) =>
      _$MessageMetadataFromJson(json);
}
