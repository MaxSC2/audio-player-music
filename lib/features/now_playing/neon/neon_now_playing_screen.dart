import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import '../../../widgets/player_feature_row.dart';
import '../cinematic/cinematic_player_body.dart';
import '../../../core/debug_log.dart';

/// Neon now playing: отдельное музыкальное пространство —
/// неоновая кромка, кольца сцены, ряд из 5 кнопок, все функции.
class NeonNowPlayingScreen extends StatelessWidget {
  const NeonNowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    DebugLog.rebuild('NeonNowPlaying');
    final track = context.watch<PlayerProvider>().currentTrack;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: CinematicTheme.bg,
      body: CinematicAmbient(
        trackId: track?.id,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: CinematicTheme.textSoft,
                        size: 28,
                      ),
                      tooltip: 'Свернуть',
                    ),
                    const Expanded(
                      child: Text(
                        'NEONWAVE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CinematicTheme.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: CinematicPlayerBody(
                  key: ValueKey('neon-${track?.id}'),
                  showFeatures: true,
                  fullControls: true,
                  edgeGlow: true,
                  stageRings: true,
                  features: track == null
                      ? null
                      : Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            6,
                            16,
                            8 + bottom * 0.4,
                          ),
                          child: PlayerFeatureRow(track: track),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
