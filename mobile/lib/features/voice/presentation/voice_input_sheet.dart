import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/offline/sync_queue_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/widgets/amount_text_field.dart';
import '../../../shared/widgets/sheet_drag_handle.dart';
import '../../category/data/category_repository.dart';
import '../../debt/domain/customer.dart';
import '../../transaction/data/transaction_repository.dart';
import '../../transaction/presentation/create_transaction_sheet.dart' show VaultDropdownField, CategoryDropdownField;
import '../../transaction/presentation/debt_transaction_tab.dart' show CustomerDropdownField;
import '../../vault/data/vault_repository.dart';
import '../domain/voice_nlu_parser.dart';

/// Nhập liệu bằng giọng nói (Mục 10): mic → live transcript → parsed
/// confirmation form (never auto-saves — Mục 10.3's "tự động lưu sau 3
/// giây" was intentionally dropped in favor of an explicit Lưu button, to
/// avoid a rule-based parser silently saving a misheard amount).
Future<bool?> showVoiceInputSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const VoiceInputSheet(),
  );
}

enum _Phase { idle, listening, confirming }

class VoiceInputSheet extends ConsumerStatefulWidget {
  const VoiceInputSheet({super.key});

  @override
  ConsumerState<VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends ConsumerState<VoiceInputSheet> {
  final _speech = stt.SpeechToText();
  _Phase _phase = _Phase.idle;
  String _transcript = '';
  String? _initError;
  bool _speechReady = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (e) => setState(() => _initError = 'Lỗi nhận diện giọng nói: ${e.errorMsg}'),
      );
      setState(() => _speechReady = available);
      if (available) _startListening();
    } catch (e) {
      setState(() => _initError = 'Thiết bị không hỗ trợ nhận diện giọng nói.');
    }
  }

  Future<void> _startListening() async {
    setState(() {
      _phase = _Phase.listening;
      _transcript = '';
    });
    await _speech.listen(
      onResult: (result) {
        setState(() => _transcript = result.recognizedWords);
        if (result.finalResult) _finishListening();
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        partialResults: true,
        localeId: 'vi_VN',
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  void _finishListening() {
    if (_speech.isListening) _speech.stop();
    if (_transcript.trim().isEmpty) {
      setState(() => _phase = _Phase.idle);
      return;
    }
    setState(() => _phase = _Phase.confirming);
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Center(child: SheetDragHandle()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Nhập bằng giọng nói', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).maybePop()),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: switch (_phase) {
                _Phase.idle => _IdleOrErrorView(error: _initError, ready: _speechReady, onRetry: _startListening),
                _Phase.listening => _ListeningView(transcript: _transcript, onStop: _finishListening),
                _Phase.confirming => _ConfirmationForm(
                    transcript: _transcript,
                    onRestart: _startListening,
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _IdleOrErrorView extends StatelessWidget {
  final String? error;
  final bool ready;
  final VoidCallback onRetry;

  const _IdleOrErrorView({required this.error, required this.ready, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_off_outlined, size: 56, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              error ?? (ready ? 'Không nghe rõ. Vui lòng thử lại.' : 'Đang chuẩn bị micro...'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (ready) FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.mic), label: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

class _ListeningView extends StatelessWidget {
  final String transcript;
  final VoidCallback onStop;

  const _ListeningView({required this.transcript, required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulsingMic(onTap: onStop),
            const SizedBox(height: 24),
            Text(
              transcript.isEmpty ? 'Đang nghe... hãy nói ví dụ "thu 500 nghìn tiền mặt bán hàng"' : transcript,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: transcript.isEmpty ? 13 : 17, color: transcript.isEmpty ? AppColors.textSecondary : AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            TextButton(onPressed: onStop, child: const Text('Dừng và xác nhận')),
          ],
        ),
      ),
    );
  }
}

class _PulsingMic extends StatefulWidget {
  final VoidCallback onTap;

  const _PulsingMic({required this.onTap});

  @override
  State<_PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<_PulsingMic> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1 + _controller.value * 0.15;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: AppColors.expense.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.mic, color: AppColors.expense, size: 44),
            ),
          );
        },
      ),
    );
  }
}

