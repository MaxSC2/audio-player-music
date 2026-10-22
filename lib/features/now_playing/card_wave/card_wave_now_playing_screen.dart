import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/ui_style.dart';
import '../../../providers/player_provider.dart';
import '../cinematic/cinematic_player_body.dart';

/// Full-screen Cardwave player: a dark card table with gilded borders.
class CardWaveNowPlayingScreen extends StatelessWidget {
  const CardWaveNowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final track = context.select<PlayerProvider, int?>((p) => p.currentTrack?.id);

    return Scaffold(
      backgroundColor: const Color(0xFF09090D),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 5, 10, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Свернуть',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 29),
                    color: const Color(0xFFD8C18A),
                  ),
                  const Expanded(
                    child: Column(
                      children: [
                        Text(
                          'THE DECK',
                          style: TextStyle(
                            color: Color(0xFFF2E8D3),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'NOW PLAYING',
                          style: TextStyle(
                            color: Color(0xFF9E927B),
                            fontSize: 9,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Следующий стиль',
                    onPressed: () => context.read<UiStyleController>().toggle(),
                    icon: const Icon(Icons.style_rounded),
                    color: const Color(0xFFD8C18A),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF201B25), Color(0xFF0D0D12), Color(0xFF17131A)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0x66C9B47C), width: 1.2),
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
                    child: Stack(
                      children: [
                        const Positioned(
                          left: 13,
                          top: 13,
                          child: _CornerMark(top: true, left: true),
                        ),
                        const Positioned(
                          right: 13,
                          top: 13,
                          child: _CornerMark(top: true, left: false),
                        ),
                        const Positioned(
                          left: 13,
                          bottom: 13,
                          child: _CornerMark(top: false, left: true),
                        ),
                        const Positioned(
                          right: 13,
                          bottom: 13,
                          child: _CornerMark(top: false, left: false),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 20, 6, 12),
                          child: CinematicPlayerBody(
                            key: ValueKey('cardwave-$track'),
                            fullControls: true,
                            edgeGlow: false,
                            stageRings: false,
                          ),
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
        color: Color(0xFFC9B47C),
        size: 19,
      ),
    );
  }
}