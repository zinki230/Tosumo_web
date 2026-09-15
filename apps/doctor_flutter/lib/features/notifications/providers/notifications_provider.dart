import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../domain/models/notification_item.dart';

class NotificationsState {
  final List<NotificationItem> notifications;
  final String filter;
  final bool loading;
  final String? error;

  const NotificationsState({
    this.notifications = const [],
    this.filter = 'All',
    this.loading = false,
    this.error,
  });

  NotificationsState copyWith({
    List<NotificationItem>? notifications,
    String? filter,
    bool? loading,
    String? error,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      filter: filter ?? this.filter,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  List<NotificationItem> get filteredNotifications {
    var list = List<NotificationItem>.from(notifications);
    if (filter == 'Unread') return list.where((n) => !n.read).toList();
    if (filter != 'All') return list.where((n) => n.type == filter.toLowerCase()).toList();
    return list;
  }

  int get unreadCount => notifications.where((n) => !n.read).length;
}

final notificationsProvider = NotifierProvider<NotificationsNotifier, NotificationsState>(NotificationsNotifier.new);

class NotificationsNotifier extends Notifier<NotificationsState> {
  String get _doctorId => ref.read(currentDoctorIdProvider) ?? '';

  @override
  NotificationsState build() => const NotificationsState();

  Future<void> loadNotifications() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final repo = ref.read(notificationRepositoryProvider);
      final notifications = await repo.getNotifications(_doctorId);
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = state.copyWith(notifications: notifications, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setFilter(String filter) {
    state = state.copyWith(filter: filter);
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await ref.read(notificationRepositoryProvider).markAsRead(notificationId);
      await loadNotifications();
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await ref.read(notificationRepositoryProvider).markAllAsRead();
      await loadNotifications();
    } catch (_) {}
  }

  Future<void> refresh() async {
    await loadNotifications();
  }
}

final unreadNotificationsProvider = Provider<int>((ref) {
  final state = ref.watch(notificationsProvider);
  return state.unreadCount;
});
