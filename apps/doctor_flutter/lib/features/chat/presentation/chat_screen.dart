import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/chat_conversation.dart';
import '../../../domain/models/chat_message.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/network/doctor_api_endpoints.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/error_mapper.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/avatar.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  String get _doctorId => ref.read(currentDoctorIdProvider) ?? '';
  ChatConversation? _selectedConversation;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;

  List<ChatConversation> _conversations = [];
  List<ChatMessage> _messages = [];
  bool _loadingConversations = true;
  bool _loadingMessages = false;
  String? _conversationsError;
  String? _messagesError;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  String? _joinedChatId;
  late final SocketService _socket;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(socketServiceProvider);
    _socket.connect().then((_) {
      final selected = _selectedConversation;
      if (selected != null) _socket.joinChat(selected.id);
    });
    _messageSubscription = _socket.onMessage.listen((data) {
      if (!mounted || data['chatId']?.toString() != _joinedChatId) return;
      final id = _joinedChatId;
      if (id != null) {
        _loadMessages(id);
        _loadConversations();
      }
    });
    _loadConversations();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    if (_joinedChatId != null) _socket.leaveChat(_joinedChatId!);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() => _loadingConversations = true);
    try {
      final conversations = await ref.read(chatRepositoryProvider).getConversations(_doctorId);
      if (mounted) setState(() { _conversations = conversations; _loadingConversations = false; _conversationsError = null; });
    } catch (e) {
      if (mounted) setState(() { _conversationsError = ErrorMapper.fromException(e).message; _loadingConversations = false; });
    }
  }

  Future<void> _loadMessages(String conversationId) async {
    setState(() => _loadingMessages = true);
    try {
      final messages = await ref.read(chatRepositoryProvider).getMessages(conversationId);
      if (mounted) setState(() { _messages = messages; _loadingMessages = false; _messagesError = null; });
    } catch (e) {
      if (mounted) setState(() { _messagesError = ErrorMapper.fromException(e).message; _loadingMessages = false; });
    }
  }

  Future<void> _refresh() async {
    await _loadConversations();
    if (_selectedConversation != null) {
      await _loadMessages(_selectedConversation!.id);
    }
  }

  void _selectConversation(ChatConversation conv) {
    if (_joinedChatId != null) _socket.leaveChat(_joinedChatId!);
    setState(() => _selectedConversation = conv);
    _joinedChatId = conv.id;
    _socket.joinChat(conv.id);
    _loadMessages(conv.id);
    if (conv.unread > 0) {
      ref.read(chatRepositoryProvider).markChatRead(conv.id);
    }
  }

  Future<void> _pickAttachment() async {
    final conv = _selectedConversation;
    if (conv == null) return;
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif', 'pdf', 'doc', 'docx', 'txt', 'csv']);
    final file = picked?.files.single;
    final path = file?.path;
    if (file == null || path == null) return;
    try {
      final url = await ref.read(remoteDoctorRepoProvider).uploadFile(path);
      if (url == null || url.isEmpty) throw Exception('Le fichier n’a pas pu être téléversé.');
      final ext = file.extension?.toLowerCase() ?? '';
      final mime = const {'jpg':'image/jpeg','jpeg':'image/jpeg','png':'image/png','webp':'image/webp','gif':'image/gif','pdf':'application/pdf','doc':'application/msword','docx':'application/vnd.openxmlformats-officedocument.wordprocessingml.document','txt':'text/plain','csv':'text/csv'}[ext] ?? 'application/octet-stream';
      await ref.read(chatRepositoryProvider).sendMessage(conv.id, '', type: mime.startsWith('image/') ? 'image' : 'document', metadata: {'attachmentUrl': url, 'fileName': file.name, 'fileSize': file.size, 'mimeType': mime});
      await _loadMessages(conv.id);
      await _loadConversations();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec de l’envoi du fichier : ${ErrorMapper.fromException(e).message}')));
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _selectedConversation == null) return;
    _messageController.clear();
    try {
      await ref.read(chatRepositoryProvider).sendMessage(
        _selectedConversation!.id,
        text,
      );
      await _loadMessages(_selectedConversation!.id);
      await _loadConversations();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMapper.fromException(e).message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedConversation != null) {
      return _buildChatThread();
    }

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
                title: 'Messagerie',
                subtitle: 'Communications sécurisées',
                showBack: false,
                showNotification: true,
              ),
            ),
            if (_loadingConversations)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                child: Column(
                  children: [
                    ListSkeleton(count: 5),
                  ],
                ),
              ))
            else if (_conversationsError != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: LucideIcons.alertCircle,
                  message: 'Erreur de chargement',
                  actionLabel: 'Réessayer',
                  onAction: _refresh,
                ),
              )
            else if (_conversations.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: LucideIcons.messageSquare,
                  message: 'Aucune conversation',
                ),
              )
            else ...[
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final sorted = List<ChatConversation>.from(_conversations)
                      ..sort((a, b) => b.lastMessageDate.compareTo(a.lastMessageDate));
                    final conv = sorted[index];
                    return _ConversationTile(
                      conversation: conv,
                      onTap: () => _selectConversation(conv),
                    );
                  },
                  childCount: _conversations.length,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatThread() {
    final conv = _selectedConversation!;
    final colors = [
      AppColors.primary, AppColors.success, AppColors.accent,
      AppColors.alert, AppColors.destructive, AppColors.gold,
    ];
    final colorIndex = conv.participantName.hashCode % colors.length;
    final avatarColor = colors[colorIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => setState(() => _selectedConversation = null),
          color: AppColors.foreground,
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: avatarColor.withValues(alpha: 0.15),
                  child: Text(
                    conv.participantInitials,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: avatarColor),
                  ),
                ),
                if (conv.online)
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      width: 10, height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(BorderSide(color: AppColors.white, width: 2)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conv.participantName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.foreground),
                  ),
                  Text(
                    conv.online ? 'En ligne' : 'Hors ligne',
                    style: TextStyle(
                      fontSize: 11,
                      color: conv.online ? AppColors.success : AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.primary,
              child: _loadingMessages
                  ? const ListSkeleton(count: 3)
                  : _messagesError != null
                      ? const SizedBox.shrink()
                      : _buildMessagesList(conv, avatarColor),
            ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                IconButton(onPressed: _pickAttachment, icon: const Icon(LucideIcons.paperclip), tooltip: 'Joindre une image ou un document'),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _messageController,
                      onChanged: (v) => setState(() => _isTyping = v.isNotEmpty),
                      decoration: InputDecoration(
                        hintText: 'Écrivez un message...',
                        hintStyle: const TextStyle(color: AppColors.mutedForeground),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        suffixIcon: _isTyping
                            ? GestureDetector(
                                onTap: _sendMessage,
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: const Icon(LucideIcons.send, size: 16, color: AppColors.white),
                                ),
                              )
                            : null,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(ChatConversation conv, Color avatarColor) {
    if (_messages.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          EmptyState(
            icon: LucideIcons.messageCircle,
            message: 'Aucun message',
          ),
        ],
      );
    }
    final sorted = List<ChatMessage>.from(_messages)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final msg = sorted[index];
        final isMe = msg.senderRole == 'doctor';
        final showAvatar = !isMe && (index == 0 || sorted[index - 1].senderRole != msg.senderRole);
        final showTimestamp = index == 0 ||
          sorted[index].timestamp.difference(sorted[index - 1].timestamp).inMinutes >= 5;
        return Column(
          children: [
            if (showTimestamp) ...[
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    _formatDate(msg.timestamp),
                    style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Padding(
              padding: EdgeInsets.only(
                left: isMe ? 60 : 0,
                right: isMe ? 0 : 60,
                top: 4,
              ),
              child: Row(
                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isMe && showAvatar)
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: avatarColor.withValues(alpha: 0.15),
                      child: Text(
                        conv.participantInitials,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: avatarColor),
                      ),
                    ),
                  if (!isMe && showAvatar) const SizedBox(width: 8),
                  if (!isMe && !showAvatar) const SizedBox(width: 36),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe ? AppColors.primary : AppColors.card,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(AppRadius.lg),
                          topRight: const Radius.circular(AppRadius.lg),
                          bottomLeft: Radius.circular(isMe ? AppRadius.lg : AppRadius.sm),
                          bottomRight: Radius.circular(isMe ? AppRadius.sm : AppRadius.lg),
                        ),
                        boxShadow: isMe ? null : [BoxShadow(
                          color: AppColors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        )],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (msg.metadata?.fileName.isNotEmpty == true)
                            _DoctorAttachment(message: msg, isMe: isMe)
                          else if (msg.text.isNotEmpty)
                            Text(msg.text, style: TextStyle(fontSize: 14, color: isMe ? AppColors.white : AppColors.foreground)),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('HH:mm').format(msg.timestamp),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe ? AppColors.white.withValues(alpha: 0.7) : AppColors.mutedForeground,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  msg.status == 'read' ? LucideIcons.checkCheck : LucideIcons.check,
                                  size: 12,
                                  color: msg.status == 'read'
                                      ? AppColors.accent
                                      : AppColors.white.withValues(alpha: 0.7),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return DateFormat('HH:mm').format(date);
    }
    return DateFormat('dd/MM HH:mm').format(date);
  }
}

