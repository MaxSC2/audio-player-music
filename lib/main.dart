import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/player_provider.dart';
import 'screens/library_screen.dart';
import 'services/audio_handler.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final playerProvider = PlayerProvider();

  final handlerFuture = AudioService.init(
    builder: () => PlayerAudioHandler(
      playerProvider.player,
      onToggleRepeat: playerProvider.toggleRepeat,
      onToggleShuffle: playerProvider.toggleShuffle,
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
  }).ignore();

  try {
    await handlerFuture.timeout(const Duration(seconds: 10));
  } catch (_) {
    // AudioService could not be initialized on this device; run without
    // the media notification rather than blocking the UI.
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => playerProvider,
      child: const NeonWaveApp(),
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
      home: const LibraryScreen(),
    );
  }
}