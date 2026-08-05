import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/screen_neutrals.dart';
import '../../../core/theme/visual_style_provider.dart';
import '../domain/chat_message.dart';
import 'ai_chat_notifier.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(aiChatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiChatProvider);
    final style = ref.watch(visualStyleProvider);
    final n = neutralsFor(style);

    ref.listen(aiChatProvider, (_, next) {
      if (!next.isLoading) _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: n.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Trợ lý AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('DeepSeek · Tài chính thông minh',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
              ],
            ),
          ],
        ),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        actions: [
          if (state.messages.isNotEmpty)
            IconButton(
              tooltip: 'Xóa lịch sử',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClear(context, ref),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.messages.isEmpty
                ? _WelcomeView(onSuggestionTap: (s) {
                    _controller.text = s;
                    _send();
                  }, n: n)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: state.messages.length + (state.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.messages.length) {
                        return const _TypingIndicator();
                      }
                      final msg = state.messages[index];
                      return _MessageBubble(message: msg, n: n);
                    },
                  ),
          ),
          _InputBar(
            controller: _controller,
            focusNode: _focusNode,
            isLoading: state.isLoading,
            onSend: _send,
            n: n,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa hội thoại?'),
        content: const Text('Toàn bộ lịch sử chat sẽ bị xóa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(aiChatProvider.notifier).clearHistory();
  }
}

// ---------------------------------------------------------------------------
// Welcome / empty state
// ---------------------------------------------------------------------------

class _WelcomeView extends StatelessWidget {
  final ValueChanged<String> onSuggestionTap;
  final ScreenNeutrals n;

  const _WelcomeView({required this.onSuggestionTap, required this.n});

  static const _suggestions = [
    'Làm sao quản lý dòng tiền hiệu quả?',
    'Túi tiền nên chia như thế nào?',
    'Tôi nên theo dõi những khoản chi nào?',
    'Công nợ phải thu là gì?',
    'Cách lập ngân sách cho shop nhỏ?',
    'Giải thích tính năng báo cáo của app',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: const Icon(Icons.auto_awesome, size: 36, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            'Trợ lý Tài chính AI',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: n.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Hỏi bất cứ điều gì về quản lý tài chính,\ntính năng app, hoặc tư vấn thu chi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: n.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _suggestions
                .map((s) => _SuggestionChip(text: s, onTap: () => onSuggestionTap(s), n: n))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final ScreenNeutrals n;

  const _SuggestionChip({required this.text, required this.onTap, required this.n});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: n.textPrimary),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message bubble
// ---------------------------------------------------------------------------

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final ScreenNeutrals n;

  const _MessageBubble({required this.message, required this.n});

  bool get _isUser => message.role == ChatRole.user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 8,
        left: _isUser ? 48 : 0,
        right: _isUser ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment: _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!_isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _copyToClipboard(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _isUser
                      ? const Color(0xFF6C63FF)
                      : message.isError
                          ? AppColors.error.withValues(alpha: 0.1)
                          : n.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(_isUser ? 16 : 4),
                    bottomRight: Radius.circular(_isUser ? 4 : 16),
                  ),
                  border: !_isUser
                      ? Border.all(
                          color: message.isError
                              ? AppColors.error.withValues(alpha: 0.3)
                              : n.divider,
                          width: 0.5,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.isError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 14, color: AppColors.error),
                            const SizedBox(width: 4),
                            Text('Lỗi', style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    _FormattedText(
                      text: message.content,
                      color: _isUser
                          ? Colors.white
                          : message.isError
                              ? AppColors.error
                              : n.textPrimary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('HH:mm').format(message.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: _isUser
                            ? Colors.white.withValues(alpha: 0.7)
                            : n.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép'), duration: Duration(seconds: 1)),
    );
  }
}

// ---------------------------------------------------------------------------
// Simple markdown-lite formatter (bold, bullets, code inline)
// ---------------------------------------------------------------------------

class _FormattedText extends StatelessWidget {
  final String text;
  final Color color;

  const _FormattedText({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      _parseMarkdown(text, color),
      style: TextStyle(color: color, fontSize: 14, height: 1.5),
    );
  }

  TextSpan _parseMarkdown(String raw, Color baseColor) {
    final spans = <InlineSpan>[];
    // Normalize line endings
    final lines = raw.replaceAll('\r\n', '\n').split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (i > 0) spans.add(const TextSpan(text: '\n'));

      if (line.startsWith('• ') || line.startsWith('- ') || line.startsWith('* ')) {
        spans.add(TextSpan(text: '• ', style: TextStyle(color: baseColor)));
        _parseInline(line.substring(2), baseColor, spans);
      } else if (RegExp(r'^\d+\. ').hasMatch(line)) {
        final match = RegExp(r'^(\d+\. )(.*)').firstMatch(line);
        if (match != null) {
          spans.add(TextSpan(text: match.group(1), style: TextStyle(color: baseColor)));
          _parseInline(match.group(2) ?? '', baseColor, spans);
        }
      } else if (line.startsWith('### ') || line.startsWith('## ') || line.startsWith('# ')) {
        final content = line.replaceFirst(RegExp(r'^#{1,3} '), '');
        spans.add(TextSpan(
          text: content,
          style: TextStyle(color: baseColor, fontWeight: FontWeight.bold, fontSize: 15),
        ));
      } else {
        _parseInline(line, baseColor, spans);
      }
    }
    return TextSpan(children: spans);
  }

  void _parseInline(String line, Color baseColor, List<InlineSpan> spans) {
    // Handle **bold** and `code`
    final pattern = RegExp(r'\*\*(.+?)\*\*|`(.+?)`');
    int last = 0;
    for (final match in pattern.allMatches(line)) {
      if (match.start > last) {
        spans.add(TextSpan(text: line.substring(last, match.start), style: TextStyle(color: baseColor)));
      }
      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(color: baseColor, fontWeight: FontWeight.bold),
        ));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(2),
          style: TextStyle(
            color: baseColor,
            fontFamily: 'monospace',
            backgroundColor: baseColor.withValues(alpha: 0.1),
          ),
        ));
      }
      last = match.end;
    }
    if (last < line.length) {
      spans.add(TextSpan(text: line.substring(last), style: TextStyle(color: baseColor)));
    }
  }
}

// ---------------------------------------------------------------------------
// Typing indicator (3 animated dots)
// ---------------------------------------------------------------------------

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
        ..repeat(reverse: true, period: Duration(milliseconds: 600 + i * 150));
    });
    _animations = _controllers
        .map((c) => Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();
    Future.delayed(const Duration(milliseconds: 0), () {
      for (var i = 0; i < _controllers.length; i++) {
        Future.delayed(Duration(milliseconds: i * 150), () {
          if (mounted) _controllers[i].repeat(reverse: true);
        });
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 48),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _animations[i],
                  builder: (_, __) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 6,
                    height: 6 + _animations[i].value * 4,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        const Color(0xFF6C63FF).withValues(alpha: 0.4),
                        const Color(0xFF6C63FF),
                        _animations[i].value,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input bar
// ---------------------------------------------------------------------------

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSend;
  final ScreenNeutrals n;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSend,
    required this.n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: n.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: n.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: n.divider),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                style: TextStyle(color: n.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Hỏi về tài chính, thu chi...',
                  hintStyle: TextStyle(color: n.textSecondary, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: isLoading
                  ? const LinearGradient(colors: [Colors.grey, Colors.grey])
                  : const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: onSend,
                    padding: EdgeInsets.zero,
                  ),
          ),
        ],
      ),
    );
  }
}
