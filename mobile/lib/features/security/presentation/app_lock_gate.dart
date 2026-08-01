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

    // Arm the lock exactly once per cold-start session, right after the
    // user is confirmed authenticated (covers "app relaunched from
    // scratch with a PIN already set" — not just backgrounding).
    if (authStatus == AuthStatus.authenticated && lockState.pinConfigured && !_lockedOnce) {
      _lockedOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(appLockNotifierProvider.notifier).lockIfConfigured();
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
