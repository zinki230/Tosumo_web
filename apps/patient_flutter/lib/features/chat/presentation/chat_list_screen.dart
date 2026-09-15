import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/providers/patient_provider.dart';
import '../../../core/utils/localization.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_animated_mount.dart';
import '../../../shared/widgets/safe_top_spacer.dart';
import '../../../shared/models/chat_conversation.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;
    final state = ref.watch(patientProvider);
    final chats = state.chats;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SafeTopSpacer(extra: 0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t?.t('chat.title') ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(t?.t('chat.subtitle') ?? '', style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
                  ],
                ),
              ),
              Stack(
                children: [
                  const Icon(LucideIcons.bell, size: 20, color: AppColors.mutedForeground),
                  if (state.notifications.any((n) => !n.read))
                    Positioned(
                      top: -1, right: -1,
                      child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.destructive, shape: BoxShape.circle)),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (chats.isEmpty)
            _buildEmptyState(context, t)
          else
            ...chats.map((chat) => _ChatRow(chat: chat, onTap: () => context.push('/patient/chat/${chat.id}'))),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, dynamic t) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(16)),
            child: Icon(LucideIcons.messageCircle, size: 32, color: AppColors.mutedForeground.withAlpha(102)),
          ),
          const SizedBox(height: 16),
          Text(t?.t('chat.noConversations') ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(t?.t('chat.noConversationsDesc') ?? '', style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  final ChatConversation chat;
  final VoidCallback onTap;

  const _ChatRow({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedMount(
      animation: 'fadeInUp',
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: chat.unread > 0 ? AppColors.primary.withAlpha(51) : AppColors.border),
          boxShadow: chat.unread > 0 ? [BoxShadow(color: AppColors.primary.withAlpha(13), blurRadius: 8)] : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            chat.participantInitials,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ),
                      ),
                      if (chat.online)
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: AppColors.card, width: 2)))),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(chat.participantName, style: TextStyle(fontSize: 15, fontWeight: chat.unread > 0 ? FontWeight.w600 : FontWeight.w500)),
                            Text(_formatRelativeTime(chat.lastMessageDate), style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(chat.participantRole, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primary)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                chat.lastMessage,
                                style: TextStyle(fontSize: 13, color: chat.unread > 0 ? AppColors.foreground : AppColors.mutedForeground, fontWeight: chat.unread > 0 ? FontWeight.w500 : FontWeight.normal),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (chat.unread > 0)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.destructive, borderRadius: BorderRadius.circular(10)),
                                child: Text('${chat.unread}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.white)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatRelativeTime(String isoDate) {
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}j';
    return '${diff.inDays ~/ 7}sem';
  }
}
