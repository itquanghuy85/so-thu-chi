import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offline/app_database.dart';
import '../../core/theme/screen_neutrals.dart';
import '../../core/theme/visual_style_provider.dart';
import '../providers/current_workspace_provider.dart';

/// A horizontal row of tap-to-fill chips sourced from this device's past
/// entries for [fieldKey] (Mục — "nhập nhanh theo lịch sử"): as the user
/// types, chips narrow to past values that start the same way; tapping one
/// fills [controller] instantly instead of retyping something like "Bán
/// rau" or a price that recurs every day. Purely local (see
/// `AppDatabase`'s field_history table doc comment) — this widget only
/// *reads* history; call [FieldHistory.record] from the owning form's save
/// handler to grow it.
class FieldSuggestionChips extends ConsumerStatefulWidget {
  final String fieldKey;
  final TextEditingController controller;
  final Color accent;

  const FieldSuggestionChips({super.key, required this.fieldKey, required this.controller, required this.accent});

  @override
  ConsumerState<FieldSuggestionChips> createState() => _FieldSuggestionChipsState();
}

class _FieldSuggestionChipsState extends ConsumerState<FieldSuggestionChips> {
  List<String> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final workspaceId = ref.read(currentWorkspaceIdProvider);
    final results = await AppDatabase.instance.getFieldSuggestions(
      workspaceId: workspaceId,
      fieldKey: widget.fieldKey,
      prefix: widget.controller.text,
    );
    final filtered = results.where((s) => s != widget.controller.text).toList();
    if (mounted) setState(() => _suggestions = filtered);
  }

  @override
  Widget build(BuildContext context) {
    if (_suggestions.isEmpty) return const SizedBox.shrink();
    final n = neutralsFor(ref.watch(visualStyleProvider));
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _suggestions.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (context, i) {
            final value = _suggestions[i];
            return ActionChip(
              label: Text(value, style: TextStyle(fontSize: 12, color: n.textPrimary)),
              backgroundColor: n.surface,
              side: BorderSide(color: widget.accent.withValues(alpha: 0.35)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onPressed: () {
                widget.controller.value = TextEditingValue(
                  text: value,
                  selection: TextSelection.collapsed(offset: value.length),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Call from a form's successful-save handler to grow the suggestion pool
/// for [fieldKey] — safe (a no-op) for blank values. Both free-text (note)
/// and formatted-numeric (amount, stored exactly as the field displayed
/// it) values work the same way.
class FieldHistory {
  FieldHistory._();

  static Future<void> record({required String workspaceId, required String fieldKey, required String value}) {
    return AppDatabase.instance.recordFieldValue(workspaceId: workspaceId, fieldKey: fieldKey, value: value);
  }
}
