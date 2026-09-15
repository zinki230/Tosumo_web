import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/data/response_mapper.dart';
import '../../../core/providers/patient_provider.dart';
import '../../../core/network/socket_provider.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/localization.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/models/chat_conversation.dart';
import '../../../shared/widgets/app_back_button.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  final String chatId;
  const ChatThreadScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  StreamSubscription<Map<String, dynamic>>? _messageSub;
  StreamSubscription<Map<String, dynamic>>? _typingSub;
  bool _isTyping = false;
  bool _sending = false;
  SocketService? _socket;

  @override
  void initState() {
    super.initState();
    _initThread();
  }

  Future<void> _initThread() async {
    final socket = _socket ?? ref.read(socketServiceProvider);
    _socket = socket;
    if (socket == null) return;
    socket.joinChat(widget.chatId);
    ref.read(patientProvider.notifier).markChatAsRead(widget.chatId);

    _messageSub = socket.onMessage.listen((data) {
      final msg = ResponseMapper.messageFromBackend(data);
      if (msg.id.isNotEmpty) {
        _appendMessage(msg);
      }
    });

    _typingSub = socket.onTyping.listen((data) {
      final chatId = data['chatId']?.toString() ?? '';
      if (chatId != widget.chatId) return;
      final typing = data.keys.any((k) => k == 'typing' && data['typing'] == true) ||
          data['type'] == 'typing:start';
      setState(() => _isTyping = typing);
    });

    await ref.read(patientProvider.notifier).refreshChat(widget.chatId);
    _scrollToBottom();
  }

  void _appendMessage(ChatMessage msg) {
    if (!mounted) return;
    ref.read(patientProvider.notifier).appendIncomingMessage(widget.chatId, msg);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;
    _inputController.clear();
    setState(() => _sending = true);
    try {
      await ref.read(patientProvider.notifier).sendChatMessage(widget.chatId, text);
      if (!mounted) return;
      setState(() => _sending = false);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de l\'envoi : $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _typingSub?.cancel();
    _socket?.leaveChat(widget.chatId);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _emitTyping(bool typing) {
    final socket = ref.read(socketServiceProvider);
    if (typing) {
      socket.emitTypingStart(widget.chatId);
    } else {
      socket.emitTypingStop(widget.chatId);
    }
  }

  ChatConversation? _findChat(List<ChatConversation> chats) {
    try {
      return chats.firstWhere((c) => c.id == widget.chatId);
    } catch (_) {
      return null;
    }
  }

  String _formatTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;
    final patientState = ref.watch(patientProvider);
    final currentUserId = ref.watch(authProvider).patient?.id ?? '';
    final chat = _findChat(patientState.chats);
    final messages = chat?.messages ?? [];
    final name = chat?.participantName ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.foreground)),
            const SizedBox(height: 2),
            Text(
              (chat?.online ?? false) ? (t?.t('chat.online') ?? '') : (t?.t('chat.offline') ?? ''),
              style: TextStyle(fontSize: 11, color: (chat?.online ?? false) ? const Color(0xFF22C55E) : AppColors.mutedForeground),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: chat == null
              ? Center(child: Text(t?.t('chat.notFound') ?? ''))
              : ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    ...messages.map((msg) => _MessageBubble(
                      text: msg.text,
                      isMe: msg.senderId == currentUserId,
                      time: _formatTime(msg.timestamp),
                    )),
                    if (_isTyping)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _bouncingDot(0),
                                  const SizedBox(width: 4),
                                  _bouncingDot(150),
                                  const SizedBox(width: 4),
                                  _bouncingDot(300),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(icon: const Icon(LucideIcons.paperclip, size: 20), color: AppColors.mutedForeground, onPressed: () {}),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      onChanged: (_) => _emitTyping(true),
                      onSubmitted: (_) => _handleSend(),
                      decoration: InputDecoration(
                        hintText: (t?.t('chat.placeholder') ?? '').replaceAll('{{name}}', name),
                        filled: true,
                        fillColor: AppColors.muted,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _handleSend,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: _sending ? AppColors.primary.withAlpha(128) : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                            )
                          : const Icon(LucideIcons.send, size: 20, color: AppColors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bouncingDot(int delayMs) {
    return _BouncingDot(delayMs: delayMs);
  }
}

class _BouncingDot extends StatefulWidget {
  final int delayMs;
  const _BouncingDot({required this.delayMs});

  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_controller.value * 6),
          child: Opacity(
            opacity: 1.0 - _controller.value * 0.3,
            child: Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            ),
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;

  const _MessageBubble({required this.text, required this.isMe, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: AppColors.primary.withAlpha(25), shape: BoxShape.circle),
              child: const Icon(LucideIcons.user, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : AppColors.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(fontSize: 14, color: isMe ? AppColors.white : AppColors.foreground),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(time, style: TextStyle(fontSize: 10, color: isMe ? AppColors.white.withAlpha(153) : AppColors.mutedForeground)),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        const Icon(LucideIcons.checkCheck, size: 12, color: Color(0xFF4ADE80)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}