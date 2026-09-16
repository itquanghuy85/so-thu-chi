import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/presentation/auth_notifier.dart';
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
  DateTime? _lockoutUntil;
  int _lockoutRemaining = 0;
  bool _loggingOut = false;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
    _restoreLockoutState();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  /// Picks up a pending lockout (persisted in secure storage) when the
  /// lock screen is re-shown, so a restart can't bypass the freeze.
  Future<void> _restoreLockoutState() async {
    final until = await ref.read(appLockServiceProvider).pinLockoutUntil();
    if (!mounted) return;
    if (until != null && DateTime.now().isBefore(until)) {
      _lockoutUntil = until;
      _tickLockout();
    }
  }

  void _enterLockout(DateTime until) {
    _lockoutUntil = until;
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickLockout());
    _tickLockout();
    setState(() {
      _error = 'Quá nhiều lần nhập sai. Khoá tạm thời.';
      _entered = '';
    });
  }

  void _tickLockout() {
    final until = _lockoutUntil;
    if (until == null) return;
    final remaining = until.difference(DateTime.now()).inSeconds;
    if (!mounted) return;
    setState(() {
      _lockoutRemaining = remaining < 0 ? 0 : remaining;
      if (remaining <= 0) {
        _lockoutUntil = null;
        _lockoutTimer?.cancel();
      }
    });
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
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      setState(() {
        _error = _lockoutRemaining > 0 ? 'Thử lại sau $_lockoutRemaining giây' : 'Khoá tạm thời';
      });
      return;
    }
    if (_entered.length >= 6) return;
    setState(() {
      _entered += digit;
      _error = null;
    });
    if (_entered.length == 6) {
      final service = ref.read(appLockServiceProvider);
      final ok = await service.verifyPin(_entered);
      if (ok) {
        await service.resetFailedPinAttempts();
        ref.read(appLockNotifierProvider.notifier).unlock();
      } else {
        await service.registerFailedPinAttempt();
        final lockoutSync = await service.pinLockoutUntil();
        if (mounted) {
          if (lockoutSync != null && DateTime.now().isBefore(lockoutSync)) {
            _enterLockout(lockoutSync);
          } else {
            final remaining = AppLockService.maxPinAttempts - await service.failedPinAttempts();
            setState(() {
              _error = remaining > 0 ? 'Sai mã PIN. Còn $remaining lần thử.' : 'Sai mã PIN';
              _entered = '';
            });
          }
        }
      }
    }
  }

  Future<void> _onLogout() async {
    final service = ref.read(appLockServiceProvider);
    final action = await showDialog<_LogoutAction>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text(
          'Quên mã PIN?\n\nĐăng xuất sẽ đưa bạn về màn hình đăng nhập. Khi đăng nhập lại, mã PIN trên thiết bị này sẽ được xoá và bạn có thể thiết lập mã mới.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_LogoutAction.logoutOnly),
            child: const Text('Đăng xuất'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_LogoutAction.forgotPin),
            child: const Text('Quên PIN, đặt lại'),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    if (action == _LogoutAction.forgotPin) {
      await service.clearPin();
      await ref.read(appLockNotifierProvider.notifier).refreshPinConfigured();
    }
    await service.resetFailedPinAttempts();
    await ref.read(authNotifierProvider.notifier).logout();
    if (mounted) {
      setState(() => _loggingOut = true);
      ref.read(appLockNotifierProvider.notifier).unlock();
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
              _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)
                  ? 'Khoá tạm thời. Thử lại sau $_lockoutRemaining giây'
                  : (_error ?? ' '),
              textAlign: TextAlign.center,
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
            TextButton(
              onPressed: _loggingOut ? null : _onLogout,
              style: TextButton.styleFrom(foregroundColor: Colors.white70, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              child: _loggingOut
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
                  : const Text('Quên mã PIN? Đăng xuất'),
            ),
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

enum _LogoutAction { logoutOnly, forgotPin }
