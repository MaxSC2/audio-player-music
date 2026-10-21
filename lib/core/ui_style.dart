import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'debug_log.dart';
import 'rescue_store.dart';

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
  UiStyleController({
    Future<SharedPreferences>? prefsFuture,
    RescueStore? rescue,
  }) : _prefsFuture = prefsFuture,
       _rescue = rescue;

  final Future<SharedPreferences>? _prefsFuture;
  final RescueStore? _rescue;

  static const _prefsKey = 'ui_style';
  static const _cinematicPrefsKey = 'cinematic_theme';

  PlayerUIStyle _style = PlayerUIStyle.simple;
  CinematicThemeMode _cinematicTheme = CinematicThemeMode.auto;
  SharedPreferences? _prefs;
  bool _styleTouched = false;
  bool _themeTouched = false;

  PlayerUIStyle get style => _style;
  CinematicThemeMode get cinematicTheme => _cinematicTheme;

  /// Итоговые цвета cinematic-атмосферы: Auto — из обложки, иначе фикс.
  List<Color> resolveCinematic(List<Color> artwork) {
    if (_cinematicTheme == CinematicThemeMode.auto) return artwork;
    return cinematicThemeColors[_cinematicTheme]!;
  }

  Future<void> init() async {
    final rescue = _rescue;
    if (rescue != null) await rescue.ready;

    final rescueStyle = rescue != null && rescue.use(_prefsKey)
        ? rescue.get(_prefsKey)
        : null;
    final rescueTheme = rescue != null && rescue.use(_cinematicPrefsKey)
        ? rescue.get(_cinematicPrefsKey)
        : null;
    if (!_styleTouched && rescueStyle is String) {
      try {
        _style = PlayerUIStyle.values.byName(rescueStyle);
      } catch (_) {
        _style = PlayerUIStyle.simple;
      }
    }
    if (!_themeTouched && rescueTheme is String) {
      try {
        _cinematicTheme = CinematicThemeMode.values.byName(rescueTheme);
      } catch (_) {
        _cinematicTheme = CinematicThemeMode.auto;
      }
    }

    try {
      _prefs = await (_prefsFuture ?? SharedPreferences.getInstance()).timeout(
        const Duration(seconds: 2),
      );
    } on TimeoutException {
      _prefs = null;
      DebugLog.log('uiStyle: prefs таймаут');
    } catch (_) {
      _prefs = null;
    }

    if (!_styleTouched && rescueStyle == null) {
      final saved = _prefs?.get(_prefsKey);
      if (saved is String) {
        try {
          _style = PlayerUIStyle.values.byName(saved);
        } catch (_) {
          _style = PlayerUIStyle.simple;
        }
      }
    }
    if (!_themeTouched && rescueTheme == null) {
      final saved = _prefs?.get(_cinematicPrefsKey);
      if (saved is String) {
        try {
          _cinematicTheme = CinematicThemeMode.values.byName(saved);
        } catch (_) {
          _cinematicTheme = CinematicThemeMode.auto;
        }
      }
    }
    if (_styleTouched) {
      try {
        await _prefs?.setString(_prefsKey, _style.name);
      } catch (_) {}
      rescue?.set(_prefsKey, _style.name);
    }
    if (_themeTouched) {
      try {
        await _prefs?.setString(_cinematicPrefsKey, _cinematicTheme.name);
      } catch (_) {}
      rescue?.set(_cinematicPrefsKey, _cinematicTheme.name);
    }
    notifyListeners();
  }

  Future<void> setStyle(PlayerUIStyle value) async {
    if (_style == value) return;
    _style = value;
    _styleTouched = true;
    notifyListeners();
    try {
      await _prefs?.setString(_prefsKey, value.name);
    } catch (_) {}
    _rescue?.set(_prefsKey, value.name);
  }

  Future<void> setCinematicTheme(CinematicThemeMode value) async {
    if (_cinematicTheme == value) return;
    _cinematicTheme = value;
    _themeTouched = true;
    notifyListeners();
    try {
      await _prefs?.setString(_cinematicPrefsKey, value.name);
    } catch (_) {}
    _rescue?.set(_cinematicPrefsKey, value.name);
  }

  void toggle() {
    const values = PlayerUIStyle.values;
    final next = values[(_style.index + 1) % values.length];
    setStyle(next);
  }
}
