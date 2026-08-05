import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/current_workspace_provider.dart';
import '../data/ai_chat_repository.dart';
import '../domain/chat_message.dart';

class AiChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? errorMessage;

  const AiChatState({
    this.messages = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  AiChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AiChatNotifier extends StateNotifier<AiChatState> {
  final AiChatRepository _repository;
  final String _workspaceName;

  AiChatNotifier(this._repository, this._workspaceName) : super(const AiChatState());

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isLoading) return;

    final userMsg = ChatMessage(
      id: 'u_${DateTime.now().microsecondsSinceEpoch}',
      role: ChatRole.user,
      content: trimmed,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      clearError: true,
    );

    try {
      final reply = await _repository.sendMessage(
        history: state.messages,
        userMessage: trimmed,
        workspaceName: _workspaceName,
      );
      final assistantMsg = ChatMessage(
        id: 'a_${DateTime.now().microsecondsSinceEpoch}',
        role: ChatRole.assistant,
        content: reply,
        createdAt: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isLoading: false,
      );
    } catch (e) {
      final errorMsg = ChatMessage(
        id: 'err_${DateTime.now().microsecondsSinceEpoch}',
        role: ChatRole.assistant,
        content: e.toString().replaceFirst('Exception: ', ''),
        createdAt: DateTime.now(),
        isError: true,
      );
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isLoading: false,
        errorMessage: errorMsg.content,
      );
    }
  }

  void clearHistory() {
    state = const AiChatState();
  }
}

final aiChatProvider =
    StateNotifierProvider.autoDispose<AiChatNotifier, AiChatState>((ref) {
  final workspaceState = ref.watch(workspaceNotifierProvider);
  final workspaceName = workspaceState.selected?.name ?? 'Không gian làm việc';
  return AiChatNotifier(ref.watch(aiChatRepositoryProvider), workspaceName);
});
