import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Full VND display format, e.g. `formatVND(1500000)` -> `'1.500.000đ'`.
///
/// Per spec Mục 16.6, used wherever exact amounts matter (transaction
/// detail, reports, dashboard totals). The MVP only supports VND.
String formatVND(num amount) {
  final formatter = NumberFormat('#,###', 'vi_VN');
  return '${formatter.format(amount)}đ';
}

/// Rút gọn (compact) currency format, e.g. 1.500.000 -> '1,5tr'.
///
/// Kept for parity with spec Mục 16.6 groundwork, but the MVP uses
/// [formatVND] everywhere for simplicity (full format is acceptable for
/// this pass per the product owner).
String formatCurrency(num amount, {String locale = 'vi'}) {
  if (locale == 'en') {
    if (amount >= 1000000000) return '${(amount / 1000000000).toStringAsFixed(1)}B ₫';
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M ₫';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}k ₫';
    return '₫${amount.toInt()}';
  } else {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1).replaceAll('.', ',')} tỷ';
    }
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1).replaceAll('.', ',')}tr';
    }
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}k';
    return '${amount.toInt()}đ';
  }
}

/// Strips grouping dots/spaces and parses a formatted currency string typed
/// by the user (e.g. from a [CurrencyInputFormatter]-backed field) back into
/// an integer amount in VND. Returns 0 for empty/invalid input.
int parseCurrencyInput(String input) {
  final digitsOnly = input.replaceAll(RegExp(r'[^\d]'), '');
  if (digitsOnly.isEmpty) return 0;
  return int.tryParse(digitsOnly) ?? 0;
}

const _digitWords = [
  'không', 'một', 'hai', 'ba', 'bốn', 'năm', 'sáu', 'bảy', 'tám', 'chín', //
];

/// Reads an integer VND amount out loud in Vietnamese, e.g. `1000000` ->
/// `'Một triệu đồng'`, `1500000` -> `'Một triệu năm trăm nghìn đồng'`.
/// Shown as helper text under amount fields (Mục 19.1.1 UX polish). Only
/// handles magnitudes up to `999,999,999,999` (the app's own amount cap);
/// returns an empty string for 0 or out-of-range input.
String amountInWords(num amount) {
  final value = amount.round();
  if (value <= 0 || value > 999999999999) return '';

  String threeDigits(int n, {required bool isLeadingGroup}) {
    final hundreds = n ~/ 100;
    final remainder = n % 100;
    final tens = remainder ~/ 10;
    final units = remainder % 10;
    final parts = <String>[];

    if (hundreds > 0 || !isLeadingGroup) {
      parts.add('${_digitWords[hundreds]} trăm');
    }
    if (tens == 0) {
      if (units > 0 && (hundreds > 0 || !isLeadingGroup)) parts.add('linh ${_digitWords[units]}');
      if (units > 0 && isLeadingGroup && hundreds == 0) parts.add(_digitWords[units]);
    } else if (tens == 1) {
      parts.add('mười');
      if (units == 5) {
        parts.add('lăm');
      } else if (units > 0) {
        parts.add(_digitWords[units]);
      }
    } else {
      parts.add('${_digitWords[tens]} mươi');
      if (units == 1) {
        parts.add('mốt');
      } else if (units == 5) {
        parts.add('lăm');
      } else if (units > 0) {
        parts.add(_digitWords[units]);
      }
    }
    return parts.join(' ');
  }

  final groups = <int>[];
  var remaining = value;
  while (remaining > 0) {
    groups.insert(0, remaining % 1000);
    remaining ~/= 1000;
  }
  const groupUnits = ['', 'nghìn', 'triệu', 'tỷ'];

  final words = <String>[];
  for (var i = 0; i < groups.length; i++) {
    final group = groups[i];
    if (group == 0) continue;
    final isLeadingGroup = i == 0;
    final unit = groupUnits[groups.length - 1 - i];
    final groupWords = threeDigits(group, isLeadingGroup: isLeadingGroup);
    words.add(unit.isEmpty ? groupWords : '$groupWords $unit');
  }

  final sentence = words.join(' ').trim();
  if (sentence.isEmpty) return '';
  return '${sentence[0].toUpperCase()}${sentence.substring(1)} đồng';
}

/// TextInputFormatter that live-formats a currency field with dot-grouped
/// thousands as the user types, per spec Mục 19.1.1: e.g. typing `1000000`
/// shows `1.000.000`. MVP only supports integer VND amounts (no decimals).
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return const TextEditingValue(text: '');

    final formatted = NumberFormat('#,###').format(int.parse(digitsOnly));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
