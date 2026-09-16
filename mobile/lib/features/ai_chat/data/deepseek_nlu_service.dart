import 'dart:collection';
import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../voice/domain/voice_nlu_parser.dart';

// ---------------------------------------------------------------------------
// Cấu hình
// ---------------------------------------------------------------------------

const _kApiKey = String.fromEnvironment(
  'DEEPSEEK_API_KEY',
  defaultValue: 'sk-ba5e92a9187e440c833087e7a3e95f75',
);
const _kApiBase = 'https://api.deepseek.com';
const _kModel = 'deepseek-chat';

/// Số entry tối đa trong cache LRU (≈ bộ nhớ ≤ vài KB — nhỏ).
const _kCacheMaxSize = 50;

/// Cache hết hạn sau 5 phút — đủ lâu để tái dùng trong 1 phiên, đủ ngắn
/// để không giữ kết quả lỗi thời.
const _kCacheTtl = Duration(minutes: 5);

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

/// Danh mục chi tiêu chuẩn (slug). Giá trị trùng với key DeepSeek trả về
/// để tránh mapping thừa.
enum ExpenseCategory {
  anUong('An_uong', 'Ăn uống'),
  diChuyen('Di_chuyen', 'Di chuyển'),
  muaSam('Mua_sam', 'Mua sắm'),
  hoaDon('Hoa_don', 'Hóa đơn'),
  giaiTri('Giai_tri', 'Giải trí'),
  yTe('Y_te', 'Y tế'),
  khac('Khac', 'Khác');

  const ExpenseCategory(this.slug, this.label);
  final String slug;
  final String label;

  static ExpenseCategory? fromSlug(String? slug) {
    if (slug == null) return null;
    for (final c in values) {
      if (c.slug.toLowerCase() == slug.toLowerCase()) return c;
    }
    return null;
  }
}

/// Kết quả phân tích câu nói/text thành giao dịch.
class NluTransactionResult {
  /// Intent: income / expense / transfer / debt_increase / debt_decrease / unknown
  final VoiceIntent intent;

  /// Số tiền (VNĐ, nguyên), null nếu không tìm thấy.
  final int? amount;

  /// Danh mục chi tiêu chuẩn — chỉ set cho expense.
  final ExpenseCategory? category;

  /// Tên danh mục tùy chỉnh (từ workspace), để map về categoryId ngoài service.
  final String? categoryNameGuess;

  /// Tên túi tiền gợi ý (từ workspace context), để map về vaultId ngoài service.
  final String? vaultNameGuess;

  /// Ghi chú tóm tắt nội dung giao dịch.
  final String? note;

  /// Ngày giao dịch do regex nhận diện ("hôm qua"/"hôm kia"). Chỉ regex
  /// đường có field này — AI không phân tích ngày. Giao dịch vẫn được lưu
  /// theo ngày hôm nay; UI dùng field này để cảnh báo thay vì bỏ im lặng.
  final DateTime? transactionDate;

  /// 'ai' | 'regex' | 'cache' — giúp debug, hiển thị badge "AI" hay không.
  final String source;

  const NluTransactionResult({
    required this.intent,
    this.amount,
    this.category,
    this.categoryNameGuess,
    this.vaultNameGuess,
    this.note,
    this.transactionDate,
    required this.source,
  });

  NluTransactionResult copyWith({String? source}) => NluTransactionResult(
        intent: intent,
        amount: amount,
        category: category,
        categoryNameGuess: categoryNameGuess,
        vaultNameGuess: vaultNameGuess,
        note: note,
        transactionDate: transactionDate,
        source: source ?? this.source,
      );
}

// ---------------------------------------------------------------------------
// Cache entry nội bộ
// ---------------------------------------------------------------------------

class _CacheEntry {
  final NluTransactionResult result;
  final DateTime expiresAt;
  _CacheEntry(this.result) : expiresAt = DateTime.now().add(_kCacheTtl);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

// ---------------------------------------------------------------------------
// DeepSeekNluService
// ---------------------------------------------------------------------------

/// Dịch vụ AI tích hợp DeepSeek cho 2 mục đích:
///
/// 1. [parseTransaction] — phân tích câu nói/text thành dữ liệu giao dịch
///    (số tiền, danh mục, ghi chú). Tự động:
///    • Kiểm tra cache trước (tiết kiệm token & giảm latency).
///    • Dùng regex parser nếu input đủ rõ ràng (không gọi AI).
///    • Gọi DeepSeek khi regex không đủ tự tin.
///    • Fallback về regex nếu AI thất bại (offline, hết quota, ...).
///
/// 2. [answerFinancialQuestion] — trả lời câu hỏi tài chính bằng tiếng Việt,
///    có thể nhận [financialContext] (tóm tắt dữ liệu) để trả lời chính xác.
///    Tự trả lời không cần AI cho các truy vấn aggregate đơn giản.
class DeepSeekNluService {
  // LinkedHashMap giữ thứ tự insertion → dễ evict entry cũ nhất (LRU).
  final _cache = LinkedHashMap<String, _CacheEntry>();

