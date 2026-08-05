/// Rule-based Vietnamese NLU for voice transaction entry (Mục 10). This is
/// a deterministic keyword/regex parser, **not** an AI/LLM call — the
/// spec's original design (on-device TensorFlow Lite + cloud GPT-4o mini
/// fallback) needs infrastructure/API keys this environment doesn't have.
/// It handles the common phrasings a shop owner would actually say
/// ("thu 500k tiền mặt bán hàng", "chi 200k tiền chợ") and always leaves
/// the parsed fields editable in a confirmation card before saving — see
/// mobile/README.md "Voice input notes".
library;

/// Intent giao dịch + lệnh điều hướng nhanh.
enum VoiceIntent {
  // Tạo giao dịch
  income, expense, transfer, debtIncrease, debtDecrease,
  // Điều hướng — không tạo giao dịch
  openShift, closeShift, dailyClosing, viewReport, viewVaults,
  // Không xác định được
  unknown,
}

/// True nếu intent là điều hướng (không cần form giao dịch).
bool isNavigationIntent(VoiceIntent intent) {
  return intent == VoiceIntent.openShift ||
      intent == VoiceIntent.closeShift ||
      intent == VoiceIntent.dailyClosing ||
      intent == VoiceIntent.viewReport ||
      intent == VoiceIntent.viewVaults;
}

/// Route tương ứng cho từng navigation intent.
String routeForIntent(VoiceIntent intent) {
  return switch (intent) {
    VoiceIntent.openShift || VoiceIntent.closeShift => '/shift',
    VoiceIntent.dailyClosing => '/daily-closing',
    VoiceIntent.viewReport => '/reports',
    VoiceIntent.viewVaults => '/vaults',
    _ => '/dashboard',
  };
}

class VoiceParseResult {
  final VoiceIntent intent;
  final int? amount;
  final String? vaultNameGuess;
  final String? categoryNameGuess;
  /// Ghi chú đã được làm sạch (bỏ số tiền + từ khoá intent).
  final String? note;
  final String transcript;
  /// Ngày giao dịch (null = hôm nay).
  final DateTime? transactionDate;

  const VoiceParseResult({
    required this.intent,
    this.amount,
    this.vaultNameGuess,
    this.categoryNameGuess,
    this.note,
    this.transactionDate,
    required this.transcript,
  });
}

const Map<String, int> _wordNumbers = {
  'không': 0,
  'một': 1,
  'mốt': 1,
  'hai': 2,
  'ba': 3,
  'bốn': 4,
  'tư': 4,
  'năm': 5,
  'lăm': 5,
  'sáu': 6,
  'bảy': 7,
  'tám': 8,
  'chín': 9,
  'mười': 10,
};

String _stripDiacritics(String input) {
  const from = 'àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ';
  const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final buffer = StringBuffer();
  for (final ch in input.split('')) {
    final idx = from.indexOf(ch);
    buffer.write(idx == -1 ? ch : to[idx]);
  }
  return buffer.toString();
}

VoiceIntent _parseIntent(String lower) {
  bool has(List<String> keywords) => keywords.any(lower.contains);

  // Lệnh điều hướng — kiểm tra trước giao dịch
  if (has(['mở ca', 'bắt đầu ca', 'mở shift', 'vào ca'])) return VoiceIntent.openShift;
  if (has(['đóng ca', 'kết thúc ca', 'thoát ca', 'kết ca'])) return VoiceIntent.closeShift;
  if (has(['chốt sổ', 'chốt quỹ', 'chốt thu chi', 'kiểm quỹ', 'tổng kết ngày'])) return VoiceIntent.dailyClosing;
  if (has(['xem báo cáo', 'báo cáo hôm nay', 'doanh thu hôm nay', 'thống kê'])) return VoiceIntent.viewReport;
  if (has(['xem túi tiền', 'số dư túi', 'kiểm tra số dư', 'xem số dư'])) return VoiceIntent.viewVaults;

  // Giao dịch
  if (has(['trả nợ', 'trả tiền nợ', 'thu nợ', 'thu hồi nợ'])) return VoiceIntent.debtDecrease;
  if (has(['bán thiếu', 'bán chịu', 'ghi nợ'])) return VoiceIntent.debtIncrease;
  if (has(['chuyển tiền', 'chuyển khoản sang', 'chuyển sang', 'chuyển qua'])) return VoiceIntent.transfer;
  if (has(['chi ', 'chi tiền', 'mua ', 'trả tiền ', 'thanh toán', 'tiêu '])) return VoiceIntent.expense;
  if (has(['thu ', 'bán ', 'nhận tiền', 'thu nhập'])) return VoiceIntent.income;
  return VoiceIntent.unknown;
}

