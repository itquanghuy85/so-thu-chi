import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/secure_storage_keys.dart';
import '../../shared/providers/secure_storage_provider.dart';

/// The two visual skins the app can render in (Mục 16.2 "Game Leon"):
/// `classic` is the finance-app look used everywhere by default, `gameLeon`
/// swaps the Dashboard, bottom nav, and Thành tích screen for a dark
/// arcade-style skin built around a hand-painted (CustomPainter) Leon
/// mascot. Every other screen (forms, lists, settings) intentionally stays
/// Classic regardless of this setting — reskinning dense data/entry screens
/// in a game style would hurt usability for a bookkeeping app, so the game
/// skin is scoped to the screens that are actually meant to feel playful.
enum AppVisualStyle { classic, gameLeon }

class VisualStyleNotifier extends StateNotifier<AppVisualStyle> {
  final FlutterSecureStorage _secureStorage;

  VisualStyleNotifier(this._secureStorage) : super(AppVisualStyle.classic) {
    _restore();
  }

  Future<void> _restore() async {
    final saved = await _secureStorage.read(key: SecureStorageKeys.visualStyle);
    if (saved == AppVisualStyle.gameLeon.name) {
      state = AppVisualStyle.gameLeon;
    }
  }

  Future<void> setStyle(AppVisualStyle style) async {
    state = style;
    await _secureStorage.write(key: SecureStorageKeys.visualStyle, value: style.name);
  }
}

final visualStyleProvider = StateNotifierProvider<VisualStyleNotifier, AppVisualStyle>((ref) {
  return VisualStyleNotifier(ref.watch(secureStorageProvider));
});
