import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/ui_style.dart';
import '../../../models/audio_track.dart';
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
    final centerAlbum = useAlbums ? albums[centerIndex] : null;
    final galleryTracks = player.visibleTracks;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // 3D scene background: deep gradient + glowing blobs
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0B0C14), Color(0xFF151228)],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            left: -60,
            child: _GlowBlob(
              size: 260,
              color: const Color(0x334433FF),
            ),
          ),
          Positioned(
            top: 90,
            right: -70,
            child: _GlowBlob(
              size: 220,
              color: const Color(0x3306B6D4),
            ),
          ),
          Positioned(
            bottom: 60,
            right: -90,
            child: _GlowBlob(
              size: 320,
              color: const Color(0x33A855F7),
            ),
          ),
          Positioned.fill(
            child: Column(
              children: [
                _buildAppBar(),
                // 3D gallery hero
                SizedBox(
                  height: 244,
                  child: useAlbums
                      ? _buildAlbumHero(player, albums, initialCenter)
                      : _buildTrackHero(player, galleryTracks, initialCenter),
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
                  )
                else
                  const SizedBox(height: 22),
                // Glass library panel
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                    decoration: BoxDecoration(
                      color: AppTheme.background.withOpacity(0.55),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28)),
                      border: Border(
                        top: BorderSide(
                            color: Colors.white.withOpacity(0.08), width: 1),
                        left: BorderSide(
                            color: Colors.white.withOpacity(0.06), width: 1),
                        right: BorderSide(
                            color: Colors.white.withOpacity(0.06), width: 1),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 30,
                          offset: Offset(0, -6),
                        ),
                      ],
                    ),
                    child: const LibraryTabs(threeD: true),
                  ),
                ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.primaryGradient.createShader(bounds),
            child: const Text(
              'Cover Flow',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.view_agenda_outlined,
                color: AppTheme.textSecondary),
            onPressed: () => context
                .read<UiStyleController>()
                .setStyle(PlayerUIStyle.simple),
            tooltip: 'Простой интерфейс',
          ),
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
        ],
      ),
    );
  }

  Widget _buildAlbumHero(
      PlayerProvider player, List<String> albums, int initialCenter) {
    return CoverFlowCarousel(
      itemCount: albums.length,
      initialIndex: initialCenter,
      viewportFraction: 0.4,
      cardWidth: 150,
      cardHeight: 190,
      onPageChanged: (i) => setState(() => _center = i),
      itemBuilder: (context, index) {
        final album = albums[index];
        final tracks = player.allTracks.where((t) => t.album == album).toList();
        return CoverFlowCard(
          track: tracks.first,
          width: 150,
          height: 190,
          onTap: () => player.playFromPlaylist(tracks, 0),
        );
      },
    );
  }

  Widget _buildTrackHero(
      PlayerProvider player, List<AudioTrack> tracks, int initialCenter) {
    return CoverFlowCarousel(
      itemCount: tracks.length,
      initialIndex: initialCenter,
      viewportFraction: 0.4,
      cardWidth: 150,
      cardHeight: 190,
      onPageChanged: (i) => setState(() => _center = i),
      itemBuilder: (context, index) {
        final track = tracks[index];
        return CoverFlowCard(
          track: track,
          width: 150,
          height: 190,
          onTap: () => player.playFromPlaylist(tracks, index),
        );
      },
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0)],
          ),
        ),
      ),
    );
  }
}