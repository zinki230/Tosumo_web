import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../network/api_providers.dart';
import '../../shared/models/notification_model.dart';

enum NotificationCategory {
  appointment,
  medication,
  emergency,
  cardUpdate,
  accessRequest,
  labResult,
  message,
  system,
}

class NotificationService {
  final ApiClient _client;
  final StreamController<NotificationModel> _pushController = StreamController<NotificationModel>.broadcast();

  Stream<NotificationModel> get onPushNotification => _pushController.stream;

  NotificationService(this._client);

  Future<List<NotificationModel>> getNotifications(String patientId) async {
    final response = await _client.get(ApiEndpoints.notifications);
    return (response.data as List)
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<NotificationModel>> getUnreadNotifications(String patientId) async {
    final response = await _client.get(ApiEndpoints.notificationUnread);
    return (response.data as List)
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAsRead(String notificationId) async {
    await _client.put(ApiEndpoints.notificationRead(notificationId));
  }

  Future<void> markAllAsRead() async {
    await _client.put(ApiEndpoints.notificationReadAll);
  }

  void handlePushPayload(Map<String, dynamic> payload) {
    final notification = NotificationModel(
      id: payload['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: payload['type'] as String? ?? 'system',
      title: payload['title'] as String? ?? '',
      message: payload['message'] as String? ?? '',
      time: payload['time'] as String? ?? DateTime.now().toIso8601String(),
      read: false,
    );
    _pushController.add(notification);
  }

  void dispose() {
    _pushController.close();
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(ref.read(apiClientProvider));
  ref.onDispose(() => service.dispose());
  return service;
});
