import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/ui_style.dart';
import '../../../providers/player_provider.dart';
import '../../../ui/theme.dart';
import '../../../widgets/cover_flow_card.dart';
import '../../../widgets/cover_flow_carousel.dart';
import '../../library/library_tabs.dart';
import '../../mini_player/mini_player.dart';
import '../../now_playing/now_playing_screen.dart';
import '../../settings/settings_screen.dart';

class CoverFlowHomeScreen extends StatefulWidget {
  const CoverFlowHomeScreen({super.key});

  @override
  State<CoverFlowHomeScreen> createState() => _CoverFlowHomeScreenState();
}

class _CoverFlowHomeScreenState extends State<CoverFlowHomeScreen> {
  int _center = 0;
  bool _centerInitialized = false;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final albums = player.albums;
    final useAlbums = albums.isNotEmpty;

    final currentAlbum = player.currentTrack?.album;
    final initialCenter = useAlbums
        ? (currentAlbum == null
            ? 0
            : albums.indexOf(currentAlbum).clamp(0, albums.length - 1).toInt())
        : 0;

    if (!_centerInitialized) {
      _centerInitialized = true;
      _center = initialCenter;
    }

    final centerIndex =
        useAlbums ? _center.clamp(0, albums.length - 1).toInt() : 0;
    final centerAlbum =
        useAlbums ? albums[centerIndex] : null;

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
          IconButton(
            icon: const Icon(Icons.settings_rounded,
                color: AppTheme.textSecondary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            tooltip: 'Настройки',
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined,
                color: AppTheme.textSecondary),
            onPressed: () => context
                .read<UiStyleController>()
                .setStyle(PlayerUIStyle.simple),
            tooltip: 'Простой интерфейс',
          ),
        ],
      ),
      body: Column(
        children: [
          // 3D gallery banner
          SizedBox(
            height: 176,
            child: useAlbums
                ? _buildAlbumBanner(player, albums, initialCenter)
                : _buildTrackBanner(player, initialCenter),
          ),
          if (useAlbums && centerAlbum != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                centerAlbum,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.accentLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          // Full library (search, tabs, lists, sort, multi-select)
          const Expanded(child: LibraryTabs()),
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

  Widget _buildAlbumBanner(
      PlayerProvider player, List<String> albums, int initialCenter) {
    return CoverFlowCarousel(
      itemCount: albums.length,
      initialIndex: initialCenter,
      viewportFraction: 0.45,
      cardWidth: 120,
      cardHeight: 150,
      onPageChanged: (i) => setState(() => _center = i),
      itemBuilder: (context, index) {
        final album = albums[index];
        final tracks = player.allTracks.where((t) => t.album == album).toList();
        return CoverFlowCard(
          track: tracks.first,
          width: 120,
          height: 150,
          showReflection: false,
          onTap: () => player.playFromPlaylist(tracks, 0),
        );
      },
    );
  }

  Widget _buildTrackBanner(PlayerProvider player, int initialCenter) {
    final tracks = player.visibleTracks;
    return CoverFlowCarousel(
      itemCount: tracks.length,
      initialIndex: initialCenter,
      viewportFraction: 0.45,
      cardWidth: 120,
      cardHeight: 150,
      onPageChanged: (i) => setState(() => _center = i),
      itemBuilder: (context, index) {
        final track = tracks[index];
        return CoverFlowCard(
          track: track,
          width: 120,
          height: 150,
          showReflection: false,
          onTap: () => player.playFromPlaylist(tracks, index),
        );
      },
    );
  }
}