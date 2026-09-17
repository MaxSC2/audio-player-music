import 'package:audio_player/models/audio_track.dart';
import 'package:audio_player/providers/player_provider.dart';
import 'package:audio_player/widgets/queue_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Только граница платформы: очередь и callback остаются рабочим кодом.
class _AudioBackend {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  final sources = <String>[];
  String? id;
  int index = 0;
  int moves = 0;
  int loads = 0;

  void handle(String name, Future<Object?> Function(MethodCall) callback) {
    final channel = MethodChannel(name);
    channels.add(channel);
    messenger.setMockMethodCallHandler(channel, callback);
  }

  void install() {
    handle('com.ryanheise.audio_session', (call) async {
      if (call.method == 'getConfiguration') return null;
      if (call.method == 'setActive') return true;
      return null;
    });
    handle('com.ryanheise.just_audio.methods', (call) async {
      if (call.method == 'init') {
        id = (call.arguments as Map)['id'] as String;
        handle('com.ryanheise.just_audio.events.$id', (_) async => null);
        handle('com.ryanheise.just_audio.data.$id', (_) async => null);
        handle('com.ryanheise.just_audio.methods.$id', invoke);
      }
      return <String, Object?>{};
    });
  }

  void emit() {
    messenger.handlePlatformMessage(
      'com.ryanheise.just_audio.events.$id',
      const StandardMethodCodec().encodeSuccessEnvelope({
        'processingState': 3,
        'updateTime': DateTime.now().millisecondsSinceEpoch,
        'updatePosition': 0,
        'bufferedPosition': 180000000,
        'duration': 180000000,
        'currentIndex': index,
      }),
      (_) {},
    );
  }

  Future<Object?> invoke(MethodCall call) async {
    final args = (call.arguments as Map?) ?? {};
    switch (call.method) {
      case 'androidEqualizerGetParameters':
        return {
          'parameters': {
            'minDecibels': -15.0,
            'maxDecibels': 15.0,
            'bands': <Object>[],
          },
        };
      case 'load':
        loads++;
        final source = args['audioSource'] as Map;
        sources
          ..clear()
          ..addAll((source['children'] as List).map((s) => (s as Map)['uri'] as String));
        index = (args['initialIndex'] as int?) ?? 0;
        emit();
        return {'duration': 180000000};
      case 'seek':
        index = (args['index'] as int?) ?? index;
        emit();
      case 'concatenatingMove':
        final from = args['currentIndex'] as int;
        final to = args['newIndex'] as int;
        // Модель нативной операции сохраняет текущий источник по identity.
        final active = sources[index];
        final moved = sources.removeAt(from);
        sources.insert(to, moved);
        index = sources.indexOf(active);
        moves++;
        emit();
    }
    return <String, Object?>{};
  }

  void dispose() {
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  }
}

/// Прокрутка кадров БЕЗ pumpAndSettle: в очереди на текущей строке
/// крутится AnimatedWaveform (`_controller.repeat()`), поэтому «устаканить»
/// дерево невозможно — pumpAndSettle ждал бы таймаут (~10 мин).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
  // Debounce виджет-сервиса (60 мс) создаётся на последних перестройках —
  // без этого прогона тест падает на «Pending timers».
  await tester.pump(const Duration(milliseconds: 200));
}

/// Перетаскивание за реальную ручку ReorderableDragStartListener.
Future<void> _dragRow(
  WidgetTester tester, {
  required int from,
  required int to,
}) async {
  final start = tester.getCenter(
    find.byType(ReorderableDragStartListener).at(from),
  );
  final toRow = tester.getRect(find.byType(ListTile).at(to));
  final end = Offset(start.dx, toRow.center.dy);

  final gesture = await tester.startGesture(start);
  await tester.pump(const Duration(milliseconds: 30));
  const steps = 10;
  for (var i = 1; i <= steps; i++) {
    await gesture.moveTo(Offset.lerp(start, end, i / steps)!);
    await tester.pump(const Duration(milliseconds: 30));
  }
  await gesture.up();
  await _settle(tester);
}

