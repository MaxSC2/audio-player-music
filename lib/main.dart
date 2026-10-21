import 'dart:async';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'core/debug_log.dart';
import 'core/nav_observer.dart';
import 'core/ui_style.dart';
import 'features/boot/boot_gate.dart';
import 'features/home/home_screen.dart';
import 'providers/player_provider.dart';
import 'services/audio_handler.dart';
import 'services/bridge_service.dart';
import 'services/widget_service.dart';
import 'state/palette_controller.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Запрашиваем prefs ДО создания плеера и любых плагинов: на некоторых
  // устройствах инициализация ExoPlayer/аудиоэффектов блокирует главный
  // поток, из-за чего getAll() для SharedPreferences не успевал выполниться
  // и все настройки (стиль, избранное, сортировка) терялись.
  final prefsFuture = SharedPreferences.getInstance();
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
  final playerProvider = PlayerProvider(prefsFuture: prefsFuture);
  final uiStyle = UiStyleController(prefsFuture: prefsFuture);
  final palette = PaletteController(prefsFuture: prefsFuture);

  WidgetService.bind(playerProvider);

  final bootFuture = _bootstrap(playerProvider, palette, uiStyle);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => playerProvider),
        ChangeNotifierProvider(create: (_) => uiStyle),
        ChangeNotifierProvider(create: (_) => palette),
      ],
      child: ListenableBuilder(
        listenable: palette,
        builder: (_, __) => NeonWaveApp(bootFuture: bootFuture),
      ),
    ),
  );
}

/// Прогревает приложение под брендированным splash. Тяжёлые шаги ограничены
/// таймаутами: даже зависший platform channel не оставляет чёрный экран.
Future<void> _bootstrap(
  PlayerProvider playerProvider,
  PaletteController palette,
  UiStyleController uiStyle,
) async {
  final started = DateTime.now();

  await Future.wait([
    _withUiTimeout(palette.init(), 'palette init'),
    _withUiTimeout(uiStyle.init(), 'uiStyle init'),
  ]);

  try {
    await playerProvider.ready.timeout(const Duration(seconds: 4));
  } on TimeoutException {
    playerProvider.setMediaServiceError('Инициализация провайдера: таймаут');
  } catch (e, st) {
    DebugLog.log('PlayerProvider init failed', e, st);
  }

  // Если доступ к аудио уже выдан, прогреваем библиотеку до HomeScreen:
  // история и ДНК сразу видят треки, а не выглядят «стёртыми».
  try {
    await playerProvider
        .loadTracksIfAuthorized()
        .timeout(const Duration(seconds: 3));
  } on TimeoutException {
    DebugLog.log('library warmup: таймаут');
  } catch (e, st) {
    DebugLog.log('library warmup failed', e, st);
  }

  unawaited(_initAudioService(playerProvider));
  unawaited(BridgeService.init(playerProvider));

  const minSplash = Duration(milliseconds: 900);
  final elapsed = DateTime.now().difference(started);
  if (elapsed < minSplash) {
    await Future.delayed(minSplash - elapsed);
  }
}

Future<void> _withUiTimeout(Future<void> future, String label) async {
  try {
    await future.timeout(const Duration(seconds: 2));
  } on TimeoutException {
    DebugLog.log('$label: таймаут');
  } catch (e, st) {
    DebugLog.log('$label failed', e, st);
  }
}

Future<void> _initAudioService(PlayerProvider playerProvider) async {
  try {
    final handler = await AudioService.init(
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
    ).timeout(const Duration(seconds: 10));
    playerProvider.attachAudioHandler(handler);
  } on TimeoutException {
    playerProvider.setMediaServiceError('Таймаут инициализации (10 сек)');
  } catch (e) {
    playerProvider.setMediaServiceError('Ошибка: $e');
  }
}

class NeonWaveApp extends StatelessWidget {
  const NeonWaveApp({super.key, required this.bootFuture});

  final Future<void> bootFuture;

  @override
  Widget build(BuildContext context) {
    final showFps =
        context.select<PlayerProvider, bool>((p) => p.perfOverlay.value);
    return MaterialApp(
      title: 'NeonWave',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: BootGate(
        bootFuture: bootFuture,
        child: const HomeScreen(),
      ),
      showPerformanceOverlay: showFps,
      navigatorObservers: [DebugNavObserver()],
    );
  }
}
