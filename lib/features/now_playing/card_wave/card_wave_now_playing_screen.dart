import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/ui_style.dart';
import '../../../widgets/queue_sheet.dart';
import 'card_wave_player_body.dart';
import 'card_wave_theme.dart';

/// Full-screen Cardwave player: the current track dealt on a dark card table.
class CardWaveNowPlayingScreen extends StatelessWidget {
  const CardWaveNowPlayingScreen({super.key});

  void _openQueue(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cardWaveBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const QueueSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cardWaveBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 5, 6, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Свернуть',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 29,
                    ),
                    color: cardWaveGoldSoft,
                  ),
                  const Expanded(
                    child: Column(
                      children: [
                        Text(
                          'THE DECK',
                          style: TextStyle(
                            color: cardWaveCream,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'NOW PLAYING',
                          style: TextStyle(
                            color: cardWaveMuted,
                            fontSize: 9,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Колода',
                    onPressed: () => _openQueue(context),
                    icon: const Icon(Icons.layers_rounded, size: 22),
                    color: cardWaveGoldSoft,
                  ),
                  IconButton(
                    tooltip: 'Следующий стиль',
                    onPressed: () => context.read<UiStyleController>().toggle(),
                    icon: const Icon(Icons.style_rounded, size: 22),
                    color: cardWaveGoldSoft,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF201B25),
                        Color(0xFF0D0D12),
                        Color(0xFF17131A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0x66C9B47C),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x44000000),
                        blurRadius: 28,
                        spreadRadius: -4,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(29),
                    child: const Stack(
                      children: [
                        Positioned(
                          left: 13,
                          top: 13,
                          child: _CornerMark(top: true, left: true),
                        ),
                        Positioned(
                          right: 13,
                          top: 13,
                          child: _CornerMark(top: true, left: false),
                        ),
                        Positioned(
                          left: 13,
                          bottom: 13,
                          child: _CornerMark(top: false, left: true),
                        ),
                        Positioned(
                          right: 13,
                          bottom: 13,
                          child: _CornerMark(top: false, left: false),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(4, 20, 4, 8),
                          child: CardWavePlayerBody(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerMark extends StatelessWidget {
  final bool top;
  final bool left;

  const _CornerMark({required this.top, required this.left});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: (top == left) ? 0 : 1.5708,
      child: const Icon(
        Icons.spa_outlined,
        color: cardWaveGold,
        size: 19,
      ),
    );
  }
}
