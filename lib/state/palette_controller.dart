import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/theme.dart';

class PaletteColors {
  final Color background;
  final Color accent;
  final Color accentLight;
  final Color accentCyan;
  final Color accentPink;
  final Color accentGreen;
  final Color accentAmber;

  const PaletteColors({
    required this.background,
    required this.accent,
    required this.accentLight,
    required this.accentCyan,
    required this.accentPink,
    required this.accentGreen,
    required this.accentAmber,
  });

  PaletteColors copyWith({Color? background, Color? accent, Color? accentCyan,
          Color? accentPink, Color? accentGreen, Color? accentAmber}) =>
      PaletteColors(
        background: background ?? this.background,
        accent: accent ?? this.accent,
        accentLight: _lighten(accent ?? this.accent),
        accentCyan: accentCyan ?? this.accentCyan,
        accentPink: accentPink ?? this.accentPink,
        accentGreen: accentGreen ?? this.accentGreen,
        accentAmber: accentAmber ?? this.accentAmber,
      );

  static Color _lighten(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness * 1.4).clamp(0.0, 1.0))
        .toColor();
  }

  String encode() => [
        background.value,
        accent.value,
        accentLight.value,
        accentCyan.value,
        accentPink.value,
        accentGreen.value,
        accentAmber.value,
      ].join(',');

  static PaletteColors decode(String raw) {
    final parts = raw.split(',');
    Color c(int i) => Color(int.tryParse(parts[i]) ?? 0);
    return PaletteColors(
      background: c(0),
      accent: c(1),
      accentLight: c(2),
      accentCyan: c(3),
      accentPink: c(4),
      accentGreen: c(5),
      accentAmber: c(6),
    );
  }
}

class PaletteController extends ChangeNotifier {
  static const _modeKey = 'palette_mode';
  static const _customKey = 'palette_custom';

  static const List<PaletteColors> presets = [
    // Neon — по умолчанию
    PaletteColors(
      background: Color(0xFF0B0C14),
      accent: Color(0xFFA855F7),
      accentLight: Color(0xFFC084FC),
      accentCyan: Color(0xFF06B6D4),
      accentPink: Color(0xFFEC4899),
      accentGreen: Color(0xFF10B981),
      accentAmber: Color(0xFFF59E0B),
    ),
    // Киберпанк
    PaletteColors(
      background: Color(0xFF0E0817),
      accent: Color(0xFFF472B6),
      accentLight: Color(0xFFF9A8D4),
      accentCyan: Color(0xFF22D3EE),
      accentPink: Color(0xFFFB7185),
      accentGreen: Color(0xFF34D399),
      accentAmber: Color(0xFFFBBF24),
    ),
    // Океан
    PaletteColors(
      background: Color(0xFF060D1A),
      accent: Color(0xFF3B82F6),
      accentLight: Color(0xFF60A5FA),
      accentCyan: Color(0xFF2DD4BF),
      accentPink: Color(0xFFF472B6),
      accentGreen: Color(0xFF34D399),
      accentAmber: Color(0xFFFACC15),
    ),
    // Закат
    PaletteColors(
      background: Color(0xFF150A08),
      accent: Color(0xFFF97316),
      accentLight: Color(0xFFFDBA74),
      accentCyan: Color(0xFF38BDF8),
      accentPink: Color(0xFFF43F5E),
      accentGreen: Color(0xFF4ADE80),
      accentAmber: Color(0xFFFBBF24),
    ),
    // Мята
    PaletteColors(
      background: Color(0xFF06130E),
      accent: Color(0xFF10B981),
      accentLight: Color(0xFF34D399),
      accentCyan: Color(0xFF14B8A6),
      accentPink: Color(0xFFEC4899),
      accentGreen: Color(0xFF4ADE80),
      accentAmber: Color(0xFFF59E0B),
    ),
  ];

  static const List<String> presetNames = [
    'Neon',
    'Киберпанк',
    'Океан',
    'Закат',
    'Мята',
  ];

  SharedPreferences? _prefs;
  int _index = 0; // -1 = своя палитра
  PaletteColors? _custom;

  int get index => _index;
  bool get isCustom => _index < 0;
  PaletteColors get active =>
      isCustom ? (_custom ?? presets.first) : presets[_index];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _index = _prefs?.getInt(_modeKey) ?? 0;
    final raw = _prefs?.getString(_customKey);
    if (raw != null && raw.isNotEmpty) {
      _custom = PaletteColors.decode(raw);
    }
    _apply();
  }

  void select(int i) {
    _index = i;
    _persist();
    _apply();
  }

  /// Редактирование слота своей палитры. [color] применяется к конкретному
  /// слоту, остальные берутся из текущей активной палитры.
  void editSlot({Color? background, Color? accent, Color? accentCyan,
          Color? accentPink, Color? accentGreen, Color? accentAmber}) {
    if (_custom == null) _custom = active;
    _custom = _custom!.copyWith(
      background: background,
      accent: accent,
      accentCyan: accentCyan,
      accentPink: accentPink,
      accentGreen: accentGreen,
      accentAmber: accentAmber,
    );
    _index = -1;
    _persist();
    _apply();
  }

  void resetCustom() {
    _custom = null;
    _index = 0;
    _persist();
    _apply();
  }

  void _persist() {
    _prefs?.setInt(_modeKey, _index);
    if (_custom != null) {
      _prefs?.setString(_customKey, _custom!.encode());
    } else {
      _prefs?.remove(_customKey);
    }
  }

  void _apply() {
    final p = active;
    AppTheme.applyPalette(
      background: p.background,
      accent: p.accent,
      accentLight: p.accentLight,
      accentCyan: p.accentCyan,
      accentPink: p.accentPink,
      accentGreen: p.accentGreen,
      accentAmber: p.accentAmber,
    );
    notifyListeners();
  }
}