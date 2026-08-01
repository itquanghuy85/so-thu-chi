import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Colored circle with the first 1-2 initials of [name] — used for customer
/// avatars (Công nợ) and the Dashboard greeting avatar. Color is derived
/// deterministically from [name] so the same person always gets the same
/// color.
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double radius;

  const InitialsAvatar({super.key, required this.name, this.radius = 22});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forKey(name.isEmpty ? '?' : name);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(
        _initials,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: radius * 0.7),
      ),
    );
  }
}
