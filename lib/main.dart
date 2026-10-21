import 'dart:async';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/debug_log.dart';
import 'core/nav_observer.dart';
import 'core/ui_style.dart';
import 'features/home/home_screen.dart';
import 'providers/player_provider.dart';
import 'services/audio_handler.dart';
import 'services/bridge_service.dart';
import 'services/widget_service.dart';
import 'state/palette_controller.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Мега-логер: ловим ВСЕ ошибки (Flutter, async, platform).
  final prevFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    DebugLog.log(
      'FlutterError: ${details.exception}',
      details.exception,
      details.stack,
    );
    if (prevFlutterError != null) {
      prevFlutterError(details);
    } else {
      FlutterError.presentError(details);
    }
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    DebugLog.log('AsyncError: $error', error, stack);
    return true;
  };
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  final playerProvider = PlayerProvider();
  final uiStyle = UiStyleController();
  final palette = PaletteController();

  WidgetService.bind(playerProvider);

  // Тему и стиль грузим до первого кадра, но с жёстким лимитом: зависший
  // SharedPreferences не должен оставлять приложение на чёрном экране.
  try {
    await Future.wait([
      palette.init(),
      uiStyle.init(),
    ]).timeout(const Duration(seconds: 2));
  } on TimeoutException {
    DebugLog.log('UI settings init: таймаут');
  } catch (e, st) {
    DebugLog.log('UI settings init failed', e, st);
  }

  // Сначала показываем UI: если audio_session/провайдер/AudioService зависнут
  // на конкретном устройстве, чёрный экран больше не блокирует старт.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => playerProvider),
        ChangeNotifierProvider(create: (_) => uiStyle),
        ChangeNotifierProvider(create: (_) => palette),
      ],
      child: ListenableBuilder(
        listenable: palette,
        builder: (_, __) => const NeonWaveApp(),
      ),
    ),
  );

  try {
    await playerProvider.ready.timeout(const Duration(seconds: 4));
  } on TimeoutException {
    playerProvider.setMediaServiceError('Инициализация провайдера: таймаут');
  } catch (e, st) {
    DebugLog.log('PlayerProvider init failed', e, st);
  }

  final handlerFuture = AudioService.init(
    builder: () => PlayerAudioHandler(
      playerProvider.player,
      onToggleRepeat: playerProvider.toggleRepeat,
      onToggleShuffle: playerProvider.toggleShuffle,
      onToggleFavorite: playerProvider.toggleFavoriteCurrent,
      onNext: playerProvider.next,
      onPrevious: playerProvider.previous,
      onPlayAt: (i) => playerProvider.playAt(i),
      onApplyShuffle: playerProvider.applyShuffle,
      onApplyRepeat: playerProvider.applyRepeatIndex,
      ensureLibraryLoaded: playerProvider.loadTracksIfAuthorized,
      getLibraryTracks: () => playerProvider.visibleTracks,
      getFavoriteTracks: () => playerProvider.favoriteTracks,
      getRecentTracks: () => playerProvider.smartRecentlyPlayed,
      getPlaylists: () => playerProvider.playlists,
      getPlaylistTracks: playerProvider.tracksOfPlaylist,
      onPlayTrackById: (id) async {
        for (final track in playerProvider.allTracks) {
          if (track.id == id) {
            await playerProvider.playTrack(track);
            return;
          }
        }
      },
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.audio_player.channel.audio',
      androidNotificationChannelName: 'NeonWave',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  handlerFuture.then(
    (handler) {
      playerProvider.attachAudioHandler(handler);
    },
    onError: (Object e) {
      playerProvider.setMediaServiceError('Ошибка: $e');
    },
  );

  try {
    await handlerFuture.timeout(const Duration(seconds: 10));
  } on TimeoutException {
    playerProvider.setMediaServiceError('Таймаут инициализации (10 сек)');
  } catch (e) {
    playerProvider.setMediaServiceError('Ошибка: $e');
  }

  // Мост внешних команд (Mini-UNA): автовоспроизведение + возврат.
  unawaited(BridgeService.init(playerProvider));
}

class NeonWaveApp extends StatelessWidget {
  const NeonWaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    final showFps =
        context.select<PlayerProvider, bool>((p) => p.perfOverlay.value);
    return MaterialApp(
      title: 'NeonWave',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
      showPerformanceOverlay: showFps,
      navigatorObservers: [DebugNavObserver()],
    );
  }
}
