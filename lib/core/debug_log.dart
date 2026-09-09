import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Мега-логер диагностики: все ошибки приложения + счётчики ребилдов
/// ключевых виджетов + автозапись сессии замеров. Временный инструмент
/// поиска шторма, не продуктовый код.
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

  // ── Автозапись сессии замеров ────────────────────────────────
  static const int _maxSessionLines = 120;
  static bool recording = false;
  static DateTime? _sessionStart;
  static final List<String> _session = [];
  static Timer? _sessionTimer;

  // Агрегаты кадров текущей секунды.
  static int _fUiSum = 0;
  static int _fUiMax = 0;
  static int _fRSum = 0;
  static int _fRMax = 0;
  static int _fCount = 0;

  /// Свежие значения извне (провайдер пишет раз в секунду).
  static int externalNotifyRate = 0;
  static Map<String, int> externalNotifySources = const {};

  static void setRecording(bool v) {
    if (v == recording) return;
    recording = v;
    if (v) {
      _sessionStart = DateTime.now();
      _resetFrameAgg();
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      _sessionTimer =
          Timer.periodic(const Duration(seconds: 1), (_) => _flushSecond());
      log('Сессия замеров начата');
    } else {
      _sessionTimer?.cancel();
      _sessionTimer = null;
      _flushSecond(force: true);
      try {
        SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      } catch (_) {}
      log('Сессия замеров остановлена');
    }
    version.value++;
  }

  static void _resetFrameAgg() {
    _fUiSum = 0;
    _fUiMax = 0;
    _fRSum = 0;
    _fRMax = 0;
    _fCount = 0;
  }

  static void _onTimings(List<FrameTiming> timings) {
    if (!recording) return;
    for (final t in timings) {
      final uiMs = t.buildDuration.inMicroseconds ~/ 1000;
      final rMs = t.rasterDuration.inMicroseconds ~/ 1000;
      _fUiSum += uiMs;
      _fRSum += rMs;
      if (uiMs > _fUiMax) _fUiMax = uiMs;
      if (rMs > _fRMax) _fRMax = rMs;
      _fCount++;
    }
  }

  static void _flushSecond({bool force = false}) {
    if (!recording && !force) return;
    if (_fCount == 0 && !force) return;
    final elapsed = _sessionStart == null
        ? 0
        : DateTime.now().difference(_sessionStart!).inSeconds;
    final topNotify = externalNotifySources.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topRebuild = _rebuilds.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final line =
        'T+$elapsed' 's ui_avg=${_fCount == 0 ? 0 : _fUiSum ~/ _fCount}ms '
        'ui_max=${_fUiMax}ms r_avg=${_fCount == 0 ? 0 : _fRSum ~/ _fCount}ms '
        'r_max=${_fRMax}ms notify=${externalNotifyRate}/s '
        '| notify: ${topNotify.take(4).map((e) => '${e.key}:${e.value}').join(',')} '
        '| rebuild: ${topRebuild.take(6).map((e) => '${e.key}:${e.value}').join(',')}';
    _session.add(line);
    while (_session.length > _maxSessionLines) {
      _session.removeAt(0);
    }
    _resetFrameAgg();
    version.value++;
  }

  static List<String> get session => List.unmodifiable(_session);

  static String get sessionText => _session.join('\n');

  static void clearSession() {
    _session.clear();
    version.value++;
  }
}
