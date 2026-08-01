import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/screen_neutrals.dart';
import '../../../core/theme/section_accents.dart';
import '../../../core/theme/visual_style_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/section_app_bar.dart';
import '../../../shared/widgets/sheet_drag_handle.dart';
import '../data/shift_repository.dart';
import '../domain/shift.dart';

/// Ca làm việc (Mục — "Shifts"). No punch-clock hardware needed: opening a
/// shift just snapshots every real-money vault's balance; closing it
/// snapshots again and the server derives income/expense-during-shift from
/// transactions created in that window (see ShiftsService doc comment).
class ShiftScreen extends ConsumerWidget {
  const ShiftScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentAsync = ref.watch(currentShiftProvider);
    final style = ref.watch(visualStyleProvider);
    final n = neutralsFor(style);
    final accent = sectionAccent(AppSection.shift, style);

    return Scaffold(
      backgroundColor: n.tint(accent),
      appBar: SectionAppBar(title: 'Ca làm việc', style: style),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentShiftProvider);
          ref.invalidate(shiftHistoryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            currentAsync.when(
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: n.isGame ? accent : null)),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Text('Không thể tải ca làm việc', style: TextStyle(color: n.textPrimary)),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: () => ref.invalidate(currentShiftProvider), child: const Text('Thử lại')),
                  ],
                ),
              ),
              data: (shift) => shift == null ? _NoOpenShiftCard(neutrals: n, accent: accent) : _OpenShiftCard(shift: shift, neutrals: n, accent: accent),
            ),
            const SizedBox(height: 24),
            Text('Lịch sử ca làm việc', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: n.textPrimary)),
            const SizedBox(height: 12),
            Consumer(
              builder: (context, ref, _) {
                final historyAsync = ref.watch(shiftHistoryProvider);
                return historyAsync.when(
                  loading: () => Center(child: CircularProgressIndicator(color: n.isGame ? accent : null)),
                  error: (error, _) => Text('Không thể tải lịch sử', style: TextStyle(color: n.textPrimary)),
                  data: (shifts) {
                    final closed = shifts.where((s) => !s.isOpen).toList();
                    if (closed.isEmpty) {
                      return EmptyStateWidget(icon: Icons.badge_outlined, message: 'Chưa có ca làm việc nào đã kết thúc.', accent: accent);
                    }
                    return Column(children: closed.map((s) => _ShiftHistoryTile(shift: s, neutrals: n)).toList());
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NoOpenShiftCard extends ConsumerWidget {
  final ScreenNeutrals neutrals;
  final Color accent;

  const _NoOpenShiftCard({required this.neutrals, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: neutrals.cardDecoration(radius: 16),
      child: Column(
        children: [
          Icon(Icons.badge_outlined, size: 40, color: neutrals.textSecondary),
          const SizedBox(height: 12),
          Text('Bạn chưa mở ca làm việc', style: TextStyle(fontWeight: FontWeight.w600, color: neutrals.textPrimary)),
          const SizedBox(height: 4),
          Text(
            'Mở ca để chốt số dư đầu ca, theo dõi thu/chi trong ca và chốt số dư cuối ca.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: neutrals.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: accent),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Mở ca làm việc'),
              onPressed: () => _openShift(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openShift(BuildContext context, WidgetRef ref) async {
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _NoteSheet(title: 'Mở ca làm việc', confirmLabel: 'Mở ca'),
    );
    if (note == null) return;
    try {
      final workspaceId = ref.read(currentWorkspaceIdProvider);
      await ref.read(shiftRepositoryProvider).open(workspaceId: workspaceId, note: note.isEmpty ? null : note);
      ref.invalidate(currentShiftProvider);
      ref.invalidate(shiftHistoryProvider);
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể mở ca làm việc';
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _OpenShiftCard extends ConsumerWidget {
  final Shift shift;
  final ScreenNeutrals neutrals;
  final Color accent;

  const _OpenShiftCard({required this.shift, required this.neutrals, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: neutrals.isGame ? [accent, Color.lerp(accent, Colors.black, 0.35)!] : AppColors.heroGradient(accent), begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: neutrals.isGame ? [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Ca làm việc đang mở', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Bắt đầu lúc ${DateFormat('HH:mm dd/MM/yyyy').format(shift.openedAt)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _StatColumn(label: 'Thu trong ca', value: formatVND(shift.incomeDuringShift))),
              Expanded(child: _StatColumn(label: 'Chi trong ca', value: formatVND(shift.expenseDuringShift))),
            ],
          ),
          const SizedBox(height: 8),
          Text('Chênh lệch ròng: ${formatVND(shift.netDuringShift)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 16),
          if (shift.openingSnapshot.isNotEmpty) ...[
            const Text('Số dư đầu ca', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...shift.openingSnapshot.map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(v.name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    Text(formatVND(v.balance), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: accent),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Kết thúc ca làm việc'),
              onPressed: () => _closeShift(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _closeShift(BuildContext context, WidgetRef ref) async {
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _NoteSheet(title: 'Kết thúc ca làm việc', confirmLabel: 'Kết thúc'),
    );
    if (note == null) return;
    try {
      final workspaceId = ref.read(currentWorkspaceIdProvider);
      await ref.read(shiftRepositoryProvider).close(workspaceId: workspaceId, shiftId: shift.id, note: note.isEmpty ? null : note);
      ref.invalidate(currentShiftProvider);
      ref.invalidate(shiftHistoryProvider);
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể kết thúc ca làm việc';
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}

class _ShiftHistoryTile extends StatelessWidget {
  final Shift shift;
  final ScreenNeutrals neutrals;

  const _ShiftHistoryTile({required this.shift, required this.neutrals});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: neutrals.cardDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${DateFormat('HH:mm dd/MM').format(shift.openedAt)} → ${shift.closedAt != null ? DateFormat('HH:mm dd/MM').format(shift.closedAt!) : ''}',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: neutrals.textPrimary),
                ),
              ),
              if (shift.userName != null && shift.userName!.isNotEmpty)
                Text(shift.userName!, style: TextStyle(fontSize: 11, color: neutrals.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Thu: ${formatVND(shift.incomeDuringShift)}', style: const TextStyle(fontSize: 12, color: AppColors.income)),
              Text('Chi: ${formatVND(shift.expenseDuringShift)}', style: const TextStyle(fontSize: 12, color: AppColors.expense)),
              Text('Ròng: ${formatVND(shift.netDuringShift)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: neutrals.textPrimary)),
            ],
          ),
          if (shift.note != null && shift.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(shift.note!, style: TextStyle(fontSize: 11, color: neutrals.textSecondary, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

class _NoteSheet extends StatefulWidget {
  final String title;
  final String confirmLabel;

  const _NoteSheet({required this.title, required this.confirmLabel});

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: SheetDragHandle()),
            const SizedBox(height: 8),
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(labelText: 'Ghi chú (không bắt buộc)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              maxLines: 2,
              maxLength: 500,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
              child: Text(widget.confirmLabel),
            ),
          ],
        ),
      ),
    );
  }
}
