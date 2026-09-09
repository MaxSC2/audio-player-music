import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import '../../../widgets/player_feature_row.dart';
import 'cinematic_player_body.dart';
import '../../../core/debug_log.dart';

/// Полноэкранный cinematic-плеер: то же пространство + все функции.
class CinematicNowPlayingScreen extends StatelessWidget {
  const CinematicNowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    DebugLog.rebuild('CinematicNowPlaying');
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
                        'Сейчас играет',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CinematicTheme.textDim,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: CinematicPlayerBody(
                  key: ValueKey('full-${track?.id}'),
                  showFeatures: true,
                  features: track == null
                      ? null
                      : Padding(
                          padding: EdgeInsets.fromLTRB(
                              16, 6, 16, 8 + bottom * 0.4),
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
