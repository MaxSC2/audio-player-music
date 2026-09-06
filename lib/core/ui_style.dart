import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PlayerUIStyle { simple, coverFlow3D, cinematic }

class UiStyleController extends ChangeNotifier {
  static const _prefsKey = 'ui_style';

  PlayerUIStyle _style = PlayerUIStyle.simple;
  SharedPreferences? _prefs;

  PlayerUIStyle get style => _style;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final saved = _prefs?.getString(_prefsKey);
      try {
        _style = saved == null
            ? PlayerUIStyle.simple
            : PlayerUIStyle.values.byName(saved);
      } catch (_) {
        _style = PlayerUIStyle.simple;
      }
      notifyListeners();
    } catch (_) {
      _style = PlayerUIStyle.simple;
    }
  }

  Future<void> setStyle(PlayerUIStyle value) async {
    if (_style == value) return;
    _style = value;
    notifyListeners();
    await _prefs?.setString(_prefsKey, value.name);
  }

  void toggle() {
    const values = PlayerUIStyle.values;
    final next = values[(_style.index + 1) % values.length];
    setStyle(next);
  }
}
