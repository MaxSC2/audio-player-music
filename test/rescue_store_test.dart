import 'dart:convert';

import 'package:audio_player/core/rescue_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('neonwave/rescue_test');

  Map<String, Object?> nativeState({
    required int savedAt,
    required int prefsSavedAt,
    required bool prefsHasAny,
    Map<String, Object?> values = const {'ui_style': 'neon'},
  }) => {
    'state': jsonEncode({
      'version': 1,
      'savedAt': savedAt,
      'values': values,
    }),
    'savedAt': savedAt,
    'prefsSavedAt': prefsSavedAt,
    'prefsHasAny': prefsHasAny,
    'path': '/tmp/neonwave_rescue.json',
    'launchCount': 3,
  };

  void mockLoad(Map<String, Object?> payload) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'load') return payload;
          if (call.method == 'save') return true;
          return null;
        });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('rescue новее SharedPreferences — используется rescue', () async {
    SharedPreferences.setMockInitialValues({});
    mockLoad(
      nativeState(savedAt: 200, prefsSavedAt: 100, prefsHasAny: true),
    );
    final store = RescueStore(channel: channel);
    await store.load(SharedPreferences.getInstance());

    expect(store.use('ui_style'), isTrue);
    expect(store.get('ui_style'), 'neon');
    expect(store.launchCount, 3);
  });

  test('SharedPreferences новее — rescue не перебивает их', () async {
    SharedPreferences.setMockInitialValues({});
    mockLoad(
      nativeState(savedAt: 100, prefsSavedAt: 200, prefsHasAny: true),
    );
    final store = RescueStore(channel: channel);
    await store.load(SharedPreferences.getInstance());

    expect(store.use('ui_style'), isFalse);
  });

  test('пустые prefs — rescue восстанавливает настройки', () async {
    SharedPreferences.setMockInitialValues({});
    mockLoad(
      nativeState(savedAt: 100, prefsSavedAt: 0, prefsHasAny: false),
    );
    final store = RescueStore(channel: channel);
    await store.load(SharedPreferences.getInstance());

    expect(store.use('ui_style'), isTrue);
  });

  test('flush отправляет полный снимок в нативный канал', () async {
    SharedPreferences.setMockInitialValues({});
    String? savedBody;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'load') {
            return nativeState(
              savedAt: 100,
              prefsSavedAt: 0,
              prefsHasAny: false,
            );
          }
          if (call.method == 'save') {
            savedBody = call.arguments['state'] as String?;
            return true;
          }
          return null;
        });
    final store = RescueStore(channel: channel);
    await store.load(SharedPreferences.getInstance());
    store.setAll({'ui_style': 'cinematic', 'favorite_ids': ['7', '9']});
    await store.flush();

    final decoded = jsonDecode(savedBody!) as Map<String, dynamic>;
    final values = decoded['values'] as Map<String, dynamic>;
    expect(values['ui_style'], 'cinematic');
    expect(values['favorite_ids'], ['7', '9']);
  });
}
