import '../models/notification_item.dart';

abstract class NotificationRepository {
  Future<List<NotificationItem>> getNotifications(String doctorId);
  Future<List<NotificationItem>> getUnreadNotifications(String doctorId);
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
}
