import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/notification_item.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/error_mapper.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/app_card.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String get _doctorId => ref.read(currentDoctorIdProvider) ?? '';
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Unread', 'Appointment', 'Lab', 'Emergency'];

  List<NotificationItem> _notifications = [];
  bool _loadingNotifications = true;
  String? _notificationsError;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _loadingNotifications = true);
    try {
      final notifications = await ref.read(notificationRepositoryProvider).getNotifications(_doctorId);
      if (mounted) setState(() { _notifications = notifications; _loadingNotifications = false; _notificationsError = null; });
    } catch (e) {
      if (mounted) setState(() { _notificationsError = ErrorMapper.fromException(e).message; _loadingNotifications = false; });
    }
  }

  Future<void> _refresh() async => _loadNotifications();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: 'Notifications',
                subtitle: 'Restez informé',
                showBack: false,
                showNotification: false,
                rightAction: _buildRightAction(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                child: SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isSelected = _selectedFilter == filter;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFilter = filter),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : AppColors.card,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.border,
                            ),
                          ),
                          child: Text(
                            _filterLabel(filter),
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500,
                              color: isSelected ? AppColors.white : AppColors.mutedForeground,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (_loadingNotifications)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                  child: const ListSkeleton(count: 5),
                ),
              )
            else if (_notificationsError != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: LucideIcons.alertCircle,
                  message: 'Erreur de chargement',
                  actionLabel: 'Réessayer',
                  onAction: _refresh,
                ),
              )
            else
              _buildNotificationsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRightAction() {
    if (_loadingNotifications || _notificationsError != null) return const SizedBox.shrink();
    final hasUnread = _notifications.any((n) => !n.read);
    if (!hasUnread) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () async {
        await ref.read(notificationRepositoryProvider).markAllAsRead();
        _refresh();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: const Text(
          'Tout marquer lu',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildNotificationsList() {
    var notifications = List<NotificationItem>.from(_notifications);
    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (_selectedFilter == 'Unread') {
      notifications = notifications.where((n) => !n.read).toList();
    } else if (_selectedFilter == 'Appointment') {
      notifications = notifications.where((n) => n.type == 'appointment').toList();
    } else if (_selectedFilter == 'Lab') {
      notifications = notifications.where((n) => n.type == 'lab').toList();
    } else if (_selectedFilter == 'Emergency') {
      notifications = notifications.where((n) => n.type == 'emergency').toList();
    }

    if (notifications.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: LucideIcons.bellOff,
          message: 'Aucune notification',
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final notification = notifications[index];
          return _NotificationCard(
            notification: notification,
            onTap: () => _handleNotificationTap(notification),
            onDismiss: () async {
              if (!notification.read) {
                await ref.read(notificationRepositoryProvider).markAsRead(notification.id);
                _refresh();
              }
            },
          );
        },
        childCount: notifications.length,
      ),
    );
  }

  void _handleNotificationTap(NotificationItem notification) async {
    final ref = this.ref;
    if (!notification.read) {
      await ref.read(notificationRepositoryProvider).markAsRead(notification.id);
      _refresh();
    }
    if (!mounted) return;
    switch (notification.type) {
      case 'appointment':
        context.push('/appointments');
      case 'lab':
        context.push('/lab-requests');
      case 'emergency':
        context.push('/emergency');
      case 'message':
        context.push('/chat');
      default:
        break;
    }
  }

  String _filterLabel(String filter) {
    switch (filter) {
      case 'All': return 'Toutes';
      case 'Unread': return 'Non lues';
      case 'Appointment': return 'Rendez-vous';
      case 'Lab': return 'Laboratoire';
      case 'Emergency': return 'Urgences';
      default: return filter;
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppColors.primaryLight,
        child: const Icon(LucideIcons.checkCheck, color: AppColors.primary),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal, vertical: 3),
        child: AppCard(
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _iconColor(notification.type).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(_iconForType(notification.type), size: 20, color: _iconColor(notification.type)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: notification.read ? AppColors.mutedForeground : AppColors.foreground,
                            ),
                          ),
                        ),
                        Text(
                          _timeAgo(notification.createdAt),
                          style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: notification.read ? AppColors.mutedForeground : AppColors.foreground,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!notification.read)
                Container(
                  margin: const EdgeInsets.only(top: 8, left: 8),
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'appointment': return LucideIcons.calendar;
      case 'lab': return LucideIcons.beaker;
      case 'emergency': return LucideIcons.ambulance;
      case 'message': return LucideIcons.mail;
      default: return LucideIcons.bell;
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'appointment': return AppColors.primary;
      case 'lab': return AppColors.success;
      case 'emergency': return AppColors.destructive;
      case 'message': return AppColors.accent;
      default: return AppColors.mutedForeground;
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'maintenant';
    if (diff.inHours < 1) return '${diff.inMinutes}min';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}j';
    return DateFormat('dd/MM').format(date);
  }
}
