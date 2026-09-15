import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../domain/models/chat_conversation.dart';
import '../../../domain/models/chat_message.dart';

class ChatState {
  final List<ChatConversation> conversations;
  final ChatConversation? selectedConversation;
  final List<ChatMessage> currentMessages;
  final bool loading;
  final bool sending;
  final String? error;
  final int currentPage;

  const ChatState({
    this.conversations = const [],
    this.selectedConversation,
    this.currentMessages = const [],
    this.loading = false,
    this.sending = false,
    this.error,
    this.currentPage = 0,
  });

  ChatState copyWith({
    List<ChatConversation>? conversations,
    ChatConversation? selectedConversation,
    List<ChatMessage>? currentMessages,
    bool? loading,
    bool? sending,
    String? error,
    int? currentPage,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      selectedConversation: selectedConversation ?? this.selectedConversation,
      currentMessages: currentMessages ?? this.currentMessages,
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      error: error,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);

class ChatNotifier extends Notifier<ChatState> {
  String get _doctorId => ref.read(currentDoctorIdProvider) ?? '';

  @override
  ChatState build() => const ChatState();

  Future<void> loadConversations() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final repo = ref.read(chatRepositoryProvider);
      final conversations = await repo.getConversations(_doctorId);
      state = state.copyWith(conversations: conversations, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  int get unreadCount {
    return state.conversations.fold(0, (sum, c) => sum + c.unread);
  }

  Future<void> selectConversation(ChatConversation conversation) async {
    state = state.copyWith(selectedConversation: conversation, currentMessages: [], currentPage: 0);
    try {
      final repo = ref.read(chatRepositoryProvider);
      final messages = await repo.getMessages(conversation.id);
      state = state.copyWith(currentMessages: messages);
      if (conversation.unread > 0) {
        await repo.markChatRead(conversation.id);
        await loadConversations();
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> loadMoreMessages() async {
    final conv = state.selectedConversation;
    if (conv == null) return;
    final nextPage = state.currentPage + 1;
    try {
      final repo = ref.read(chatRepositoryProvider);
      final messages = await repo.getMessages(conv.id, page: nextPage, limit: 20);
      state = state.copyWith(
        currentMessages: [...state.currentMessages, ...messages],
        currentPage: nextPage,
      );
    } catch (_) {}
  }

  Future<void> sendMessage(String text, {String? type, Map<String, dynamic>? metadata}) async {
    final conv = state.selectedConversation;
    if (conv == null || text.isEmpty) return;
    state = state.copyWith(sending: true);
    try {
      final repo = ref.read(chatRepositoryProvider);
      final message = await repo.sendMessage(conv.id, text, type: type, metadata: metadata);
      state = state.copyWith(
        currentMessages: [...state.currentMessages, message],
        sending: false,
      );
      await loadConversations();
    } catch (e) {
      state = state.copyWith(sending: false, error: e.toString());
    }
  }

  void clearSelection() {
    state = state.copyWith(selectedConversation: null, currentMessages: []);
  }
}

final chatConversationsProvider = FutureProvider<List<ChatConversation>>((ref) async {
  final doctorId = ref.read(currentDoctorIdProvider) ?? '';
  return ref.read(chatRepositoryProvider).getConversations(doctorId);
});

final chatMessagesProvider = FutureProvider.family<List<ChatMessage>, String>((ref, conversationId) async {
  return ref.read(chatRepositoryProvider).getMessages(conversationId);
});