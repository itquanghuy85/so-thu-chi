import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_lock_service.dart';

/// Re-locks the app after it's been backgrounded for 5+ minutes (Mục 14:
/// "Khi app vào nền và mở lại sau 5 phút, yêu cầu xác thực"), if a PIN has
/// been set. [AppLockGate] (in app.dart) drives this via
/// `WidgetsBindingObserver` lifecycle callbacks.
class AppLockState {
  final bool locked;
  final bool pinConfigured;

  const AppLockState({this.locked = false, this.pinConfigured = false});

  AppLockState copyWith({bool? locked, bool? pinConfigured}) {
    return AppLockState(
      locked: locked ?? this.locked,
      pinConfigured: pinConfigured ?? this.pinConfigured,
    );
  }
}

class AppLockNotifier extends StateNotifier<AppLockState> {
  final AppLockService _service;
  static const _backgroundThreshold = Duration(minutes: 5);

  DateTime? _backgroundedAt;

  AppLockNotifier(this._service) : super(const AppLockState()) {
    _refreshPinConfigured();
  }

  Future<void> _refreshPinConfigured() async {
    final hasPin = await _service.hasPin();
    state = state.copyWith(pinConfigured: hasPin);
  }

  /// Call after enabling/disabling the PIN in Settings.
  Future<void> refreshPinConfigured() => _refreshPinConfigured();

  void onAppBackgrounded() {
    _backgroundedAt = DateTime.now();
  }

  /// Call when the app resumes; locks (if a PIN is set and the threshold
  /// elapsed) or clears the background timestamp.
  void onAppResumed() {
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (!state.pinConfigured || backgroundedAt == null) return;
    if (DateTime.now().difference(backgroundedAt) >= _backgroundThreshold) {
      state = state.copyWith(locked: true);
    }
  }

  /// Call once right after login/session-restore, so a fresh app launch
  /// with a configured PIN starts locked too.
  void lockIfConfigured() {
    if (state.pinConfigured) state = state.copyWith(locked: true);
  }

  void unlock() {
    state = state.copyWith(locked: false);
  }
}

final appLockNotifierProvider = StateNotifierProvider<AppLockNotifier, AppLockState>((ref) {
  return AppLockNotifier(ref.watch(appLockServiceProvider));
});
