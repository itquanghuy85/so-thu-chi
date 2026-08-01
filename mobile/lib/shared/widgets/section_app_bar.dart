import 'package:flutter/material.dart';

/// A solid-color `AppBar` tinted to a bottom-nav tab's own accent (Mục 12:
/// each of the 5 main tabs — Tổng quan/Giao dịch/Túi tiền/Công nợ/Báo cáo —
/// has its own color, matching `MainShellScreen`'s `_navItems` and that
/// screen's own hero card/summary tiles), instead of every screen sharing
/// the same neutral default `AppBarTheme` from `app.dart`.
class SectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Color accent;
  final List<Widget>? actions;

  const SectionAppBar({super.key, required this.title, required this.accent, this.actions});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: accent,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