class _ConversationTile extends ConsumerWidget {
  final ChatConversation conversation;
  final VoidCallback onTap;

  const _ConversationTile({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal, vertical: 4),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Avatar(
              initials: conversation.participantInitials,
              size: 48,
              online: conversation.online,
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
                          conversation.participantName,
                          style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.foreground,
                          ),
                        ),
                      ),
                      Text(
                        _timeAgo(conversation.lastMessageDate),
                        style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage,
                          style: TextStyle(
                            fontSize: 13,
                            color: conversation.unread > 0
                                ? AppColors.foreground
                                : AppColors.mutedForeground,
                            fontWeight: conversation.unread > 0 ? FontWeight.w500 : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.destructive,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            '${conversation.unread}',
                            style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

class _DoctorAttachment extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  const _DoctorAttachment({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final metadata = message.metadata?.toJson() ?? <String, dynamic>{};
    final url = metadata['attachmentUrl']?.toString() ?? '';
    final name = metadata['fileName']?.toString() ?? 'Pièce jointe';
    final image = message.type == 'image' || (metadata['mimeType']?.toString().startsWith('image/') ?? false);
    final uri = url.startsWith('http') ? Uri.parse(url) : Uri.parse(DoctorApiEndpoints.baseUrl).resolve('/${url.replaceFirst(RegExp(r'^/'), '')}');
    if (image) {
      return GestureDetector(
        onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(uri.toString(), width: 220, height: 160, fit: BoxFit.cover, errorBuilder: (_, _, _) => _document(uri, name)),
        ),
      );
    }
    return _document(uri, name);
  }

  Widget _document(Uri uri, String name) => InkWell(
    onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(LucideIcons.fileText, color: isMe ? AppColors.white : AppColors.primary),
      const SizedBox(width: 8),
      Flexible(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isMe ? AppColors.white : AppColors.foreground, decoration: TextDecoration.underline))),
      const SizedBox(width: 4),
      Icon(LucideIcons.download, size: 16, color: isMe ? Colors.white70 : AppColors.mutedForeground),
    ]),
  );
}
