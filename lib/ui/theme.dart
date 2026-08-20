import 'package:flutter/material.dart';

class AppTheme {
  // Backgrounds & Surfaces
  static Color background = const Color(0xFF0B0C14);
  static const Color surface = Color(0xFF141622);
  static const Color surfaceLight = Color(0xFF1F2235);
  static const Color card = Color(0xFF1A1C2B);
  static const Color cardBorder = Color(0x1FFFFFFF);

  // Neon Accents (dynamic — переключаются палитрой)
  static Color accent = const Color(0xFFA855F7); // Electric Violet
  static Color accentLight = const Color(0xFFC084FC);
  static Color accentCyan = const Color(0xFF06B6D4); // Neon Cyan
  static Color accentPink = const Color(0xFFEC4899); // Hot Pink
  static Color accentGreen = const Color(0xFF10B981); // Emerald
  static Color accentAmber = const Color(0xFFF59E0B);

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Gradients (динамические — пересобираются из акцентов)
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

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1D2032), Color(0xFF141624)],
  );

  static const LinearGradient miniPlayerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xE61E2135), Color(0xF5131522)],
  );

  /// Применяет палитру ко всем стилям приложения.
  static void applyPalette({
    required Color background,
    required Color accent,
    required Color accentLight,
    required Color accentCyan,
    required Color accentPink,
    required Color accentGreen,
    required Color accentAmber,
  }) {
    AppTheme.background = background;
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

  /// Возвращает палитру по умолчанию.
  static void resetPalette() {
    applyPalette(
      background: const Color(0xFF0B0C14),
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
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        primaryColor: accent,
        canvasColor: background,
        colorScheme: ColorScheme.dark(
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
            side: const BorderSide(color: cardBorder, width: 0.8),
          ),
        ),
        textTheme: const TextTheme(
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
        iconTheme: const IconThemeData(color: textPrimary),
      );
}