import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF121212);
  static const Color card = Color(0xFF1E1E1E);
  static const Color accent = Color(0xFFBB86FC);
  static const Color textPrimary = Color(0xFFE0E0E0);
  static const Color textSecondary = Color(0xFFA0A0A0);

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        primaryColor: accent,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: accent,
          surface: card,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: textPrimary),
        ),
        cardTheme: const CardTheme(
          color: card,
          elevation: 0,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        textTheme: const TextTheme(
          titleMedium: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          bodyMedium: TextStyle(
            color: textSecondary,
            fontSize: 14,
          ),
          bodySmall: TextStyle(
            color: textSecondary,
            fontSize: 12,
          ),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: accent,
          inactiveTrackColor: card,
          thumbColor: accent,
          overlayColor: accent.withOpacity(0.2),
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      );
}
