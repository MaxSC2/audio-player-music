import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/player_provider.dart';
import '../../../ui/theme.dart';
import '../../../widgets/cover_flow_card.dart';
import '../../../widgets/cover_flow_carousel.dart';
import '../../mini_player/mini_player.dart';
import '../../now_playing/now_playing_screen.dart';

class CoverFlowHomeScreen extends StatefulWidget {
  const CoverFlowHomeScreen({super.key});

  @override
  State<CoverFlowHomeScreen> createState() => _CoverFlowHomeScreenState();
}

class _CoverFlowHomeScreenState extends State<CoverFlowHomeScreen> {
  int _centerAlbum = 0;
  bool _centerInitialized = false;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final albums = player.albums;

    if (albums.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text(
            'Cover Flow',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.album_outlined,
                  color: AppTheme.textMuted, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Альбомы не найдены',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final currentAlbum = player.currentTrack?.album;
    final initialAlbumIndex =
        currentAlbum == null ? 0 : (albums.indexOf(currentAlbum).clamp(0, albums.length - 1).toInt());
    if (!_centerInitialized) {
      _centerInitialized = true;
      _centerAlbum = initialAlbumIndex;
    }
    final centerAlbum = albums[_centerAlbum.clamp(0, albums.length - 1).toInt()];
    final centerTracks =
        player.allTracks.where((t) => t.album == centerAlbum).toList();

    final screenW = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Cover Flow',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          if (player.allTracks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${albums.length} ${albums.length == 1 ? 'альбом' : 'альбомов'}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 3D album carousel
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardW = (screenW * 0.62 - 12).clamp(170.0, 250.0).toDouble();
                final cardH = (cardW * 1.22)
                    .clamp(0.0, constraints.maxHeight - 56)
                    .toDouble();
                return CoverFlowCarousel(
                  itemCount: albums.length,
                  initialIndex: initialAlbumIndex,
                  cardWidth: cardW,
                  cardHeight: cardH,
                  onPageChanged: (i) => setState(() => _centerAlbum = i),
                  itemBuilder: (context, index) {
                    final album = albums[index];
                    final tracks = player.allTracks
                        .where((t) => t.album == album)
                        .toList();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CoverFlowCard(
                          track: tracks.first,
                          width: cardW,
                          height: cardH - 52,
                          onTap: () {
                            player.playFromPlaylist(tracks, 0);
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          album,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${tracks.length} ${tracks.length == 1 ? 'трек' : 'треков'}',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Centered album info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
            child: Column(
              children: [
                Text(
                  centerAlbum,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.accentLight,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${centerTracks.length} '
                  '${centerTracks.length == 1 ? 'трек' : 'треков'} · '
                  'нажмите на обложку, чтобы играть',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),

          // Mini player
          SafeArea(
            top: false,
            child: MiniPlayer(
              onExpand: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const NowPlayingScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}