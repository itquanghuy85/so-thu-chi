import 'package:flutter/material.dart';

import '../../core/theme/screen_neutrals.dart';
import '../../core/theme/visual_style_provider.dart';

/// A gradient `AppBar` built from the app's own primary/brand hue for the
/// current visual style — the same two-tone gradient on every screen
/// (Tổng quan, Giao dịch, Túi tiền, Công nợ, Báo cáo, ...), instead of each
/// tab carrying its own unrelated flat color. Compact, standard toolbar
/// height — no oversized bottom-rounded shape.
class SectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final AppVisualStyle style;
  final List<Widget>? actions;

  const SectionAppBar({super.key, required this.title, required this.style, this.actions});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: headerGradientFor(style), begin: Alignment.centerLeft, end: Alignment.centerRight),
        ),
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
