import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/ui_style.dart';
import '../../../providers/player_provider.dart';
import '../../../ui/theme.dart';
import '../../../widgets/three_d_visualizer.dart';
import '../../../widgets/cover_flow_card.dart';
import '../../../widgets/cover_flow_carousel.dart';
import '../../../widgets/marquee_text.dart';
import '../../../widgets/three_d_background.dart';

class CoverFlowNowPlayingScreen extends StatefulWidget {
  const CoverFlowNowPlayingScreen({super.key});

  @override
  State<CoverFlowNowPlayingScreen> createState() =>
      _CoverFlowNowPlayingScreenState();
}

class _CoverFlowNowPlayingScreenState extends State<CoverFlowNowPlayingScreen> {
  PageController? _controller;
  int _lastSyncedIndex = -1;

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  void _onPageChanged(int index) {
    final player = context.read<PlayerProvider>();
    if (player.currentIndex == index) return;
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      final p = context.read<PlayerProvider>();
      final settled =
          (_controller?.hasClients ?? false) ? _controller!.page!.round() : index;
      if (settled == index && p.currentIndex != index) {
        p.playAt(index);
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final playlist = player.playlist;
    final track = player.currentTrack;

    if (playlist.isEmpty || track == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(leading: const SizedBox.shrink()),
        body: const Center(
          child: Text(
            'Нет воспроизводимого трека',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ),
      );
    }

    final currentIndex =
        (player.currentIndex < 0 ? 0 : player.currentIndex)
            .clamp(0, playlist.length - 1)
            .toInt();

    _controller ??= PageController(
      viewportFraction: 0.72,
      initialPage: currentIndex,
    );

    if (currentIndex != _lastSyncedIndex) {
      _lastSyncedIndex = currentIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _controller == null) return;
        final c = _controller!;
        if (c.hasClients && (c.page ?? 0).round() != currentIndex) {
          c.jumpToPage(currentIndex);
        }
      });
    }

    final screenW = MediaQuery.sizeOf(context).width;
    final cardW = (screenW * 0.70 - 12).clamp(180.0, 270.0).toDouble();
    final posMs = player.position.inMilliseconds;
    final durMs = player.duration.inMilliseconds;
    final posFrac = durMs > 0 ? (posMs / durMs).clamp(0.0, 1.0).toDouble() : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: ThreeDBackground(
        child: SafeArea(
          child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.textSecondary, size: 30),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Свернуть',
                  ),
                  IconButton(
                    icon: const Icon(Icons.view_agenda_outlined,
                        color: AppTheme.textSecondary, size: 22),
                    onPressed: () =>
                        context.read<UiStyleController>().setStyle(
                            PlayerUIStyle.simple),
                    tooltip: 'Простой интерфейс',
                  ),
                  const Spacer(),
                  const Text(
                    'Сейчас играет',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      track.isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: track.isFavorite
                          ? AppTheme.accentPink
                          : AppTheme.textSecondary,
                      size: 24,
                    ),
                    onPressed: player.toggleFavoriteCurrent,
                    tooltip: 'В избранное',
                  ),
                ],
              ),
            ),

            // 3D Cover Flow
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cardH = (cardW * 1.26)
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
                        itemCount: playlist.length,
                        initialIndex: currentIndex,
                        controller: _controller,
                        cardWidth: cardW,
                        cardHeight: cardH,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, index) {
                          return CoverFlowCard(
                            track: playlist[index],
                            width: cardW,
                            height: cardH,
                            isCurrent: playlist[index].id == track.id,
                            onTap: () => player.playAt(index),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),

            // Track info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  MarqueeText(
                    text: track.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    track.artist,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),

            // Progress slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      activeTrackColor: AppTheme.accent,
                      inactiveTrackColor: AppTheme.surfaceLight,
                      thumbColor: AppTheme.accentLight,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7),
                      overlayColor: AppTheme.accent.withOpacity(0.15),
                    ),
                    child: Slider(
                      value: posFrac,
                      onChanged: (v) =>
                          player.seek(Duration(milliseconds: (durMs * v).round())),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _fmt(player.position),
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 11),
                        ),
                        Text(
                          '-${_fmt(player.duration - player.position)}',
                          style: const TextStyle(
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
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shuffle_rounded),
                    color: player.shuffleMode
                        ? AppTheme.accentCyan
                        : AppTheme.textSecondary,
                    iconSize: 26,
                    onPressed: player.toggleShuffle,
                    tooltip: 'Перемешать',
                  ),
                  const SizedBox(width: 22),
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded,
                        color: AppTheme.textPrimary),
                    iconSize: 42,
                    onPressed: player.previous,
                    tooltip: 'Предыдущий',
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: Icon(
                      player.isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_filled_rounded,
                      color: AppTheme.accentLight,
                    ),
                    iconSize: 74,
                    onPressed: player.togglePlay,
                    tooltip: player.isPlaying ? 'Пауза' : 'Играть',
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded,
                        color: AppTheme.textPrimary),
                    iconSize: 42,
                    onPressed: player.next,
                    tooltip: 'Следующий',
                  ),
                  const SizedBox(width: 22),
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

            // Thin progress line
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
              child: LinearProgressIndicator(
                value: posFrac,
                minHeight: 3,
                backgroundColor: AppTheme.surfaceLight,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}