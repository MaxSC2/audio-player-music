import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'debug_log.dart';

/// Независимая копия критичных настроек.
///
/// SharedPreferences на части прошивок (в т.ч. HyperOS) может не сохранить
/// запись после завершения процесса. RescueStore пишет тот же снимок в
/// JSON-файл в media-каталоге приложения и при следующем старте выбирает
/// более свежую копию. Файл также служит диагностикой: его можно прочитать
/// из Termux без root.
class RescueStore {
  RescueStore({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('neonwave/rescue');

  static const _prefsTimestampKey = 'rescue_saved_at';

  final MethodChannel _channel;
  final Completer<void> _ready = Completer<void>();
  final Map<String, Object?> _values = <String, Object?>{};
  SharedPreferences? _prefs;
  Timer? _saveTimer;
  Future<void>? _saveInFlight;
  int _fileSavedAt = 0;
  int _prefsSavedAt = 0;
  bool _useRescue = false;
  bool _loaded = false;

  String? path;
  int launchCount = 0;

  Future<void> get ready => _ready.future;
  bool get loaded => _loaded;
  bool get usingRescue => _useRescue;
  Map<String, Object?> get values => Map.unmodifiable(_values);

  bool use(String key) => _useRescue && _values.containsKey(key);

  Object? get(String key) => _values[key];

  Future<void> load(Future<SharedPreferences>? prefsFuture) async {
    try {
      final raw = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('load')
          .timeout(const Duration(seconds: 2));
      final rawState = raw?['state'];
      if (rawState is String && rawState.isNotEmpty) {
        final decoded = jsonDecode(rawState);
        if (decoded is Map) {
          final saved = decoded['values'];
          if (saved is Map) {
            saved.forEach((key, value) {
              if (key is String) _values[key] = _normalize(value);
            });
          }
        }
      }
      _fileSavedAt = (raw?['savedAt'] as num?)?.toInt() ?? 0;
      _prefsSavedAt = (raw?['prefsSavedAt'] as num?)?.toInt() ?? 0;
      final prefsHasAny = raw?['prefsHasAny'] == true;
      path = raw?['path'] as String?;
      launchCount = (raw?['launchCount'] as num?)?.toInt() ?? 0;
      // Файл новее prefs — значит последняя запись prefs потерялась.
      // Если prefs пусты (очистка data/сбой записи), файл тоже главный.
      _useRescue =
          _values.isNotEmpty && (_fileSavedAt > _prefsSavedAt || !prefsHasAny);
      _loaded = true;
      DebugLog.log(
        'rescue: launch=$launchCount fileAt=$_fileSavedAt '
        'prefsAt=$_prefsSavedAt use=$_useRescue '
        'keys=${_values.keys.join(',')}',
      );
      unawaited(_adoptPrefs(prefsFuture));
    } catch (e, st) {
      DebugLog.log('rescue load failed', e, st);
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> _adoptPrefs(Future<SharedPreferences>? prefsFuture) async {
    try {
      _prefs = await (prefsFuture ?? SharedPreferences.getInstance())
          .timeout(const Duration(seconds: 3));
    } catch (e, st) {
      _prefs = null;
      DebugLog.log('rescue: prefs недоступны', e, st);
    }
  }

  void set(String key, Object? value) => setAll({key: value});

  void setAll(Map<String, Object?> entries) {
    if (entries.isEmpty) return;
    entries.forEach((key, value) => _values[key] = _normalize(value));
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 120), () {
      unawaited(flush());
    });
  }

  Future<void> flush() async {
    if (_values.isEmpty) return;
    final previous = _saveInFlight;
    if (previous != null) await previous;
    final now = DateTime.now().millisecondsSinceEpoch;
    final body = jsonEncode({
      'version': 1,
      'savedAt': now,
      'values': _values,
    });
    final future = _write(body, now);
    _saveInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_saveInFlight, future)) _saveInFlight = null;
    }
  }

  Future<void> _write(String body, int savedAt) async {
    try {
      final ok = await _channel
          .invokeMethod<bool>('save', {'state': body, 'savedAt': savedAt})
          .timeout(const Duration(seconds: 2));
      if (ok != true) {
        DebugLog.log('rescue save rejected');
        return;
      }
      _fileSavedAt = savedAt;
      final prefs = _prefs;
      if (prefs != null) {
        try {
          final stored = await prefs
              .setInt(_prefsTimestampKey, savedAt)
              .timeout(const Duration(seconds: 2));
          if (stored) _prefsSavedAt = savedAt;
        } catch (e) {
          DebugLog.log('rescue: timestamp prefs не записан: $e');
        }
      }
    } catch (e, st) {
      DebugLog.log('rescue save failed', e, st);
    }
  }

  static Object? _normalize(Object? value) {
    if (value is Set) return value.map((e) => e.toString()).toList();
    return value;
  }
}
