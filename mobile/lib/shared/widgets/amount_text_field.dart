import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';

/// A `TextFormField` pre-wired with [CurrencyInputFormatter] and standard
/// amount validation (> 0, integer, per spec Mục 19.1), used by every
/// money-amount input in the app (transaction create sheet, vault initial
/// balance, reconcile screen, etc). Shows a live "amount in words" helper
/// underneath, e.g. typing `1000000` shows "Một triệu đồng".
class AmountTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;
  final Color accent;

  const AmountTextField({
    super.key,
    required this.controller,
    this.label = 'Số tiền',
    this.required = true,
    this.onChanged,
    this.suffixIcon,
    this.accent = AppColors.primary,
  });

  @override
  State<AmountTextField> createState() => _AmountTextFieldState();
}

class _AmountTextFieldState extends State<AmountTextField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  String? _validate(String? value) {
    final amount = parseCurrencyInput(value ?? '');
    if (widget.required && amount <= 0) return 'Số tiền phải lớn hơn 0';
    if (amount > 999999999999) return 'Số tiền quá lớn';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final words = amountInWords(parseCurrencyInput(widget.controller.text));
    return TextFormField(
      controller: widget.controller,
      keyboardType: TextInputType.number,
      inputFormatters: [CurrencyInputFormatter()],
      validator: _validate,
      onChanged: widget.onChanged,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: widget.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.attach_money, color: widget.accent, size: 18),
        ),
        suffixText: 'đ',
        suffixIcon: widget.suffixIcon,
        helperText: words.isEmpty ? null : words,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.accent, width: 1.6)),
      ),
    );
  }
}
