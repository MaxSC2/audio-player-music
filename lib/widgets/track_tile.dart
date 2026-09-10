import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/audio_track.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';
import 'animated_waveform.dart';
import 'cached_artwork.dart';
import 'track_actions_sheet.dart';
import '../core/debug_log.dart';

class TrackTile extends StatelessWidget {
  final AudioTrack track;
  final bool isPlaying;
  final bool isCurrent;
  final bool selected;
  final bool threeD;

  /// Neon/тёмный «вшитый» стиль: карточка — полупрозрачная поверхность с
  /// тонкой кромкой, как мини-плеер и сцена. Без фиолетовой заливки, чтобы
  /// палитра списка не спорила с неоном плеера (жалоба по скринам).
  final bool neon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const TrackTile({
    super.key,
    required this.track,
    required this.isPlaying,
    this.isCurrent = false,
    this.selected = false,
    this.threeD = false,
    this.neon = false,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    DebugLog.rebuild('TrackTile');
    final player = context.read<PlayerProvider>();

    // Neon palette: полупрозрачная карточка + тонкая белая кромка,
    // согласованные со сценой/мини-плеером.
    const neonCard = Color(0x0FFFFFFF);
    const neonBorder = Color(0x24FFFFFF);
    final accent = AppTheme.accent;
    final baseColor = neon ? neonCard : AppTheme.card;
    final baseBorder = neon ? neonBorder : AppTheme.cardBorder;

    final tile = Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: selected
            ? accent.withValues(alpha: accent.a * (neon ? 0.28 : 0.2))
            : isCurrent
            ? accent.withValues(alpha: accent.a * (neon ? 0.16 : 0.12))
            : baseColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? accent
              : isCurrent
              ? accent.withValues(alpha: accent.a * 0.6)
              : baseBorder,
          width: selected ? 1.4 : (isCurrent ? 1.2 : 0.8),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppTheme.accent.withValues(
            alpha: AppTheme.accent.a * (0.15),
          ),
          highlightColor: AppTheme.accent.withValues(
            alpha: AppTheme.accent.a * (0.08),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Artwork / Thumbnail
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: AppTheme.cardGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isCurrent && isPlaying
                            ? [
                                BoxShadow(
                                  color: AppTheme.accent.withValues(
                                    alpha: AppTheme.accent.a * (0.4),
                                  ),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: CachedArtwork(
                        trackId: track.id,
                        width: 50,
                        height: 50,
                        radius: 12,
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(
                            alpha: Colors.black.a * (0.45),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: AnimatedWaveform(
                            isPlaying:
                                isPlaying && !player.debugNoVisualizers,
                            barCount: 4,
                            height: 20,
                            width: 24,
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.accentCyan,
                                AppTheme.accentLight,
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (selected)
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(
                            alpha: AppTheme.accent.a * (0.55),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // Title & Artist
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isCurrent
                              ? AppTheme.accentLight
                              : AppTheme.textPrimary,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              track.artist,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            ' • ${track.formattedDuration}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Favorite Button
                IconButton(
                  icon: Icon(
                    track.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: track.isFavorite
                        ? AppTheme.accentPink
                        : AppTheme.textMuted,
                    size: 22,
                  ),
                  onPressed: () => player.toggleFavorite(track),
                  tooltip: 'В избранное',
                ),

                // More Options Menu — единое меню (TrackActionsSheet),
                // то же, что и в плеере (жалоба: меню расходились).
                IconButton(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: AppTheme.textMuted,
                    size: 20,
                  ),
                  onPressed: () => TrackActionsSheet.show(context, track),
                  tooltip: 'Действия с треком',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!threeD) return tile;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0016)
        ..rotateX(-0.035)
        ..rotateZ(0.008),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                    color: AppTheme.accent.withValues(
                      alpha: AppTheme.accent.a * (0.38),
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: AppTheme.accentLight.withValues(
                      alpha: AppTheme.accentLight.a * (0.18),
                    ),
                    blurRadius: 34,
                    spreadRadius: 1,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: Colors.black.a * (0.32),
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: tile,
      ),
    );
  }
}
