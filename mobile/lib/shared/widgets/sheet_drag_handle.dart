import 'package:flutter/material.dart';

/// Small grey pill shown at the top of every bottom sheet in the app, for a
/// consistent "draggable sheet" affordance (same visual used by
/// CreateTransactionSheet).
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
