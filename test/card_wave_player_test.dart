import 'package:audio_player/features/now_playing/card_wave/card_wave_now_playing_screen.dart';
import 'package:audio_player/features/now_playing/card_wave/card_wave_player_body.dart';
import 'package:audio_player/models/audio_track.dart';
import 'package:audio_player/providers/player_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AudioBackend {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  final sources = <String>[];
  String? id;
  int index = 0;

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
        final source = args['audioSource'] as Map;
        sources
          ..clear()
          ..addAll(
            (source['children'] as List).map(
              (s) => (s as Map)['uri'] as String,
            ),
          );
        index = (args['initialIndex'] as int?) ?? 0;
        emit();
        return {'duration': 180000000};
      case 'seek':
        index = (args['index'] as int?) ?? index;
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

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
  await tester.pump(const Duration(milliseconds: 200));
}

Future<PlayerProvider> _scene(
  WidgetTester tester,
  _AudioBackend backend,
) async {
  SharedPreferences.setMockInitialValues({});
  final player = PlayerProvider();
  final tracks = List.generate(
    3,
    (i) => AudioTrack(
      id: i,
      title: 'Track $i',
      artist: 'Artist $i',
      album: 'Deck',
      uri: 'file:///test/track_$i.mp3',
      duration: 180000,
    ),
  );
  await tester.runAsync(() => player.playFromPlaylist(tracks, 0));
  await tester.runAsync(() => player.player.pause());
  await tester.pumpWidget(
    ChangeNotifierProvider<PlayerProvider>.value(
      value: player,
      child: const MaterialApp(home: CardWaveNowPlayingScreen()),
    ),
  );
  await _settle(tester);
  return player;
}

void main() {
  testWidgets('Cardwave table renders front and back without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _AudioBackend()..install();
    addTearDown(backend.dispose);
    final player = await _scene(tester, backend);
    addTearDown(player.dispose);

    expect(find.byType(CardWavePlayerBody), findsOneWidget);
    expect(find.text('Track 0'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tapAt(tester.getCenter(find.byType(CardWavePlayerBody)));
    await tester.pump(const Duration(milliseconds: 460));
    await _settle(tester);

    expect(find.text('РУБАШКА КОЛОДЫ'), findsOneWidget);
    expect(find.text('Открыть колоду'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cardwave table fits a compact phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _AudioBackend()..install();
    addTearDown(backend.dispose);
    final player = await _scene(tester, backend);
    addTearDown(player.dispose);

    expect(find.byType(CardWavePlayerBody), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tapAt(tester.getCenter(find.byType(CardWavePlayerBody)));
    await tester.pump(const Duration(milliseconds: 460));
    await _settle(tester);

    expect(find.text('РУБАШКА КОЛОДЫ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