  late final Dio _dio = Dio(BaseOptions(
    baseUrl: _kApiBase,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Authorization': 'Bearer $_kApiKey',
      'Content-Type': 'application/json',
    },
  ));

  // ---------------------------------------------------------------------------
  // 1. Phân tích giao dịch từ câu nói
  // ---------------------------------------------------------------------------

  /// Phân tích [text] (VD: "ăn trưa 50k") thành [NluTransactionResult].
  ///
  /// Thứ tự ưu tiên:
  ///   cache hit → regex đủ tự tin → DeepSeek → regex fallback
  ///
  /// [vaultNames] và [categoryNames] là danh sách tên thực từ workspace,
  /// dùng để regex parser map về đúng entity.
  Future<NluTransactionResult> parseTransaction(
    String text, {
    List<String> vaultNames = const [],
    List<String> categoryNames = const [],
  }) async {
    final key = _cacheKey(text);
    dev.log('[NLU] parse: "$text"', name: 'DeepSeekNlu');

    // --- Cache ---
    final cached = _getFromCache(key);
    if (cached != null) {
      dev.log('[NLU] cache hit → ${cached.intent} ${cached.amount}', name: 'DeepSeekNlu');
      return cached.copyWith(source: 'cache');
    }

    // --- Regex fast path ---
    final regexResult = parseVoiceTranscript(text, vaultNames: vaultNames, categoryNames: categoryNames);
    final regexConfident = regexResult.intent != VoiceIntent.unknown && regexResult.amount != null;

    if (regexConfident) {
      dev.log('[NLU] regex → ${regexResult.intent} ${regexResult.amount} (skip AI)', name: 'DeepSeekNlu');
      final result = _fromRegex(regexResult);
      _putInCache(key, result);
      return result;
    }

    // --- DeepSeek NLU ---
    try {
      final result = await _callNluApi(text, categoryNames: categoryNames);
      dev.log('[NLU] AI → ${result.intent} ${result.amount} cat=${result.category?.slug}', name: 'DeepSeekNlu');
      _putInCache(key, result);
      return result;
    } catch (e) {
      dev.log('[NLU] AI failed: $e — fallback to regex', name: 'DeepSeekNlu', error: e);
      return _fromRegex(regexResult);
    }
  }

  // ---------------------------------------------------------------------------
  // 2. Trả lời câu hỏi tài chính
  // ---------------------------------------------------------------------------

