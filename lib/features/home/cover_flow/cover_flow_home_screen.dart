import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/ui_style.dart';
import '../../../models/audio_track.dart';
import '../../../providers/player_provider.dart';
import '../../../ui/theme.dart';
import '../../../widgets/three_d_visualizer.dart';
import '../../../widgets/cover_flow_card.dart';
import '../../../widgets/cover_flow_carousel.dart';
import '../../../widgets/marquee_text.dart';
import '../../../widgets/three_d_background.dart';
import '../../library/library_tabs.dart';
import '../../library/personal_dj_sheet.dart';
import 'cover_flow_player_sheet.dart';
import '../../settings/settings_screen.dart';

class CoverFlowHomeScreen extends StatefulWidget {
  const CoverFlowHomeScreen({super.key});

  @override
  State<CoverFlowHomeScreen> createState() => _CoverFlowHomeScreenState();
}

class _CoverFlowHomeScreenState extends State<CoverFlowHomeScreen> {
  PageController? _controller;
  int _lastSyncedKey = -1;
  bool _programmatic = false;

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  int _targetIndex(PlayerProvider player) {
    final albums = player.albums;
    if (albums.isNotEmpty) {
      final album = player.currentTrack?.album;
      if (album == null) return 0;
      final i = albums.indexOf(album);
      return i < 0 ? 0 : i;
    }
    final id = player.currentTrack?.id;
    if (id == null) return 0;
    final i = player.visibleTracks.indexWhere((t) => t.id == id);
    return i < 0 ? 0 : i;
  }

  void _onPageChanged(int index) {
    // Свайп карусели — только просмотр. Воспроизведение — явный тап по карточке.
    // Раньше здесь был отложенный автозапуск: программные события страниц
    // протекали при быстрых переключениях и запускали «1-й трек альбома».
    if (_programmatic) {
      _programmatic = false;
    }
  }

