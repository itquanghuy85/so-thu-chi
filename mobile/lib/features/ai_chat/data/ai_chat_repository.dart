import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/chat_message.dart';

/// API key được đưa vào qua --dart-define=DEEPSEEK_API_KEY=... khi build.
/// Không commit key thật vào git — thêm dòng này vào .gitignore:
///   lib/core/constants/ai_config.dart  (nếu tách file)
/// hoặc dùng biến môi trường khi build release.
const _kDeepSeekApiKey = String.fromEnvironment(
  'DEEPSEEK_API_KEY',
  defaultValue: 'sk-ba5e92a9187e440c833087e7a3e95f75',
);
const _kApiBase = 'https://api.deepseek.com';
const _kModel = 'deepseek-chat';

/// Giới hạn lịch sử để tiết kiệm token: chỉ gửi N cặp hội thoại gần nhất.
const _kMaxHistoryPairs = 8;

class AiChatRepository {
  late final Dio _dio = Dio(BaseOptions(
    baseUrl: _kApiBase,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    headers: {
      'Authorization': 'Bearer $_kDeepSeekApiKey',
      'Content-Type': 'application/json',
    },
  ));

  /// Gửi tin nhắn và trả về phản hồi của AI. Chỉ gửi [_kMaxHistoryPairs]
  /// cặp hội thoại gần nhất để tiết kiệm token mà vẫn duy trì ngữ cảnh.
  Future<String> sendMessage({
    required List<ChatMessage> history,
    required String userMessage,
    required String workspaceName,
  }) async {
    // Chỉ lấy N*2 message cuối (N cặp user/assistant)
    final trimmedHistory = history.length > _kMaxHistoryPairs * 2
        ? history.sublist(history.length - _kMaxHistoryPairs * 2)
        : history;

    final messages = [
      {'role': 'system', 'content': _buildSystemPrompt(workspaceName)},
      ...trimmedHistory
          .where((m) => m.role != ChatRole.system && !m.isError)
          .map((m) => m.toApiJson()),
      {'role': 'user', 'content': userMessage},
    ];

    try {
      final response = await _dio.post(
        '/chat/completions',
        data: {
          'model': _kModel,
          'messages': messages,
          'max_tokens': 800,
          'temperature': 0.7,
          'stream': false,
        },
      );
      final content = response.data['choices']?[0]?['message']?['content'] as String?;
      if (content == null || content.isEmpty) throw Exception('Phản hồi trống từ AI');
      return content.trim();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) throw Exception('API key không hợp lệ hoặc hết hạn');
      if (status == 429) throw Exception('Quá giới hạn yêu cầu, vui lòng thử lại sau');
      if (status == 402) throw Exception('Tài khoản DeepSeek hết số dư');
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Kết nối timeout — kiểm tra mạng và thử lại');
      }
      throw Exception('Lỗi kết nối: ${e.message}');
    }
  }

  String _buildSystemPrompt(String workspaceName) {
    final today = DateTime.now();
    final dateStr = '${today.day}/${today.month}/${today.year}';
    return '''Bạn là Trợ lý Tài chính AI của ứng dụng Sổ Thu Chi — giải pháp quản lý dòng tiền cho chủ shop và gia đình Việt Nam.

Không gian làm việc hiện tại: $workspaceName
Ngày hôm nay: $dateStr

Vai trò của bạn:
• Tư vấn quản lý thu chi, dòng tiền cá nhân/kinh doanh nhỏ
• Giải thích tính năng app (giao dịch, túi tiền, công nợ, báo cáo)
• Phân tích, nhận xét tình hình tài chính khi người dùng cung cấp số liệu
• Gợi ý tiết kiệm, tối ưu chi phí cho hộ kinh doanh nhỏ

Nguyên tắc trả lời:
• Ngắn gọn, đúng trọng tâm, tránh lan man
• Dùng tiếng Việt, giọng thân thiện nhưng chuyên nghiệp
• Khi cần liệt kê, dùng bullet ngắn thay vì đoạn dài
• Không suy diễn số liệu khi chưa được cung cấp''';
  }
}

final aiChatRepositoryProvider = Provider<AiChatRepository>((ref) => AiChatRepository());