  /// Trả lời [question] (VD: "tháng này ăn hết bao nhiêu?").
  ///
  /// [financialContext] là Map tóm tắt dữ liệu tài chính (từ báo cáo, ...).
  /// Nếu câu hỏi là truy vấn đơn giản (tổng theo danh mục) và context có
  /// sẵn dữ liệu, trả lời trực tiếp mà không gọi AI.
  Future<String> answerFinancialQuestion(
    String question, {
    Map<String, dynamic>? financialContext,
    String workspaceName = '',
  }) async {
    dev.log('[FinQA] question: "$question"', name: 'DeepSeekNlu');

    // Trả lời trực tiếp nếu là truy vấn aggregate đơn giản
    if (financialContext != null) {
      final direct = _tryDirectAnswer(question, financialContext);
      if (direct != null) {
        dev.log('[FinQA] direct answer (no AI)', name: 'DeepSeekNlu');
        return direct;
      }
    }

    // Gọi AI với context tài chính
    try {
      return await _callQaApi(question, context: financialContext, workspaceName: workspaceName);
    } catch (e) {
      dev.log('[FinQA] AI failed: $e', name: 'DeepSeekNlu', error: e);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Private — DeepSeek API calls
  // ---------------------------------------------------------------------------

  Future<NluTransactionResult> _callNluApi(String text, {List<String> categoryNames = const []}) async {
    final categoryList = categoryNames.isNotEmpty
        ? categoryNames.take(10).join(', ')
        : ExpenseCategory.values.map((c) => c.slug).join('|');

    // Prompt cực ngắn để tiết kiệm token — DeepSeek hiểu tiếng Việt tốt.
    const systemPrompt = '''Phân tích câu tiếng Việt, trả về JSON thuần (không markdown):
{"intent":"income|expense|transfer|debt_increase|debt_decrease|unknown","amount":number_or_null,"category_slug":"slug_or_null","note":"string_or_null"}

Quy tắc:
- amount: số nguyên VNĐ (k=×1000, triệu=×1000000, null nếu không có)
- category_slug cho expense: An_uong|Di_chuyen|Mua_sam|Hoa_don|Giai_tri|Y_te|Khac
- note: tóm tắt nội dung, bỏ số tiền, null nếu không rõ
- intent: income=thu tiền, expense=chi tiền, transfer=chuyển tiền''';

    final response = await _dio.post('/chat/completions', data: {
      'model': _kModel,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': 'Phân tích: "$text"'},
      ],
      'max_tokens': 120,
      'temperature': 0.1, // Thấp để output ổn định/deterministic
      'stream': false,
    });

    final content = response.data['choices']?[0]?['message']?['content'] as String? ?? '';
    dev.log('[NLU] raw AI response: $content', name: 'DeepSeekNlu');
    return _parseNluJson(content);
  }

  Future<String> _callQaApi(
    String question, {
    Map<String, dynamic>? context,
    String workspaceName = '',
  }) async {
    final contextBlock = context != null ? '\n\nDữ liệu tài chính:\n${_formatContext(context)}' : '';
    final today = DateTime.now();

    final systemPrompt =
        'Trợ lý tài chính cho shop/gia đình Việt Nam. Không gian làm việc: $workspaceName. '
        'Ngày: ${today.day}/${today.month}/${today.year}.$contextBlock\n\n'
        'Trả lời ngắn gọn, đúng trọng tâm, tiếng Việt.';

    final response = await _dio.post('/chat/completions', data: {
      'model': _kModel,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': question},
      ],
      'max_tokens': 400,
      'temperature': 0.6,
      'stream': false,
    });

    final content = response.data['choices']?[0]?['message']?['content'] as String? ?? '';
    if (content.isEmpty) throw Exception('Phản hồi trống từ AI');
    return content.trim();
  }

  // ---------------------------------------------------------------------------
  // Private — trả lời trực tiếp không cần AI
  // ---------------------------------------------------------------------------

  /// Trả lời các truy vấn aggregate đơn giản từ context mà không tốn token.
  /// VD: "tháng này ăn hết bao nhiêu?" → tìm key 'An_uong' trong context.
  String? _tryDirectAnswer(String question, Map<String, dynamic> context) {
    final q = question.toLowerCase();

    // Tổng thu/chi tháng này
    if ((q.contains('tổng') || q.contains('bao nhiêu')) && q.contains('tháng')) {
      if (q.contains('thu') && context['totalIncome'] != null) {
        return 'Tổng thu tháng này: ${_fmtVnd(context['totalIncome'])}';
      }
      if ((q.contains('chi') || q.contains('tiêu')) && context['totalExpense'] != null) {
        return 'Tổng chi tháng này: ${_fmtVnd(context['totalExpense'])}';
      }
    }

    // Tổng theo danh mục
    for (final cat in ExpenseCategory.values) {
      if (_qMatchCategory(q, cat)) {
        final key = 'expense_${cat.slug.toLowerCase()}';
        if (context[key] != null) {
          return '${cat.label} tháng này: ${_fmtVnd(context[key])}';
        }
      }
    }

    // Số dư túi tiền
    if (q.contains('số dư') || q.contains('còn bao nhiêu')) {
      if (context['totalBalance'] != null) {
        return 'Tổng số dư: ${_fmtVnd(context['totalBalance'])}';
      }
    }

    return null; // Không tự trả lời được → gọi AI
  }

