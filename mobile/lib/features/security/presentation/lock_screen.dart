import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../data/app_lock_service.dart';
import 'app_lock_notifier.dart';

/// Full-screen PIN pad shown by [AppLockGate] when the app is locked
/// (Mục 14). Also offers a fingerprint/Face ID button when biometric
/// unlock is enabled, auto-prompting once when the screen appears.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _entered = '';
  String? _error;
  bool _biometricAvailable = false;
  bool _biometricTried = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final service = ref.read(appLockServiceProvider);
    final enabled = await service.isBiometricEnabled();
    final available = enabled && await service.isBiometricAvailable();
    if (mounted) setState(() => _biometricAvailable = available);
    if (available && !_biometricTried) {
      _biometricTried = true;
      _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    final ok = await ref.read(appLockServiceProvider).authenticateWithBiometrics();
    if (ok && mounted) ref.read(appLockNotifierProvider.notifier).unlock();
  }

  Future<void> _onDigit(String digit) async {
    if (_entered.length >= 6) return;
    setState(() {
      _entered += digit;
      _error = null;
    });
    if (_entered.length == 6) {
      final ok = await ref.read(appLockServiceProvider).verifyPin(_entered);
      if (ok) {
        ref.read(appLockNotifierProvider.notifier).unlock();
      } else {
        setState(() {
          _error = 'Sai mã PIN';
          _entered = '';
        });
      }
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryDark,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), shape: BoxShape.circle),
              child: const Icon(Icons.lock_outline, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 16),
            const Text('Nhập mã PIN', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              _error ?? ' ',
              style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) {
                final filled = i < _entered.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? Colors.white : Colors.transparent,
                    border: Border.all(color: Colors.white70),
                  ),
                );
              }),
            ),
            const Spacer(),
            SizedBox(
              width: 280,
              child: Column(
                children: [
                  for (final row in [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: row.map((d) => _DigitButton(digit: d, onTap: () => _onDigit(d))).toList(),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: _biometricAvailable
                              ? IconButton(
                                  icon: const Icon(Icons.fingerprint, color: Colors.white, size: 30),
                                  onPressed: _tryBiometric,
                                )
                              : null,
                        ),
                        _DigitButton(digit: '0', onTap: () => _onDigit('0')),
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: IconButton(
                            icon: const Icon(Icons.backspace_outlined, color: Colors.white70, size: 22),
                            onPressed: _onBackspace,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _DigitButton extends StatelessWidget {
  final String digit;
  final VoidCallback onTap;

  const _DigitButton({required this.digit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
        child: Text(digit, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
