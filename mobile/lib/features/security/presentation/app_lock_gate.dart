import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_notifier.dart';
import 'app_lock_notifier.dart';
import 'lock_screen.dart';

/// Wraps the whole app (via `MaterialApp.router`'s `builder`) and shows
/// [LockScreen] on top of everything when [AppLockNotifier] says the app is
/// locked — tracks background/foreground transitions itself via
/// `WidgetsBindingObserver` (Mục 14).
class AppLockGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> with WidgetsBindingObserver {
  bool _lockedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(appLockNotifierProvider.notifier);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      notifier.onAppBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      notifier.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authStatus = ref.watch(authNotifierProvider).status;
    final lockState = ref.watch(appLockNotifierProvider);

    // Re-arm the lock on every fresh login, not just cold-start: while no
    // one is logged in we drop the one-shot flag (and clear any stale
    // locked state) so the next authenticated session locks again instead
    // of booting straight in unlocked (Mục 14).
    if (authStatus != AuthStatus.authenticated) {
      _lockedOnce = false;
      if (lockState.locked) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(appLockNotifierProvider.notifier).unlock();
        });
      }
    }

    // Arm the lock exactly once per session, right after the user is
    // confirmed authenticated (covers "app relaunched from scratch with a
    // PIN already set" — not just backgrounding, and re-login in the same
    // run). Also syncs this account's PIN status from the server first, so
    // a device that hasn't set its own PIN yet still locks if another
    // device on the same account already has one configured (Mục — "hai
    // máy cùng đăng nhập 1 tài khoản").
    if (authStatus == AuthStatus.authenticated && !_lockedOnce) {
      _lockedOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final notifier = ref.read(appLockNotifierProvider.notifier);
        await notifier.syncFromServerThenRefresh();
        notifier.lockIfConfigured();
      });
    }

    final showLock = authStatus == AuthStatus.authenticated && lockState.locked;

    return Stack(
      children: [
        widget.child,
        if (showLock) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}
