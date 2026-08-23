import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' show ImageFilter;

import '../../../providers/player_provider.dart';
import '../../../ui/theme.dart';
import '../../../widgets/three_d_visualizer.dart';
import '../../../widgets/cover_flow_card.dart';
import '../../../widgets/cover_flow_carousel.dart';
import '../../../widgets/marquee_text.dart';
import '../../../widgets/player_feature_row.dart';

/// Полупрозрачная всплывающая панель плеера для 3D-режима.
/// Домашний экран остаётся главным плеером — панель лишь раскрывает
/// все функции поверх него, на весь экран не разворачивается.
class CoverFlowPlayerSheet extends StatefulWidget {
  const CoverFlowPlayerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => const CoverFlowPlayerSheet(),
    );
  }

  @override
  State<CoverFlowPlayerSheet> createState() => _CoverFlowPlayerSheetState();
}

class _CoverFlowPlayerSheetState extends State<CoverFlowPlayerSheet> {
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
      return const SizedBox.shrink();
    }

    final screenH = MediaQuery.sizeOf(context).height;
    final screenW = MediaQuery.sizeOf(context).width;

    final currentIndex =
        (player.currentIndex < 0 ? 0 : player.currentIndex)
            .clamp(0, playlist.length - 1)
            .toInt();

    _controller ??= PageController(
      viewportFraction: 0.62,
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

    final cardW = (screenW * 0.52 - 10).clamp(150.0, 210.0).toDouble();
    final posMs = player.position.inMilliseconds;
    final durMs = player.duration.inMilliseconds;
    final posFrac = durMs > 0 ? (posMs / durMs).clamp(0.0, 1.0).toDouble() : 0.0;

    final panelColor = AppTheme.lightMode
        ? Colors.white.withOpacity(0.93)
        : AppTheme.surface.withOpacity(0.88);

    return Padding(
      padding: EdgeInsets.only(
        top: screenH * 0.09,
        left: 12,
        right: 12,
        bottom: 14,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              color: panelColor,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppTheme.cardBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withOpacity(0.28),
                  blurRadius: 42,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Хваталка
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Верхняя строка
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppTheme.textSecondary, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Свернуть',
                      ),
                      Expanded(
                        child: Text(
                          'Сейчас играет',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          track.isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: track.isFavorite
                              ? AppTheme.accentPink
                              : AppTheme.textSecondary,
                          size: 22,
                        ),
                        onPressed: player.toggleFavoriteCurrent,
                        tooltip: 'В избранное',
                      ),
                    ],
                  ),
                ),

                // Карусель с визуализатором
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cardH = (cardW * 1.26)
                          .clamp(0.0, constraints.maxHeight - 8)
                          .toDouble();
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          IgnorePointer(
                            child: Center(
                              child: ThreeDVisualizer(
                                isPlaying: player.isPlaying,
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                                barCount: 15,
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

                // Инфо о треке
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Column(
                    children: [
                      MarqueeText(
                        text: track.title,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track.artist,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // Прогресс
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          activeTrackColor: AppTheme.accent,
                          inactiveTrackColor: AppTheme.surfaceLight,
                          thumbColor: AppTheme.accentLight,
                          thumbShape:
                              const RoundSliderThumbShape(enabledThumbRadius: 7),
                          overlayColor: AppTheme.accent.withOpacity(0.15),
                        ),
                        child: Slider(
                          value: posFrac,
                          onChanged: (v) => player.seek(
                              Duration(milliseconds: (durMs * v).round())),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(player.position),
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 11)),
                            Text('-${_fmt(player.duration - player.position)}',
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Управление
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.shuffle_rounded),
                        color: player.shuffleMode
                            ? AppTheme.accentCyan
                            : AppTheme.textSecondary,
                        iconSize: 24,
                        onPressed: player.toggleShuffle,
                        tooltip: 'Перемешать',
                      ),
                      const SizedBox(width: 14),
                      IconButton(
                        icon: Icon(Icons.skip_previous_rounded,
                            color: AppTheme.textPrimary),
                        iconSize: 38,
                        onPressed: player.previous,
                        tooltip: 'Предыдущий',
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(
                          player.isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                          color: AppTheme.accentLight,
                        ),
                        iconSize: 64,
                        onPressed: player.togglePlay,
                        tooltip: player.isPlaying ? 'Пауза' : 'Играть',
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(Icons.skip_next_rounded,
                            color: AppTheme.textPrimary),
                        iconSize: 38,
                        onPressed: player.next,
                        tooltip: 'Следующий',
                      ),
                      const SizedBox(width: 14),
                      IconButton(
                        icon: Icon(
                          player.repeatMode == PlayerRepeatMode.one
                              ? Icons.repeat_one_rounded
                              : Icons.repeat_rounded,
                          color: player.repeatMode != PlayerRepeatMode.off
                              ? AppTheme.accentCyan
                              : AppTheme.textSecondary,
                        ),
                        iconSize: 24,
                        onPressed: player.toggleRepeat,
                        tooltip: 'Повтор',
                      ),
                    ],
                  ),
                ),

                // Лента функций
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
                  child: PlayerFeatureRow(track: track),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