int? _parseAmount(String lower) {
  // Thử số ghép tiếng Việt trước (ưu tiên cao hơn regex đơn)
  final compound = _parseCompoundSpokenNumber(lower);
  if (compound != null && compound > 0) return compound;

  // "một triệu rưỡi", "hai trăm nghìn" style spoken numbers where the
  // digit itself is a word, immediately before a unit word.
  final wordUnitPattern = RegExp(
    r'(không|một|mốt|hai|ba|bốn|tư|năm|lăm|sáu|bảy|tám|chín|mười)\s*(nghìn|ngàn|triệu|tỷ)(\s*rưỡi)?',
  );
  final wordMatch = wordUnitPattern.firstMatch(lower);
  if (wordMatch != null) {
    final digit = _wordNumbers[wordMatch.group(1)] ?? 0;
    final unit = _unitMultiplier(wordMatch.group(2)!);
    final half = wordMatch.group(3) != null;
    return ((digit + (half ? 0.5 : 0)) * unit).round();
  }

  // Digit-based: "500k", "1.5 triệu", "2 triệu rưỡi", "300000".
  final digitUnitPattern = RegExp(r'(\d+(?:[.,]\d+)?)\s*(nghìn|ngàn|triệu|tr|tỷ|k)?(\s*rưỡi)?');
  for (final match in digitUnitPattern.allMatches(lower)) {
    final rawNumber = match.group(1);
    if (rawNumber == null) continue;
    final numeric = double.tryParse(rawNumber.replaceAll(',', '.'));
    if (numeric == null) continue;
    final unitWord = match.group(2);
    final half = match.group(3) != null;
    if (unitWord == null && !half) {
      // A bare number with no unit — only treat as the amount if it's
      // reasonably large (avoids matching stray digits like "2 cái").
      if (numeric >= 1000) return numeric.round();
      continue;
    }
    final unit = unitWord == null ? 1000 /* "rưỡi" alone implies nghìn in casual speech */ : _unitMultiplier(unitWord);
    return ((numeric + (half ? 0.5 : 0)) * unit).round();
  }
  return null;
}

int _unitMultiplier(String unit) {
  switch (unit) {
    case 'k':
    case 'nghìn':
    case 'ngàn':
      return 1000;
    case 'triệu':
    case 'tr':
      return 1000000;
    case 'tỷ':
      return 1000000000;
    default:
      return 1;
  }
}

// ---------------------------------------------------------------------------
// Số ghép tiếng Việt: "năm mươi ba nghìn", "một triệu hai trăm nghìn"
// ---------------------------------------------------------------------------

const Map<String, int> _tens = {
  'mười': 10, 'mươi': 10,
  'hai mươi': 20, 'hai mươi mốt': 21, 'hai mươi hai': 22, 'hai mươi ba': 23,
  'hai mươi bốn': 24, 'hai mươi lăm': 25, 'hai mươi sáu': 26,
  'hai mươi bảy': 27, 'hai mươi tám': 28, 'hai mươi chín': 29,
  'ba mươi': 30, 'bốn mươi': 40, 'năm mươi': 50,
  'sáu mươi': 60, 'bảy mươi': 70, 'tám mươi': 80, 'chín mươi': 90,
};

/// Thử parse số ghép kiểu "năm mươi ba nghìn" → 53000.
int? _parseCompoundSpokenNumber(String lower) {
  // Pattern: [triệu-part] [trăm-part] [chục-part] [đơn vị]
  // Ví dụ: "một triệu hai trăm năm mươi nghìn" = 1,250,000
  int? result;
  int remaining = 0;

  // Tỷ
  final tyMatch = RegExp(r'(một|hai|ba|bốn|năm|sáu|bảy|tám|chín)\s*tỷ').firstMatch(lower);
  if (tyMatch != null) {
    remaining += (_wordNumbers[tyMatch.group(1)] ?? 0) * 1000000000;
  }

  // Triệu
  final trieuMatch = RegExp(r'(một|hai|ba|bốn|năm|sáu|bảy|tám|chín|mười)\s*triệu').firstMatch(lower);
  if (trieuMatch != null) {
    remaining += (_wordNumbers[trieuMatch.group(1)] ?? 0) * 1000000;
  }

  // Trăm nghìn
  final tramNginMatch = RegExp(r'(một|hai|ba|bốn|năm|sáu|bảy|tám|chín)\s*trăm\s*nghìn').firstMatch(lower);
  if (tramNginMatch != null) {
    remaining += (_wordNumbers[tramNginMatch.group(1)] ?? 0) * 100000;
  }

  // Nghìn đơn thuần (không có trăm trước)
  if (tramNginMatch == null) {
    final nginMatch = RegExp(r'(một|hai|ba|bốn|năm|sáu|bảy|tám|chín|mười)\s*(nghìn|ngàn)').firstMatch(lower);
    if (nginMatch != null) {
      remaining += (_wordNumbers[nginMatch.group(1)] ?? 0) * 1000;
    }
  }

  // Chục: "năm mươi ba"
  for (final entry in _tens.entries) {
    if (lower.contains(entry.key)) {
      remaining += entry.value;
      // Thêm đơn vị lẻ sau chục (VD: "ba mươi ba" → 33)
      final afterTens = lower.substring(lower.indexOf(entry.key) + entry.key.length).trim();
      final unitMatch = RegExp(r'^(một|hai|ba|bốn|năm|lăm|sáu|bảy|tám|chín)\b').firstMatch(afterTens);
      if (unitMatch != null) remaining += _wordNumbers[unitMatch.group(1)] ?? 0;
      break;
    }
  }

  if (remaining > 0) result = remaining;
  return result;
}

