enum ChatRole { user, assistant, system }

class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final bool isError;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.isError = false,
  });

  Map<String, dynamic> toApiJson() => {
        'role': role == ChatRole.user ? 'user' : role == ChatRole.assistant ? 'assistant' : 'system',
        'content': content,
      };
}
