import 'package:flutter/material.dart';

/// Мега-логер диагностики: все ошибки приложения + счётчики ребилдов
/// ключевых виджетов. Временный инструмент поиска шторма, не продуктовый код.
class DebugLog {
  static const int maxEntries = 300;
  static final List<String> _entries = [];
  static final Map<String, int> _rebuilds = {};
  static final ValueNotifier<int> version = ValueNotifier(0);

  static String _ts(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}.'
      '${t.millisecond.toString().padLeft(3, '0')}';

  /// Запись ошибки (FlutterError, async, platform).
  static void log(String msg, [Object? error, StackTrace? st]) {
    final line =
        '${_ts(DateTime.now())} $msg${error != null ? ' :: $error' : ''}';
    _entries.insert(0, line);
    if (st != null) {
      final frames = st
          .toString()
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .take(6)
          .join(' | ');
      if (frames.isNotEmpty) {
        _entries.insert(0, '  ↳ $frames');
      }
    }
    while (_entries.length > maxEntries) {
      _entries.removeLast();
    }
    version.value++;
  }

  static List<String> get entries => List.unmodifiable(_entries);

  static void clear() {
    _entries.clear();
    version.value++;
  }

  /// Счётчик ребилдов виджета. Вызывать первой строкой build().
  static void rebuild(String name) {
    _rebuilds[name] = (_rebuilds[name] ?? 0) + 1;
  }

  static Map<String, int> get rebuilds => Map.unmodifiable(_rebuilds);

  static void resetRebuilds() {
    _rebuilds.clear();
    version.value++;
  }

  /// Отчёт для экрана диагностики: топ по убыванию.
  static String get rebuildsReport {
    if (_rebuilds.isEmpty) return '—';
    final sorted = _rebuilds.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(16).map((e) => '${e.key}: ${e.value}').join('\n');
  }
}
