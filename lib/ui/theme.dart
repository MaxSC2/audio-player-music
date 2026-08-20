import 'package:flutter/material.dart';

class AppTheme {
  // Backgrounds & Surfaces (dynamic — переключаются режимом/палитрой)
  static Color background = const Color(0xFF0B0C14);
  static Color surface = const Color(0xFF141622);
  static Color surfaceLight = const Color(0xFF1F2235);
  static Color card = const Color(0xFF1A1C2B);
  static Color cardBorder = const Color(0x1FFFFFFF);

  // Neon Accents (dynamic — переключаются палитрой)
  static Color accent = const Color(0xFFA855F7);
  static Color accentLight = const Color(0xFFC084FC);
  static Color accentCyan = const Color(0xFF06B6D4);
  static Color accentPink = const Color(0xFFEC4899);
  static Color accentGreen = const Color(0xFF10B981);
  static Color accentAmber = const Color(0xFFF59E0B);

  // Text Colors (dynamic — переключаются режимом)
  static Color textPrimary = const Color(0xFFF8FAFC);
  static Color textSecondary = const Color(0xFF94A3B8);
  static Color textMuted = const Color(0xFF64748B);

  // Gradients (динамические)
  static LinearGradient primaryGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA855F7), Color(0xFF06B6D4)],
  );

  static LinearGradient pinkPurpleGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEC4899), Color(0xFFA855F7)],
  );

  static LinearGradient cyanGreenGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF06B6D4), Color(0xFF10B981)],
  );

  static LinearGradient cardGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1D2032), Color(0xFF141624)],
  );

  static LinearGradient miniPlayerGradient = const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xE61E2135), Color(0xF5131522)],
  );

  /// Применяет акцентные цвета палитры.
  static void applyAccents({
    required Color accent,
    required Color accentLight,
    required Color accentCyan,
    required Color accentPink,
    required Color accentGreen,
    required Color accentAmber,
  }) {
    AppTheme.accent = accent;
    AppTheme.accentLight = accentLight;
    AppTheme.accentCyan = accentCyan;
    AppTheme.accentPink = accentPink;
    AppTheme.accentGreen = accentGreen;
    AppTheme.accentAmber = accentAmber;
    AppTheme.primaryGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [accent, accentCyan],
    );
    AppTheme.pinkPurpleGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [accentPink, accent],
    );
    AppTheme.cyanGreenGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [accentCyan, accentGreen],
    );
  }

  /// Применяет фоновый цвет (слот палитры «Фон»; только для тёмного режима).
  static void applyBackground(Color color) {
    AppTheme.background = color;
  }

  static bool _light = false;
  static bool get lightMode => _light;

  /// Переключает режим: тёмный (default) или светлый.
  static void applyMode({required bool light}) {
    _light = light;
    if (light) {
      background = const Color(0xFFF2F4FA);
      surface = const Color(0xFFFFFFFF);
      surfaceLight = const Color(0xFFE7EBF3);
      card = const Color(0xFFFFFFFF);
      cardBorder = const Color(0x140B1020);
      textPrimary = const Color(0xFF0F172A);
      textSecondary = const Color(0xFF475569);
      textMuted = const Color(0xFF94A3B8);
      cardGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFFFF), Color(0xFFEFF2F8)],
      );
      miniPlayerGradient = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFFFF), Color(0xFFE6EAF2)],
      );
    } else {
      background = const Color(0xFF0B0C14);
      surface = const Color(0xFF141622);
      surfaceLight = const Color(0xFF1F2235);
      card = const Color(0xFF1A1C2B);
      cardBorder = const Color(0x1FFFFFFF);
      textPrimary = const Color(0xFFF8FAFC);
      textSecondary = const Color(0xFF94A3B8);
      textMuted = const Color(0xFF64748B);
      cardGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1D2032), Color(0xFF141624)],
      );
      miniPlayerGradient = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xE61E2135), Color(0xF5131522)],
      );
    }
  }

  /// Возвращает палитру по умолчанию.
  static void resetPalette() {
    applyAccents(
      accent: const Color(0xFFA855F7),
      accentLight: const Color(0xFFC084FC),
      accentCyan: const Color(0xFF06B6D4),
      accentPink: const Color(0xFFEC4899),
      accentGreen: const Color(0xFF10B981),
      accentAmber: const Color(0xFFF59E0B),
    );
  }

  // ThemeData
  static ThemeData get dark => ThemeData(
        brightness: lightMode ? Brightness.light : Brightness.dark,
        scaffoldBackgroundColor: background,
        primaryColor: accent,
        canvasColor: background,
        colorScheme: lightMode
            ? ColorScheme.light(
                primary: accent,
                secondary: accentCyan,
                surface: card,
                error: accentPink,
              )
            : ColorScheme.dark(
                primary: accent,
                secondary: accentCyan,
                surface: card,
                error: accentPink,
              ),
        appBarTheme: AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          iconTheme: IconThemeData(color: textPrimary),
        ),
        cardTheme: CardThemeData(
          color: card,
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cardBorder, width: 0.8),
          ),
        ),
        textTheme: TextTheme(
          titleLarge: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          bodyMedium: TextStyle(
            color: textSecondary,
            fontSize: 14,
          ),
          bodySmall: TextStyle(
            color: textMuted,
            fontSize: 12,
          ),
        ),
        sliderTheme: SliderThemeData(
          trackHeight: 4.0,
          activeTrackColor: accent,
          inactiveTrackColor: surfaceLight,
          thumbColor: textPrimary,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
          overlayColor: accent.withOpacity(0.25),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
        ),
        iconTheme: IconThemeData(color: textPrimary),
      );
}