// ---------------------------------------------------------------------------
// Date context: "hôm qua", "sáng nay", v.v.
// ---------------------------------------------------------------------------

DateTime? _parseDate(String lower) {
  final now = DateTime.now();
  if (lower.contains('hôm qua') || lower.contains('tối qua') || lower.contains('chiều qua')) {
    return DateTime(now.year, now.month, now.day - 1);
  }
  if (lower.contains('hôm kia')) {
    return DateTime(now.year, now.month, now.day - 2);
  }
  return null; // null = hôm nay
}

// ---------------------------------------------------------------------------
// Note extraction: bỏ số tiền + từ khoá intent, giữ nội dung
// ---------------------------------------------------------------------------

String? _extractNote(String transcript, VoiceIntent intent) {
  var text = transcript.toLowerCase().trim();

  // Xóa từ khoá intent
  const intentKeywords = [
    'thu ', 'chi ', 'mua ', 'bán ', 'thanh toán', 'trả tiền', 'nhận tiền',
    'chuyển tiền', 'chuyển khoản', 'bán thiếu', 'bán chịu', 'ghi nợ', 'trả nợ',
    'hôm nay', 'hôm qua', 'hôm kia', 'sáng nay', 'tối nay', 'buổi sáng',
  ];
  for (final kw in intentKeywords) {
    text = text.replaceAll(kw, ' ');
  }

  // Xóa số tiền (bao gồm chữ "k", "nghìn", "triệu", "rưỡi")
  text = text.replaceAll(RegExp(r'\d+(?:[.,]\d+)?\s*(?:k|nghìn|ngàn|triệu|tr|tỷ|rưỡi)?'), '');
  text = text.replaceAll(RegExp(r'\b(?:một|hai|ba|bốn|năm|sáu|bảy|tám|chín|mười|mốt|lăm|tư)\s*(?:k|nghìn|ngàn|triệu|tr|tỷ)\b'), '');

  // Xóa "tiền mặt", "tiền" đứng riêng
  text = text.replaceAll(RegExp(r'\btiền\b'), '');

  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty || text.length < 2) return null;

  // Capitalize
  return text[0].toUpperCase() + text.substring(1);
}

String? _matchByName(String lower, String lowerNoDiacritics, List<String> candidates) {
  for (final c in candidates) {
    final cl = c.toLowerCase();
    if (lower.contains(cl) || lowerNoDiacritics.contains(_stripDiacritics(cl))) return c;
  }
  return null;
}

/// [vaultNames]/[categoryNames] should be the *actual* names in the
/// current workspace, so the guess always maps to something real (never
/// invents a vault/category id).
VoiceParseResult parseVoiceTranscript(
  String transcript, {
  required List<String> vaultNames,
  required List<String> categoryNames,
}) {
  final lower = transcript.toLowerCase().trim();
  final lowerNoDiacritics = _stripDiacritics(lower);

  final intent = _parseIntent(lower);
  final amount = _parseAmount(lower);

  var vaultGuess = _matchByName(lower, lowerNoDiacritics, vaultNames);
  vaultGuess ??= lowerNoDiacritics.contains('tien mat')
      ? vaultNames.firstWhere((v) => v.toLowerCase().contains('mặt'), orElse: () => '')
      : null;
  if (vaultGuess != null && vaultGuess.isEmpty) vaultGuess = null;

  final categoryGuess = _matchByName(lower, lowerNoDiacritics, categoryNames);
  final note = _extractNote(transcript, intent);
  final transactionDate = _parseDate(lower);

  return VoiceParseResult(
    intent: intent,
    amount: amount,
    vaultNameGuess: vaultGuess,
    categoryNameGuess: categoryGuess,
    note: note,
    transactionDate: transactionDate,
    transcript: transcript,
  );
}
