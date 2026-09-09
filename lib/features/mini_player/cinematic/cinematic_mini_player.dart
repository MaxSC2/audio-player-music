import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import '../../../widgets/cached_artwork.dart';
import '../../../widgets/marquee_text.dart';
import '../../now_playing/cinematic/cinematic_player_body.dart';

/// Компактный cinematic-мини: арт, название, play/pause, тонкий прогресс.
class CinematicMiniPlayer extends StatelessWidget {
  final VoidCallback onExpand;

  const CinematicMiniPlayer({super.key, required this.onExpand});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final track = player.currentTrack;
    if (track == null) return const SizedBox.shrink();

    final durMs = player.duration.inMilliseconds;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: GestureDetector(
        onTap: onExpand,
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            color: const Color(0xE60D0D11),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: CinematicTheme.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 8),
                    CachedArtwork(
                      trackId: track.id,
                      width: 46,
                      height: 46,
                      radius: 12,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MarqueeText(
                            text: track.title,
                            style: const TextStyle(
                              color: CinematicTheme.text,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: CinematicTheme.textDim,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: player.togglePlay,
                      icon: Icon(
                        player.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: CinematicTheme.text,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ValueListenableBuilder<Duration>(
                    valueListenable: player.positionTick,
                    builder: (_, pos, __) {
                      final frac = durMs > 0
                          ? (pos.inMilliseconds / durMs)
                              .clamp(0.0, 1.0)
                              .toDouble()
                          : 0.0;
                      return LinearProgressIndicator(
                        value: frac,
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(
                          Color(0xB3FFFFFF),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
