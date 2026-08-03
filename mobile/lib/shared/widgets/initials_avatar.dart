import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Colored circle with the first 1-2 initials of [name] — used for customer
/// avatars (Công nợ) and the Dashboard greeting avatar. Color is derived
/// deterministically from [name] so the same person always gets the same
/// color. If [imageUrl] is set (Trang cá nhân's uploaded photo), shows that
/// instead — initials stay as the fallback while the image loads or if it
/// fails, rather than a jarring blank circle.
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final String? imageUrl;

  const InitialsAvatar({super.key, required this.name, this.radius = 22, this.imageUrl});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forKey(name.isEmpty ? '?' : name);
    final initialsCircle = CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(
        _initials,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: radius * 0.7),
      ),
    );
    if (imageUrl == null || imageUrl!.isEmpty) return initialsCircle;
    return ClipOval(
      child: Image.network(
        imageUrl!,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) => progress == null ? child : initialsCircle,
        errorBuilder: (context, error, stackTrace) => initialsCircle,
      ),
    );
  }
}
