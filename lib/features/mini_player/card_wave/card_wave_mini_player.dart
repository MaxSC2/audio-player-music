import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/audio_track.dart';
import '../../../providers/player_provider.dart';
import '../../../widgets/cached_artwork.dart';

/// A small physical-looking fan of cards. Swiping changes the active track.
class CardWaveMiniPlayer extends StatefulWidget {
  final VoidCallback onExpand;

  const CardWaveMiniPlayer({super.key, required this.onExpand});

  @override
  State<CardWaveMiniPlayer> createState() => _CardWaveMiniPlayerState();
}

class _CardWaveMiniPlayerState extends State<CardWaveMiniPlayer> {
  double _dragX = 0;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    final track = context.select<PlayerProvider, AudioTrack?>((p) => p.currentTrack);
    final playing = context.select<PlayerProvider, bool>((p) => p.isPlaying);
    if (track == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: GestureDetector(
        onTap: widget.onExpand,
        onHorizontalDragUpdate: (details) {
          setState(() => _dragX = (_dragX + details.delta.dx).clamp(-70.0, 70.0));
        },
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          final goNext = _dragX < -24 || velocity < -320;
          final goPrevious = _dragX > 24 || velocity > 320;
          setState(() => _dragX = 0);
          if (!goNext && !goPrevious) return;
          HapticFeedback.selectionClick();
          if (goNext) {
            unawaited(player.next());
          } else {
            unawaited(player.previous(restartCurrent: false));
          }
        },
        onHorizontalDragCancel: () => setState(() => _dragX = 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 190),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(_dragX * 0.18, 0, 0),
          height: 82,
          decoration: BoxDecoration(
            color: const Color(0xFF15141A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x4DC9B47C)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x30000000),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                const Positioned(
                  left: 15,
                  top: 15,
                  child: _BackCard(angle: -0.14, color: Color(0xFF39303B)),
                ),
                const Positioned(
                  left: 23,
                  top: 10,
                  child: _BackCard(angle: 0.13, color: Color(0xFF574635)),
                ),
                Positioned(
                  left: 12,
                  top: 8,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: Container(
                      key: ValueKey(track.id),
                      width: 48,
                      height: 64,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3D5B5),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 8),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedArtwork(
                          trackId: track.id,
                          width: 44,
                          height: 60,
                          radius: 6,
                          fallback: const ColoredBox(
                            color: Color(0xFF29242D),
                            child: Icon(Icons.music_note_rounded,
                                color: Color(0xFFC9B47C)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(72, 10, 10, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFF4EBD9),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFAAA08D),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: playing ? 'Пауза' : 'Воспроизвести',
                        onPressed: player.togglePlay,
                        icon: Icon(
                          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: const Color(0xFFE3D0A0),
                          size: 29,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ValueListenableBuilder<Duration>(
                    valueListenable: player.positionTick,
                    builder: (_, position, __) {
                      final total = player.duration.inMilliseconds;
                      final progress = total <= 0
                          ? 0.0
                          : (position.inMilliseconds / total).clamp(0.0, 1.0).toDouble();
                      return LinearProgressIndicator(
                        value: progress,
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFC9B47C)),
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

class _BackCard extends StatelessWidget {
  final double angle;
  final Color color;

  const _BackCard({required this.angle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 43,
        height: 58,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFFBFA56C), width: 1),
        ),
        child: const Center(
          child: Icon(Icons.auto_awesome_rounded,
              color: Color(0xFFDDC994), size: 17),
        ),
      ),
    );
  }
}