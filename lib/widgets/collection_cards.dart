import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/audio_track.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';
import 'cached_artwork.dart';

/// ⋮-меню альбома/подборки: играть / перемешать / в очередь.
class AlbumMenu extends StatelessWidget {
  final List<AudioTrack> tracks;
  final Color iconColor;
  final double iconSize;

  const AlbumMenu({
    super.key,
    required this.tracks,
    required this.iconColor,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) return const SizedBox.shrink();
    final player = context.read<PlayerProvider>();
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        color: iconColor,
        size: iconSize,
      ),
      color: AppTheme.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.cardBorder),
      ),
      onSelected: (value) {
        if (value == 'play') {
          player.playFromPlaylist(tracks, 0);
        } else if (value == 'shuffle') {
          final shuffled = List<AudioTrack>.of(tracks)..shuffle();
          player.playFromPlaylist(shuffled, 0);
        } else if (value == 'queue') {
          for (final t in tracks) {
            player.addToQueueNext(t);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Добавлено в очередь: ${tracks.length}'),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'play',
          child: Row(
            children: [
              Icon(Icons.play_arrow_rounded, size: 18),
              SizedBox(width: 10),
              Text('Играть'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'shuffle',
          child: Row(
            children: [
              Icon(Icons.shuffle_rounded, size: 18),
              SizedBox(width: 10),
              Text('Перемешать'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'queue',
          child: Row(
            children: [
              Icon(Icons.queue_music_rounded, size: 18),
              SizedBox(width: 10),
              Text('В очередь'),
            ],
          ),
        ),
      ],
    );
  }
}

/// Карточка альбома для сетки: арт, название, исполнитель, счётчик, ⋮.
class AlbumCard extends StatelessWidget {
  final PlayerProvider player;
  final String album;
  final List<AudioTrack> tracks;

  const AlbumCard({
    super.key,
    required this.player,
    required this.album,
    required this.tracks,
  });

  @override
  Widget build(BuildContext context) {
    final artist = tracks.isNotEmpty ? tracks.first.artist : '';
    return GestureDetector(
      onTap: () {
        if (tracks.isNotEmpty) player.playFromPlaylist(tracks, 0);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: Colors.black.a * 0.3,
              ),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: tracks.isNotEmpty
                    ? CachedArtwork(
                        trackId: tracks.first.id,
                        width: 220,
                        height: 220,
                        radius: 0,
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.pinkPurpleGradient,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.album_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            album,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            artist.isEmpty
                                ? '${tracks.length} треков'
                                : '$artist • ${tracks.length}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AlbumMenu(
                      tracks: tracks,
                      iconColor: AppTheme.textMuted,
                      iconSize: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Строка исполнителя: круглый аватар, имя, счётчики, tap наружу.
class ArtistRow extends StatelessWidget {
  final String artist;
  final List<AudioTrack> tracks;
  final int albumCount;
  final VoidCallback onTap;
  final VoidCallback? onPlay;

  const ArtistRow({
    super.key,
    required this.artist,
    required this.tracks,
    required this.albumCount,
    required this.onTap,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        leading: tracks.isNotEmpty
            ? ClipOval(
                child: CachedArtwork(
                  trackId: tracks.first.id,
                  width: 46,
                  height: 46,
                  radius: 0,
                ),
              )
            : Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
        title: Text(
          artist,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          albumCount > 0
              ? '$albumCount ${_plural(albumCount, 'альбом', 'альбома', 'альбомов')} • ${tracks.length} ${_plural(tracks.length, 'трек', 'трека', 'треков')}'
              : '${tracks.length} ${_plural(tracks.length, 'трек', 'трека', 'треков')}',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        trailing: onPlay == null
            ? null
            : IconButton(
                icon: Icon(
                  Icons.play_circle_fill_rounded,
                  color: AppTheme.accent,
                ),
                onPressed: onPlay,
                tooltip: 'Слушать',
              ),
        onTap: onTap,
      ),
    );
  }

  static String _plural(int count, String one, String few, String many) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return few;
    }
    return many;
  }
}