class _ConfirmationForm extends ConsumerStatefulWidget {
  final String transcript;
  final VoidCallback onRestart;

  const _ConfirmationForm({required this.transcript, required this.onRestart});

  @override
  ConsumerState<_ConfirmationForm> createState() => _ConfirmationFormState();
}

class _ConfirmationFormState extends ConsumerState<_ConfirmationForm> {
  final _formKey = GlobalKey<FormState>();
  late final _amountController = TextEditingController();
  late final _noteController = TextEditingController(text: widget.transcript);
  VoiceIntent _intent = VoiceIntent.unknown;
  String? _vaultId;
  String? _toVaultId;
  String? _categoryId;
  Customer? _customer;
  bool _isSaving = false;
  bool _parsed = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _runParser() async {
    if (_parsed) return;
    _parsed = true;
    final workspaceId = ref.read(currentWorkspaceIdProvider);
    final vaults = await ref.read(vaultRepositoryProvider).getVaults(workspaceId);
    final incomeCategories = await ref.read(categoryRepositoryProvider).getCategories(workspaceId: workspaceId, group: 'income');
    final expenseCategories = await ref.read(categoryRepositoryProvider).getCategories(workspaceId: workspaceId, group: 'expense');

    final result = parseVoiceTranscript(
      widget.transcript,
      vaultNames: vaults.map((v) => v.name).toList(),
      categoryNames: [...incomeCategories, ...expenseCategories].map((c) => c.name).toList(),
    );

    final matchedVault = vaults.where((v) => v.name == result.vaultNameGuess).toList();
    final matchedCategory = [...incomeCategories, ...expenseCategories].where((c) => c.name == result.categoryNameGuess).toList();

    if (!mounted) return;
    setState(() {
      _intent = result.intent == VoiceIntent.unknown ? VoiceIntent.income : result.intent;
      if (result.amount != null) _amountController.text = NumberFormatUtil.grouped(result.amount!);
      if (matchedVault.isNotEmpty) _vaultId = matchedVault.first.id;
      if (matchedCategory.isNotEmpty) _categoryId = matchedCategory.first.id;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = parseCurrencyInput(_amountController.text);
    final workspaceId = ref.read(currentWorkspaceIdProvider);
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      switch (_intent) {
        case VoiceIntent.income:
          if (_vaultId == null) throw const _MissingFieldException('Vui lòng chọn túi nhận tiền');
          await repo.createIncome(workspaceId: workspaceId, toVaultId: _vaultId!, amount: amount, categoryId: _categoryId, note: _noteController.text.trim(), source: 'voice');
        case VoiceIntent.expense:
          if (_vaultId == null) throw const _MissingFieldException('Vui lòng chọn túi chi tiền');
          await repo.createExpense(workspaceId: workspaceId, fromVaultId: _vaultId!, amount: amount, categoryId: _categoryId, note: _noteController.text.trim(), source: 'voice');
        case VoiceIntent.transfer:
          if (_vaultId == null || _toVaultId == null) throw const _MissingFieldException('Vui lòng chọn đủ túi nguồn và túi đích');
          await repo.createTransfer(workspaceId: workspaceId, fromVaultId: _vaultId!, toVaultId: _toVaultId!, amount: amount, note: _noteController.text.trim(), source: 'voice');
        case VoiceIntent.debtIncrease:
          if (_customer == null) throw const _MissingFieldException('Vui lòng chọn khách hàng');
          await repo.createDebtIncrease(workspaceId: workspaceId, customerId: _customer!.id, amount: amount, note: _noteController.text.trim(), source: 'voice');
        case VoiceIntent.debtDecrease:
          if (_customer == null || _vaultId == null) throw const _MissingFieldException('Vui lòng chọn khách hàng và túi nhận tiền');
          await repo.createDebtDecrease(workspaceId: workspaceId, customerId: _customer!.id, toVaultId: _vaultId!, amount: amount, source: 'voice');
        case VoiceIntent.unknown:
          break;
      }
      ref.invalidate(pendingSyncCountProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      final message = e is _MissingFieldException
          ? e.message
          : e is ApiException
              ? e.message
              : 'Không thể lưu giao dịch';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_parsed) {
      _runParser();
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.record_voice_over_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text('"${widget.transcript}"', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13))),
                TextButton(onPressed: widget.onRestart, child: const Text('Nói lại')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Loại giao dịch', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _IntentChip(label: 'Thu', selected: _intent == VoiceIntent.income, color: AppColors.income, onTap: () => setState(() => _intent = VoiceIntent.income)),
              _IntentChip(label: 'Chi', selected: _intent == VoiceIntent.expense, color: AppColors.expense, onTap: () => setState(() => _intent = VoiceIntent.expense)),
              _IntentChip(label: 'Chuyển tiền', selected: _intent == VoiceIntent.transfer, color: AppColors.transfer, onTap: () => setState(() => _intent = VoiceIntent.transfer)),
              _IntentChip(label: 'Bán thiếu', selected: _intent == VoiceIntent.debtIncrease, color: AppColors.debt, onTap: () => setState(() => _intent = VoiceIntent.debtIncrease)),
              _IntentChip(label: 'Trả nợ', selected: _intent == VoiceIntent.debtDecrease, color: AppColors.debt, onTap: () => setState(() => _intent = VoiceIntent.debtDecrease)),
            ],
          ),
          const SizedBox(height: 16),
          AmountTextField(controller: _amountController),
          const SizedBox(height: 12),
          if (_intent == VoiceIntent.income) ...[
            VaultDropdownField(label: 'Túi nhận tiền', value: _vaultId, onChanged: (v) => setState(() => _vaultId = v)),
            const SizedBox(height: 12),
            CategoryDropdownField(group: 'income', value: _categoryId, onChanged: (v) => setState(() => _categoryId = v)),
          ] else if (_intent == VoiceIntent.expense) ...[
            VaultDropdownField(label: 'Túi chi tiền', value: _vaultId, onChanged: (v) => setState(() => _vaultId = v)),
            const SizedBox(height: 12),
            CategoryDropdownField(group: 'expense', value: _categoryId, onChanged: (v) => setState(() => _categoryId = v)),
          ] else if (_intent == VoiceIntent.transfer) ...[
            VaultDropdownField(label: 'Túi nguồn', value: _vaultId, onChanged: (v) => setState(() => _vaultId = v)),
            const SizedBox(height: 12),
            VaultDropdownField(label: 'Túi đích', value: _toVaultId, excludeVaultId: _vaultId, onChanged: (v) => setState(() => _toVaultId = v)),
          ] else if (_intent == VoiceIntent.debtIncrease) ...[
            CustomerDropdownField(value: _customer?.id, onSelected: (c) => setState(() => _customer = c)),
          ] else if (_intent == VoiceIntent.debtDecrease) ...[
            CustomerDropdownField(value: _customer?.id, onSelected: (c) => setState(() => _customer = c)),
            const SizedBox(height: 12),
            VaultDropdownField(label: 'Túi nhận tiền', value: _vaultId, onChanged: (v) => setState(() => _vaultId = v)),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteController,
            decoration: InputDecoration(labelText: 'Ghi chú', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            maxLines: 2,
            maxLength: 500,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _isSaving ? null : _submit,
            child: _isSaving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Lưu giao dịch'),
          ),
        ],
      ),
    );
  }
}

class _IntentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _IntentChip({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: color,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    );
  }
}

class _MissingFieldException implements Exception {
  final String message;

  const _MissingFieldException(this.message);
}

/// Same dot-grouped formatting `AmountTextField`'s controller expects,
/// mirrored from `debt_transaction_tab.dart`'s "Trả hết" helper.
class NumberFormatUtil {
  static String grouped(num amount) => formatVND(amount).replaceAll('đ', '');
}
