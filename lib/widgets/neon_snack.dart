import 'package:flutter/material.dart';

import '../ui/theme.dart';

/// Единый «неоновый» снекбар для всего приложения.
///
/// Раньше удаление трека показывало дефолтный БЕЛЫЙ SnackBar, который
/// вырвиглазно смотрелся на тёмном фоне и перекрывал нижнюю панель плеера.
/// Теперь всё в стиле NeonWave: тёмная поверхность, акцентная иконка,
/// скруглённая рамка и отступ снизу (не закрывает мини-плеер).
void showNeonSnack(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_outline_rounded,
  Color? accent,
  bool error = false,
  Duration duration = const Duration(milliseconds: 1800),
  SnackBarAction? action,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  showNeonSnackOn(
    messenger,
    message,
    icon: icon,
    accent: accent,
    error: error,
    duration: duration,
    action: action,
  );
}

/// Вариант через [ScaffoldMessengerState] — нужен, когда контекст уже
/// закрывается (например, после `Navigator.pop` шторки), а снекбар
/// показать всё равно надо.
void showNeonSnackOn(
  ScaffoldMessengerState messenger,
  String message, {
  IconData icon = Icons.check_circle_outline_rounded,
  Color? accent,
  bool error = false,
  Duration duration = const Duration(milliseconds: 1800),
  SnackBarAction? action,
}) {
  final color = error
      ? const Color(0xFFEF4444)
      : (accent ?? AppTheme.accentLight);

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: color.a * 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                error ? Icons.error_outline_rounded : icon,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceLight,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.cardBorder),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        duration: duration,
        action: action,
      ),
    );
}

/// Снекбар результата удаления трека с устройства (единый стиль).
void showDeleteResultSnack(
  BuildContext context,
  bool ok, {
  String? title,
}) {
  showNeonSnack(
    context,
    ok
        ? (title == null ? 'Трек удалён' : '«$title» удалён')
        : 'Не удалось удалить трек',
    icon: ok ? Icons.delete_outline_rounded : Icons.error_outline_rounded,
    accent: ok ? AppTheme.accentPink : null,
    error: !ok,
  );
}

