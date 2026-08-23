import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/ui_style.dart';
import 'features/home/home_screen.dart';
import 'providers/player_provider.dart';
import 'services/audio_handler.dart';
import 'services/widget_service.dart';
import 'state/palette_controller.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));
  final playerProvider = PlayerProvider();
  final uiStyle = UiStyleController();
  final palette = PaletteController();

  await palette.init();
  await uiStyle.init();

  WidgetService.bind(playerProvider);

  final handlerFuture = AudioService.init(
    builder: () => PlayerAudioHandler(
      playerProvider.player,
      onToggleRepeat: playerProvider.toggleRepeat,
      onToggleShuffle: playerProvider.toggleShuffle,
      onToggleFavorite: playerProvider.toggleFavoriteCurrent,
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.audio_player.channel.audio',
      androidNotificationChannelName: 'NeonWave',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  handlerFuture.then((handler) {
    if (handler is PlayerAudioHandler) {
      playerProvider.attachAudioHandler(handler);
    }
  }, onError: (Object e) {
    playerProvider.setMediaServiceError('Ошибка: $e');
  });

  try {
    await handlerFuture.timeout(const Duration(seconds: 10));
  } on TimeoutException {
    playerProvider.setMediaServiceError('Таймаут инициализации (10 сек)');
  } catch (e) {
    playerProvider.setMediaServiceError('Ошибка: $e');
  }

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
}

class NeonWaveApp extends StatelessWidget {
  const NeonWaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeonWave',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}