  void _openLibrary() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xE60F101C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Colors.white10, width: 1),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: EdgeInsets.only(top: 6, bottom: 2),
                child: Text(
                  'Библиотека',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Expanded(child: LibraryTabs(threeD: true)),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final player = context.read<PlayerProvider>();
      await player.ensureNotificationPermission();
      if (!player.hasLibrary) player.requestPermission();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _openFullPlayer(BuildContext context) {
    CoverFlowPlayerSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final track = player.currentTrack;

    final albums = player.albums;
    final useAlbums = albums.isNotEmpty;
    final tracks = player.visibleTracks;

    final targetIndex = _targetIndex(player);
    _controller ??= PageController(
      viewportFraction: 0.4,
      initialPage: targetIndex,
    );

    if (_lastSyncedKey != targetIndex) {
      _lastSyncedKey = targetIndex;
      _programmatic = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _controller == null) return;
        final c = _controller!;
        if (c.hasClients && (c.page ?? 0).round() != targetIndex) {
          c.animateToPage(
            targetIndex,
            duration: const Duration(milliseconds: 460),
            curve: Curves.easeOutCubic,
          );
        } else {
          _programmatic = false;
        }
      });
    }

    final screenW = MediaQuery.sizeOf(context).width;
    final posMs = player.position.inMilliseconds;
    final durMs = player.duration.inMilliseconds;
    final posFrac = durMs > 0 ? (posMs / durMs).clamp(0.0, 1.0).toDouble() : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: ThreeDBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              // Full-screen carousel with equalizer behind
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (tracks.isEmpty && !useAlbums) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                                color: AppTheme.accent),
                            const SizedBox(height: 16),
                            Text(
                              'Сканируем музыку...',
                              style:
                                  TextStyle(color: AppTheme.textSecondary),
                            ),
                            SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () => context
                                  .read<PlayerProvider>()
                                  .requestPermission(),
                              icon: Icon(Icons.folder_open_rounded,
                                  color: AppTheme.accentLight, size: 18),
                              label: const Text('Запросить доступ'),
                            ),
                          ],
                        ),
                      );
                    }
                    final cardW = (constraints.maxWidth * 0.44)
                        .clamp(150.0, 210.0)
                        .toDouble();
                    final cardH = (cardW * 1.28)
                        .clamp(0.0, constraints.maxHeight - 12)
                        .toDouble();
                    final barsW = constraints.maxWidth;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        IgnorePointer(
                          child: Center(
                            child: ThreeDVisualizer(
                              isPlaying: player.isPlaying,
                              width: barsW,
                              height: constraints.maxHeight,
                              barCount: 19,
                            ),
                          ),
                        ),
                        CoverFlowCarousel(
                          itemCount: useAlbums ? albums.length : tracks.length,
                          initialIndex: targetIndex,
                          controller: _controller,
                          cardWidth: cardW,
                          cardHeight: cardH,
                          onPageChanged: _onPageChanged,
                          itemBuilder: (context, index) {
                            final item = useAlbums
                                ? player.allTracks
                                    .where((t) => t.album == albums[index])
                                    .toList()
                                    .first
                                : tracks[index];
                            return CoverFlowCard(
                              track: item,
                              width: cardW,
                              height: cardH,
                              isCurrent: item.id == track?.id,
                              onTap: () {
                                if (useAlbums) {
                                  final albumTracks = player.allTracks
                                      .where((t) => t.album == albums[index])
                                      .toList();
                                  if (albumTracks.isNotEmpty) {
                                    player.playFromPlaylist(albumTracks, 0);
                                  }
                                } else {
                                  player.playFromPlaylist(tracks, index);
                                }
                              },
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
              // Track info
              if (track != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: GestureDetector(
                    onTap: () => _openFullPlayer(context),
                    child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MarqueeText(
                              text: track.title,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.keyboard_arrow_up_rounded,
                            color: AppTheme.textSecondary),
                        onPressed: () => _openFullPlayer(context),
                        tooltip: 'Открыть плеер',
                      ),
                      IconButton(
                        icon: Icon(
                          track.isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: track.isFavorite
                              ? AppTheme.accentPink
                              : AppTheme.textSecondary,
                        ),
                        onPressed: player.toggleFavoriteCurrent,
                        tooltip: 'В избранное',
                      ),
                    ],
                  ),
                ),
              ),
              // Progress
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        activeTrackColor: AppTheme.accent,
                        inactiveTrackColor: AppTheme.surfaceLight,
                        thumbColor: AppTheme.accentLight,
                        thumbShape:
                            RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayColor: AppTheme.accent.withOpacity(0.15),
                      ),
                      child: Slider(
                        value: posFrac,
                        onChanged: (v) => player
                            .seek(Duration(milliseconds: (durMs * v).round())),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _fmt(player.position),
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 11),
                          ),
                          Text(
                            durMs > 0
                                ? '-${_fmt(player.duration - player.position)}'
                                : '',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Controls
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.shuffle_rounded),
                      color: player.shuffleMode
                          ? AppTheme.accentCyan
                          : AppTheme.textSecondary,
                      iconSize: 26,
                      onPressed: player.toggleShuffle,
                      tooltip: 'Перемешать',
                    ),
                    const SizedBox(width: 18),
                    IconButton(
                      icon: Icon(Icons.skip_previous_rounded,
                          color: AppTheme.textPrimary),
                      iconSize: 42,
                      onPressed: player.previous,
                      tooltip: 'Предыдущий',
                    ),
                    SizedBox(width: 14),
                    IconButton(
                      icon: Icon(
                        player.isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_filled_rounded,
                        color: AppTheme.accentLight,
                      ),
                      iconSize: 70,
                      onPressed: player.togglePlay,
                      tooltip: player.isPlaying ? 'Пауза' : 'Играть',
                    ),
                    const SizedBox(width: 14),
                    IconButton(
                      icon: Icon(Icons.skip_next_rounded,
                          color: AppTheme.textPrimary),
                      iconSize: 42,
                      onPressed: player.next,
                      tooltip: 'Следующий',
                    ),
                    const SizedBox(width: 18),
                    IconButton(
                      icon: Icon(
                        player.repeatMode == PlayerRepeatMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        color: player.repeatMode != PlayerRepeatMode.off
                            ? AppTheme.accentCyan
                            : AppTheme.textSecondary,
                      ),
                      iconSize: 26,
                      onPressed: player.toggleRepeat,
                      tooltip: 'Повтор',
                    ),
                  ],
                ),
              ),
              // Bottom actions: Personal DJ + Library
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppTheme.surface,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24)),
                        ),
                        builder: (_) => const PersonalDJSheet(),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              color: AppTheme.accentLight, size: 19),
                          SizedBox(width: 8),
                          Text(
                            'Personal DJ',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _openLibrary,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.list_rounded,
                              color: AppTheme.textSecondary, size: 19),
                          SizedBox(width: 8),
                          Text(
                            'Библиотека',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 0),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.primaryGradient.createShader(bounds),
            child: const Text(
              'Cover Flow',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.view_agenda_outlined,
                color: AppTheme.textSecondary),
            onPressed: () => context
                .read<UiStyleController>()
                .setStyle(PlayerUIStyle.simple),
            tooltip: 'Простой интерфейс',
          ),
          IconButton(
            icon: Icon(Icons.settings_rounded,
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
}