import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_item.freezed.dart';
part 'notification_item.g.dart';

@freezed
sealed class NotificationItem with _$NotificationItem {
  const factory NotificationItem({
    required String id,
    required String type,
    required String title,
    required String message,
    @Default(<String, dynamic>{}) Map<String, dynamic> data,
    @Default(false) bool read,
    required DateTime createdAt,
  }) = _NotificationItem;

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      _$NotificationItemFromJson(json);
}
