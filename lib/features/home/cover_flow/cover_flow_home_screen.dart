import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/ui_style.dart';
import '../../../providers/player_provider.dart';
import '../../../ui/theme.dart';
import '../../../widgets/cover_flow_card.dart';
import '../../../widgets/cover_flow_carousel.dart';
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
  late double _cardW;
  late double _cardH;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final player = context.read<PlayerProvider>();
    await player.requestPermission();
    if (!mounted) return;
    setState(() {
      _permissionDenied = player.allTracks.isEmpty;
    });
  }

  AppBar _buildAppBar() {
    return AppBar(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final tracks = player.visibleTracks;
    final albums = player.albums;
    final useAlbums = albums.isNotEmpty;

    if (tracks.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: _buildAppBar(),
        body: Center(
          child: _permissionDenied
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.music_off_rounded,
                          color: AppTheme.textSecondary,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Нет доступа к музыке',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Разрешите доступ к аудиофайлам, чтобы видеть вашу музыкальную библиотеку.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _requestPermission,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Запросить доступ'),
                      ),
                    ],
                  ),
                )
              : const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.accent),
                    SizedBox(height: 16),
                    Text(
                      'Сканируем музыку...',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
        ),
      );
    }

    final items = useAlbums ? albums : tracks;
    final currentAlbum = player.currentTrack?.album;
    final initialCenter = useAlbums
        ? (currentAlbum == null
            ? 0
            : albums
                .indexOf(currentAlbum)
                .clamp(0, albums.length - 1)
                .toInt())
        : (player.currentIndex < 0
            ? 0
            : player.currentIndex.clamp(0, tracks.length - 1).toInt());

    if (!_centerInitialized) {
      _centerInitialized = true;
      _center = initialCenter;
    }

    final centerIndex = _center.clamp(0, items.length - 1).toInt();
    final screenW = MediaQuery.sizeOf(context).width;

    Widget cardFor(int index) {
      if (useAlbums) {
        final album = albums[index];
        final albumTracks =
            tracks.where((t) => t.album == album).toList();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoverFlowCard(
              track: albumTracks.first,
              width: _cardW,
              height: _cardH - 52,
              onTap: () => player.playFromPlaylist(albumTracks, 0),
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
              '${albumTracks.length} '
              '${albumTracks.length == 1 ? 'трек' : 'треков'}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        );
      } else {
        final track = tracks[index];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoverFlowCard(
              track: track,
              width: _cardW,
              height: _cardH - 52,
              onTap: () => player.playFromPlaylist(tracks, index),
            ),
            const SizedBox(height: 12),
            Text(
              track.title,
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
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        );
      }
    }

    Widget labelFor(int index) {
      if (useAlbums) {
        final album = albums[index];
        final albumTracks = tracks.where((t) => t.album == album).toList();
        return Column(
          children: [
            Text(
              album,
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
              '${albumTracks.length} '
              '${albumTracks.length == 1 ? 'трек' : 'треков'} · '
              'нажмите на обложку, чтобы играть',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        );
      } else {
        final track = tracks[index];
        return Column(
          children: [
            Text(
              track.title,
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
              '${track.artist} · нажмите на обложку, чтобы играть',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        );
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _cardW = (screenW * 0.62 - 12).clamp(170.0, 250.0).toDouble();
                _cardH = (_cardW * 1.26)
                    .clamp(0.0, constraints.maxHeight - 56)
                    .toDouble();
                return CoverFlowCarousel(
                  itemCount: items.length,
                  initialIndex: initialCenter,
                  cardWidth: _cardW,
                  cardHeight: _cardH,
                  onPageChanged: (i) => setState(() => _center = i),
                  itemBuilder: (context, index) => cardFor(index),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
            child: labelFor(centerIndex),
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
    );
  }
}