  bool _qMatchCategory(String q, ExpenseCategory cat) {
    switch (cat) {
      case ExpenseCategory.anUong:
        return q.contains('ăn') || q.contains('uống') || q.contains('ăn uống');
      case ExpenseCategory.diChuyen:
        return q.contains('xăng') || q.contains('đi lại') || q.contains('di chuyển');
      case ExpenseCategory.muaSam:
        return q.contains('mua sắm') || q.contains('mua đồ');
      case ExpenseCategory.hoaDon:
        return q.contains('hóa đơn') || q.contains('điện') || q.contains('nước') || q.contains('internet');
      case ExpenseCategory.giaiTri:
        return q.contains('giải trí') || q.contains('xem phim') || q.contains('du lịch');
      case ExpenseCategory.yTe:
        return q.contains('y tế') || q.contains('thuốc') || q.contains('bác sĩ');
      case ExpenseCategory.khac:
        return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Private — parse JSON từ AI
  // ---------------------------------------------------------------------------

  NluTransactionResult _parseNluJson(String raw) {
    // Trích JSON từ response (đôi khi AI wrap trong ```json ... ```)
    final jsonStr = _extractJson(raw);
    if (jsonStr == null) {
      dev.log('[NLU] JSON parse failed, raw: $raw', name: 'DeepSeekNlu');
      return const NluTransactionResult(intent: VoiceIntent.unknown, source: 'ai');
    }

    try {
      // Dùng RegExp thay vì dart:convert để tránh import không cần thiết
      final intentMatch = RegExp(r'"intent"\s*:\s*"([^"]+)"').firstMatch(jsonStr);
      final amountMatch = RegExp(r'"amount"\s*:\s*(\d+)').firstMatch(jsonStr);
      final categoryMatch = RegExp(r'"category_slug"\s*:\s*"([^"]+)"').firstMatch(jsonStr);
      final noteMatch = RegExp(r'"note"\s*:\s*"([^"]*)"').firstMatch(jsonStr);

      final intentStr = intentMatch?.group(1) ?? 'unknown';
      final amountStr = amountMatch?.group(1);
      final categorySlug = categoryMatch?.group(1);
      final note = noteMatch?.group(1)?.trim();

      return NluTransactionResult(
        intent: _parseIntentStr(intentStr),
        amount: amountStr != null ? int.tryParse(amountStr) : null,
        category: ExpenseCategory.fromSlug(categorySlug),
        note: (note?.isEmpty ?? true) || note == 'null' ? null : note,
        source: 'ai',
      );
    } catch (e) {
      dev.log('[NLU] JSON parse error: $e', name: 'DeepSeekNlu', error: e);
      return const NluTransactionResult(intent: VoiceIntent.unknown, source: 'ai');
    }
  }

  String? _extractJson(String raw) {
    // Xóa markdown code block nếu có
    final cleaned = raw.replaceAll(RegExp(r'```json?\s*|\s*```'), '').trim();
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    return cleaned.substring(start, end + 1);
  }

  VoiceIntent _parseIntentStr(String s) {
    switch (s.toLowerCase()) {
      case 'income':
        return VoiceIntent.income;
      case 'expense':
        return VoiceIntent.expense;
      case 'transfer':
        return VoiceIntent.transfer;
      case 'debt_increase':
        return VoiceIntent.debtIncrease;
      case 'debt_decrease':
        return VoiceIntent.debtDecrease;
      default:
        return VoiceIntent.unknown;
    }
  }

  // ---------------------------------------------------------------------------
  // Private — convert từ regex result
  // ---------------------------------------------------------------------------

  NluTransactionResult _fromRegex(VoiceParseResult r) {
    return NluTransactionResult(
      intent: r.intent,
      amount: r.amount,
      vaultNameGuess: r.vaultNameGuess,
      categoryNameGuess: r.categoryNameGuess,
      note: r.note,
      transactionDate: r.transactionDate,
      source: 'regex',
    );
  }

  // ---------------------------------------------------------------------------
  // Private — LRU cache helpers
  // ---------------------------------------------------------------------------

  String _cacheKey(String text) => text.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  NluTransactionResult? _getFromCache(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    // Move-to-end (LRU promotion)
    _cache.remove(key);
    _cache[key] = entry;
    return entry.result;
  }

  void _putInCache(String key, NluTransactionResult result) {
    // Evict entry cũ nhất nếu đầy
    if (_cache.length >= _kCacheMaxSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = _CacheEntry(result);
  }

  // ---------------------------------------------------------------------------
  // Private — tiện ích
  // ---------------------------------------------------------------------------

  String _fmtVnd(dynamic amount) {
    if (amount == null) return '?';
    final n = (amount as num).round();
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)} triệu đ';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k đ';
    return '${n}đ';
  }

  String _formatContext(Map<String, dynamic> ctx) {
    final lines = <String>[];
    if (ctx['totalIncome'] != null) lines.add('Tổng thu: ${_fmtVnd(ctx['totalIncome'])}');
    if (ctx['totalExpense'] != null) lines.add('Tổng chi: ${_fmtVnd(ctx['totalExpense'])}');
    if (ctx['totalBalance'] != null) lines.add('Số dư tổng: ${_fmtVnd(ctx['totalBalance'])}');
    for (final cat in ExpenseCategory.values) {
      final key = 'expense_${cat.slug.toLowerCase()}';
      if (ctx[key] != null) lines.add('${cat.label}: ${_fmtVnd(ctx[key])}');
    }
    if (ctx['topExpenses'] is List) {
      lines.add('Chi nhiều nhất: ${(ctx['topExpenses'] as List).take(3).join(', ')}');
    }
    return lines.join('\n');
  }
}

final deepSeekNluServiceProvider = Provider<DeepSeekNluService>((ref) => DeepSeekNluService());