List<int> _visibleOrder(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(of: find.byType(ListTile), matching: find.byType(Text)),
    )
    .map((t) => t.data)
    .whereType<String>()
    .where((s) => s.startsWith('Track '))
    .map((s) => int.parse(s.substring(6)))
    .toList();

/// Общая сцена: реальный PlayerProvider с заглушкой аудио-движка,
/// 4 трека, окно нативного плеера накрывает всю очередь.
Future<PlayerProvider> _scene(WidgetTester tester, _AudioBackend backend) async {
  SharedPreferences.setMockInitialValues({});
  final player = PlayerProvider();
  final tracks = List.generate(
    4,
    (i) => AudioTrack(
      id: i,
      title: 'Track $i',
      artist: 'Artist',
      uri: 'file:///test/track_$i.mp3',
      duration: 180000,
    ),
  );
  await tester.runAsync(() => player.playFromPlaylist(tracks, 0));
  await tester.runAsync(() => player.player.pause());
  await tester.pumpWidget(
    ChangeNotifierProvider<PlayerProvider>.value(
      value: player,
      child: const MaterialApp(home: Scaffold(body: QueueSheet())),
    ),
  );
  await _settle(tester);
  return player;
}

/// Номер трека из URI вида `file:///test/track_3.mp3`.
int _trackOf(String uri) =>
    int.parse(uri.substring(uri.lastIndexOf('_') + 1, uri.lastIndexOf('.')));

void main() {
  testWidgets('QueueSheet: перетаскивание за ручку меняет очередь в провайдере и в UI', (
    tester,
  ) async {
    final backend = _AudioBackend()..install();
    addTearDown(backend.dispose);
    final player = await _scene(tester, backend);
    addTearDown(player.dispose);

    // Очередь собрана на актуальном callback и ручках, а не на long-press.
    final listView = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    expect(listView.onReorderItem, isNotNull);
    expect(listView.buildDefaultDragHandles, isFalse);
    expect(player.currentTrack?.id, 0);
    expect(_visibleOrder(tester), [0, 1, 2, 3]);

    // 1) Перетаскивание вниз, мимо играющего трека: он остаётся на месте.
    await _dragRow(tester, from: 1, to: 3);
    expect(player.playlist.map((t) => t.id), [0, 2, 3, 1]);
    expect(player.currentTrack?.id, 0, reason: 'играющий трек не подменился');
    expect(player.currentIndex, 0, reason: 'текущий индекс не сдвинулся');
    expect(_visibleOrder(tester), [0, 2, 3, 1], reason: 'список перерисован');

    // 2) Перетаскивание самого играющего трека в конец.
    await _dragRow(tester, from: 0, to: 3);
    expect(player.playlist.map((t) => t.id), [2, 3, 1, 0]);
    expect(player.currentTrack?.id, 0, reason: 'тот же трек, новая позиция');
    expect(player.currentIndex, 3, reason: 'индекс следует за треком');
    expect(_visibleOrder(tester), [2, 3, 1, 0]);
  });

  // Нативные эффекты проверяем на реальном цикле событий: платформенный
  // вызов из callback-а жеста в fake-async зоне теста не завершается.
  testWidgets('onReorderItem: нативная очередь двигается без перезагрузки', (
    tester,
  ) async {
    final backend = _AudioBackend()..install();
    addTearDown(backend.dispose);
    final player = await _scene(tester, backend);
    addTearDown(player.dispose);

    final callback = tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorderItem!;

    await tester.runAsync(() async {
      callback(1, 3);
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await _settle(tester);

    expect(backend.moves, 1);
    expect(backend.loads, 1, reason: 'внутри окна перезагрузка не нужна');
    expect(backend.sources.map(_trackOf), [0, 2, 3, 1]);
    expect(player.playlist.map((t) => t.id), [0, 2, 3, 1]);

    await tester.runAsync(() async {
      callback(0, 3);
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await _settle(tester);

    expect(backend.moves, 2);
    expect(backend.loads, 1);
    expect(backend.sources.map(_trackOf), [2, 3, 1, 0]);
    expect(player.currentTrack?.id, 0);
    expect(player.currentIndex, 3);
  });
}
