import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PlayerUIStyle { simple, coverFlow3D, cinematic, neon }

/// Фиксированные темы Cinematic + Auto (цвета из обложки).
enum CinematicThemeMode { auto, crimson, ocean, emerald, violet, mono }

/// Фиксированные пары [primary, secondary] для тем Cinematic.
const Map<CinematicThemeMode, List<Color>> cinematicThemeColors = {
  CinematicThemeMode.crimson: [Color(0xFFF43F5E), Color(0xFF7F1D1D)],
  CinematicThemeMode.ocean: [Color(0xFF38BDF8), Color(0xFF0C4A6E)],
  CinematicThemeMode.emerald: [Color(0xFF34D399), Color(0xFF065F46)],
  CinematicThemeMode.violet: [Color(0xFFA855F7), Color(0xFF581C87)],
  CinematicThemeMode.mono: [Color(0xFF9CA3AF), Color(0xFF4B5563)],
};

const Map<CinematicThemeMode, String> cinematicThemeNames = {
  CinematicThemeMode.auto: 'Авто',
  CinematicThemeMode.crimson: 'Crimson',
  CinematicThemeMode.ocean: 'Ocean',
  CinematicThemeMode.emerald: 'Emerald',
  CinematicThemeMode.violet: 'Violet',
  CinematicThemeMode.mono: 'Mono',
};

class UiStyleController extends ChangeNotifier {
  static const _prefsKey = 'ui_style';
  static const _cinematicPrefsKey = 'cinematic_theme';

  PlayerUIStyle _style = PlayerUIStyle.simple;
  CinematicThemeMode _cinematicTheme = CinematicThemeMode.auto;
  SharedPreferences? _prefs;

  PlayerUIStyle get style => _style;
  CinematicThemeMode get cinematicTheme => _cinematicTheme;

  /// Итоговые цвета cinematic-атмосферы: Auto — из обложки, иначе фикс.
  List<Color> resolveCinematic(List<Color> artwork) {
    if (_cinematicTheme == CinematicThemeMode.auto) return artwork;
    return cinematicThemeColors[_cinematicTheme]!;
  }

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
      try {
        final savedTheme = _prefs?.getString(_cinematicPrefsKey);
        _cinematicTheme = savedTheme == null
            ? CinematicThemeMode.auto
            : CinematicThemeMode.values.byName(savedTheme);
      } catch (_) {
        _cinematicTheme = CinematicThemeMode.auto;
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

  Future<void> setCinematicTheme(CinematicThemeMode value) async {
    if (_cinematicTheme == value) return;
    _cinematicTheme = value;
    notifyListeners();
    await _prefs?.setString(_cinematicPrefsKey, value.name);
  }

  void toggle() {
    const values = PlayerUIStyle.values;
    final next = values[(_style.index + 1) % values.length];
    setStyle(next);
  }
}
