/// Rule-based Vietnamese NLU for voice transaction entry (Mục 10). This is
/// a deterministic keyword/regex parser, **not** an AI/LLM call — the
/// spec's original design (on-device TensorFlow Lite + cloud GPT-4o mini
/// fallback) needs infrastructure/API keys this environment doesn't have.
/// It handles the common phrasings a shop owner would actually say
/// ("thu 500k tiền mặt bán hàng", "chi 200k tiền chợ") and always leaves
/// the parsed fields editable in a confirmation card before saving — see
/// mobile/README.md "Voice input notes".
library;

enum VoiceIntent { income, expense, transfer, debtIncrease, debtDecrease, unknown }

class VoiceParseResult {
  final VoiceIntent intent;
  final int? amount;
  final String? vaultNameGuess;
  final String? categoryNameGuess;
  final String transcript;

  const VoiceParseResult({
    required this.intent,
    this.amount,
    this.vaultNameGuess,
    this.categoryNameGuess,
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

  if (has(['trả nợ', 'trả tiền nợ', 'thu nợ', 'thu hồi nợ'])) return VoiceIntent.debtDecrease;
  if (has(['bán thiếu', 'bán chịu', 'ghi nợ'])) return VoiceIntent.debtIncrease;
  if (has(['chuyển tiền', 'chuyển khoản sang', 'chuyển sang', 'chuyển qua'])) return VoiceIntent.transfer;
  if (has(['chi ', 'mua ', 'trả tiền ', 'thanh toán'])) return VoiceIntent.expense;
  if (has(['thu ', 'bán ', 'nhận tiền'])) return VoiceIntent.income;
  return VoiceIntent.unknown;
}

int? _parseAmount(String lower) {
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

  return VoiceParseResult(
    intent: intent,
    amount: amount,
    vaultNameGuess: vaultGuess,
    categoryNameGuess: categoryGuess,
    transcript: transcript,
  );
}
