import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/secure_storage_keys.dart';
import '../../shared/providers/secure_storage_provider.dart';

/// The three visual skins the app can render in: `classic` (default
/// finance-app look), `gameLeon` (Mục 16.2 — dark arcade skin built around
/// a hand-painted Leon mascot), and `dark` (a professional dark mode: same
/// brand accent colors as Classic, just dark neutrals, no mascot/glow
/// effects). All three apply app-wide — every screen branches on this
/// value rather than any one skin being scoped to a subset of screens.
enum AppVisualStyle { classic, gameLeon, dark }

class VisualStyleNotifier extends StateNotifier<AppVisualStyle> {
  final FlutterSecureStorage _secureStorage;

  VisualStyleNotifier(this._secureStorage) : super(AppVisualStyle.classic) {
    _restore();
  }

  Future<void> _restore() async {
    final saved = await _secureStorage.read(key: SecureStorageKeys.visualStyle);
    for (final style in AppVisualStyle.values) {
      if (saved == style.name) {
        state = style;
        break;
      }
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
