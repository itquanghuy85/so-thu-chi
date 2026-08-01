import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Mục 12.1: shown briefly while [AuthNotifier] restores/validates the
/// session; the router redirect (app.dart) then sends the user to Login,
/// the Workspace Picker, or straight into the app shell.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.headerGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.savings_rounded, size: 52, color: Colors.white),
              ),
              const SizedBox(height: 18),
              const Text(
                'Sổ Thu Chi',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Quản lý dòng tiền dễ dàng',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
              ),
              const SizedBox(height: 36),
              const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
