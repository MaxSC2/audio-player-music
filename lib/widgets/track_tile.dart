import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/audio_track.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';
import 'animated_waveform.dart';
import 'cached_artwork.dart';
import 'playlist_picker_sheet.dart';
import 'track_info_dialog.dart';

class TrackTile extends StatelessWidget {
  final AudioTrack track;
  final bool isPlaying;
  final bool isCurrent;
  final bool selected;
  final bool threeD;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const TrackTile({
    super.key,
    required this.track,
    required this.isPlaying,
    this.isCurrent = false,
    this.selected = false,
    this.threeD = false,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();

    final tile = Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.accent.withOpacity(0.2)
            : isCurrent
                ? AppTheme.accent.withOpacity(0.12)
                : AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? AppTheme.accent
              : isCurrent
                  ? AppTheme.accent.withOpacity(0.6)
                  : AppTheme.cardBorder,
          width: selected ? 1.4 : (isCurrent ? 1.2 : 0.8),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppTheme.accent.withOpacity(0.15),
          highlightColor: AppTheme.accent.withOpacity(0.08),
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
                                  color: AppTheme.accent.withOpacity(0.4),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                )
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
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: AnimatedWaveform(
                            isPlaying: isPlaying,
                            barCount: 4,
                            height: 20,
                            width: 24,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00F5D4), Color(0xFFBB86FC)],
                            ),
                          ),
                        ),
                      ),
                    if (selected)
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.55),
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
                          fontWeight:
                              isCurrent ? FontWeight.w700 : FontWeight.w600,
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

                // More Options Menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      color: AppTheme.textMuted, size: 20),
                  color: AppTheme.surfaceLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: AppTheme.cardBorder),
                  ),
                  onSelected: (value) {
                    if (value == 'play_next') {
                      player.addToQueueNext(track);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('"${track.title}" будет играть следующим'),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else if (value == 'favorite') {
                      player.toggleFavorite(track);
                    } else if (value == 'playlist') {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppTheme.surface,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24)),
                        ),
                        builder: (_) => PlaylistPickerSheet(track: track),
                      );
                    } else if (value == 'info') {
                      showDialog(
                        context: context,
                        builder: (_) => TrackInfoDialog(track: track),
                      );
                    } else if (value == 'not_now') {
                      player.toggleNotNow(track);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(player.isNotNow(track.id)
                              ? '"${track.title}" скрыт на неделю'
                              : '"${track.title}" снова в подборе'),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'play_next',
                      child: Row(
                        children: [
                          Icon(Icons.playlist_play_rounded,
                              color: AppTheme.accentCyan, size: 18),
                          SizedBox(width: 10),
                          Text('Играть следующим'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'favorite',
                      child: Row(
                        children: [
                          Icon(
                            track.isFavorite
                                ? Icons.favorite_border_rounded
                                : Icons.favorite_rounded,
                            color: AppTheme.accentPink,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(track.isFavorite
                              ? 'Удалить из избранного'
                              : 'В избранное'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'playlist',
                      child: Row(
                        children: [
                          Icon(Icons.playlist_add_rounded,
                              color: AppTheme.accentGreen, size: 18),
                          SizedBox(width: 10),
                          Text('Добавить в плейлист'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'not_now',
                      child: Row(
                        children: [
                          Icon(
                            player.isNotNow(track.id)
                                ? Icons.undo_rounded
                                : Icons.do_not_disturb_on_rounded,
                            color: AppTheme.textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(player.isNotNow(track.id)
                              ? 'Вернуть в подбор'
                              : 'Не хочу сейчас'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'info',
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: AppTheme.textSecondary, size: 18),
                          SizedBox(width: 10),
                          Text('О треке'),
                        ],
                      ),
                    ),
                  ],
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
        ..setEntry(3, 2, 0.0012)
        ..rotateX(-0.028)
        ..rotateZ(0.006),
      child: tile,
    );
  }
}