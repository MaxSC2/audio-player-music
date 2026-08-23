import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' show ImageFilter;

import '../../../providers/player_provider.dart';
import '../../../ui/theme.dart';
import '../../../widgets/marquee_text.dart';
import '../../../widgets/player_feature_row.dart';

/// Полупрозрачное всплывающее меню дополнительных функций для 3D-режима.
/// Только доп. кнопки — основной плеер остаётся на домашнем экране.
class CoverFlowPlayerSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final track = player.currentTrack;
    if (track == null) return const SizedBox.shrink();

    final panelColor = AppTheme.lightMode
        ? Colors.white.withOpacity(0.93)
        : AppTheme.surface.withOpacity(0.88);

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 14, top: 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              color: panelColor,
              borderRadius: BorderRadius.circular(26),
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
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Хваталка
                  Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Заголовок + трек
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Дополнительно',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              SizedBox(
                                width: double.infinity,
                                child: MarqueeText(
                                  text:
                                      '${track.title} — ${track.artist}',
                                  style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.keyboard_arrow_down_rounded,
                              color: AppTheme.textSecondary, size: 26),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Закрыть',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Лента дополнительных функций
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: PlayerFeatureRow(track: track),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
