import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/debug_log.dart';
import '../../../models/audio_track.dart';
import '../../../providers/player_provider.dart';
import '../../../widgets/cached_artwork.dart';
import '../../../widgets/marquee_text.dart';
import '../../now_playing/cinematic/cinematic_player_body.dart';

/// Направление свайпа: 1 — следующий трек, -1 — предыдущий.
@visibleForTesting
int? neonSwipeAction({required double dx, required double velocity}) {
  if (dx <= -26 || velocity <= -320) return 1;
  if (dx >= 26 || velocity >= 320) return -1;
  return null;
}

/// Неоновый мини-плеер: только play/pause, переключение — свайпом по карточке.
class NeonMiniPlayer extends StatefulWidget {
  final VoidCallback onExpand;

  const NeonMiniPlayer({super.key, required this.onExpand});

  @override
  State<NeonMiniPlayer> createState() => _NeonMiniPlayerState();
}

class _NeonMiniPlayerState extends State<NeonMiniPlayer> {
  double _dragDx = 0;
  bool _dragging = false;

  void _onDragStart(DragStartDetails details) {
    setState(() {
      _dragging = true;
      _dragDx = 0;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragDx = (_dragDx + details.delta.dx).clamp(-40.0, 40.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final player = context.read<PlayerProvider>();
    final action = neonSwipeAction(
      dx: _dragDx,
      velocity: details.primaryVelocity ?? 0,
    );
    setState(() {
      _dragging = false;
      _dragDx = 0;
    });
    if (action == null) return;

    HapticFeedback.lightImpact();
    if (action > 0) {
      unawaited(player.next());
    } else {
      unawaited(player.previous(restartCurrent: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    DebugLog.rebuild('NeonMini');
    final player = context.read<PlayerProvider>();
    final track = context.select<PlayerProvider, AudioTrack?>(
      (p) => p.currentTrack,
    );
    final isPlaying = context.select<PlayerProvider, bool>((p) => p.isPlaying);
    if (track == null) return const SizedBox.shrink();

    final accent = cinematicAccent(context, track.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Semantics(
        label: 'Мини-плеер: ${track.title}, ${track.artist}',
        hint: 'Свайп влево — следующий трек, вправо — предыдущий',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onExpand,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onHorizontalDragCancel: () {
            setState(() {
              _dragging = false;
              _dragDx = 0;
            });
          },
          child: AnimatedContainer(
            duration:
                _dragging ? Duration.zero : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_dragDx, 0, 0),
            height: 62,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(const Color(0xFF151622), accent, 0.10)!,
                  const Color(0xF20A0B11),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.42)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.18),
                  blurRadius: 18,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (current, previous) => Stack(
                        fit: StackFit.expand,
                        children: [...previous, if (current != null) current],
                      ),
                      transitionBuilder: (child, animation) {
                        final curved = CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                          reverseCurve: Curves.easeInCubic,
                        );
                        return FadeTransition(
                          opacity: curved,
                          child: ScaleTransition(
                            scale: Tween<double>(
                              begin: 0.96,
                              end: 1,
                            ).animate(curved),
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(track.id),
                        child: _MiniContent(
                          track: track,
                          isPlaying: isPlaying,
                          accent: accent,
                          onTogglePlay: player.togglePlay,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ValueListenableBuilder<Duration>(
                      valueListenable: player.positionTick,
                      builder: (_, pos, __) {
                        final durMs = player.duration.inMilliseconds;
                        final frac = durMs > 0
                            ? (pos.inMilliseconds / durMs)
                                .clamp(0.0, 1.0)
                                .toDouble()
                            : 0.0;
                        return LinearProgressIndicator(
                          value: frac,
                          minHeight: 2,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniContent extends StatelessWidget {
  final AudioTrack track;
  final bool isPlaying;
  final Color accent;
  final VoidCallback onTogglePlay;

  const _MiniContent({
    required this.track,
    required this.isPlaying,
    required this.accent,
    required this.onTogglePlay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 7, 8),
      child: Row(
        children: [
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
          const SizedBox(width: 8),
          _PlayButton(
            isPlaying: isPlaying,
            accent: accent,
            onTap: onTogglePlay,
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final Color accent;
  final VoidCallback onTap;

  const _PlayButton({
    required this.isPlaying,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = accent.computeLuminance() > 0.55
        ? const Color(0xFF08090E)
        : Colors.white;
    return Semantics(
      button: true,
      label: isPlaying ? 'Пауза' : 'Воспроизвести',
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(accent, Colors.white, 0.18)!,
                  accent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.34),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 140),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                key: ValueKey(isPlaying),
                color: iconColor,
                size: 27,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
