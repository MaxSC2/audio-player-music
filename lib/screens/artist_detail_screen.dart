import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';
import '../widgets/cached_artwork.dart';
import '../widgets/track_tile.dart';

/// Экран исполнителя: аватар, кнопки, список его треков.
/// Тап по треку играет из списка исполнителя, а не из всей библиотеки.
class ArtistDetailScreen extends StatelessWidget {
  final String artist;

  const ArtistDetailScreen({super.key, required this.artist});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final tracks = player.allTracks
        .where((t) => t.artist == artist)
        .toList();
    final albumCount = tracks
        .map((t) => t.album ?? '')
        .where((a) => a.isNotEmpty)
        .toSet()
        .length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          artist,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Header
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.cardGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                tracks.isNotEmpty
                    ? ClipOval(
                        child: CachedArtwork(
                          trackId: tracks.first.id,
                          width: 72,
                          height: 72,
                          radius: 0,
                        ),
                      )
                    : Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.primaryGradient,
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artist,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        albumCount > 0
                            ? '$albumCount ${_plural(albumCount, 'альбом', 'альбома', 'альбомов')} • ${tracks.length} ${_plural(tracks.length, 'трек', 'трека', 'треков')}'
                            : '${tracks.length} ${_plural(tracks.length, 'трек', 'трека', 'треков')}',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Actions
          if (tracks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        player.playFromPlaylist(tracks, 0);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text(
                        'Слушать',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final shuffled = List.of(tracks)..shuffle();
                        player.playFromPlaylist(shuffled, 0);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: BorderSide(color: AppTheme.cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.shuffle_rounded, size: 20),
                      label: const Text('Перемешать'),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),

          // Tracks
          Expanded(
            child: tracks.isEmpty
                ? Center(
                    child: Text(
                      'Нет треков исполнителя',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.only(
                      bottom: 16 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    itemCount: tracks.length,
                    itemBuilder: (context, trackIndex) {
                      final track = tracks[trackIndex];
                      final isCurrent =
                          player.currentTrack?.id == track.id;

                      return TrackTile(
                        track: track,
                        isPlaying: isCurrent && player.isPlaying,
                        isCurrent: isCurrent,
                        onTap: () {
                          player.playFromPlaylist(tracks, trackIndex);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _plural(int count, String one, String few, String many) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return few;
    }
    return many;
  }
}
