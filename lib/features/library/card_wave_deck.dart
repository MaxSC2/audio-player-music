import 'package:flutter/material.dart';

import '../../widgets/cached_artwork.dart';
import '../now_playing/card_wave/card_wave_theme.dart';

class CardWaveDeck extends StatelessWidget {
  final String title;
  final String subtitle;
  final int? artTrackId;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final Widget? menu;

  const CardWaveDeck({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
    this.artTrackId,
    this.onPlay,
    this.menu,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 8,
            right: 8,
            top: 0,
            bottom: 20,
            child: Transform.rotate(
              angle: -0.055,
              child: const _DeckBack(),
            ),
          ),
          Positioned(
            left: 4,
            right: 4,
            top: 6,
            bottom: 12,
            child: Transform.rotate(
              angle: 0.035,
              child: const _DeckBack(bright: true),
            ),
          ),
          Positioned(
            left: 1,
            right: 1,
            top: 12,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: cardWaveSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xCCC9B47C),
                    width: 1.3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x77000000),
                      blurRadius: 14,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LayoutBuilder(
                    builder: (context, box) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          _art(width: box.maxWidth, height: box.maxHeight),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x22000000),
                                  Color(0x00000000),
                                  Color(0xD9000000),
                                ],
                                stops: [0, 0.42, 1],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 7,
                            left: 7,
                            child: _DeckTag(icon: icon),
                          ),
                          if (menu != null)
                            Positioned(
                              top: 3,
                              right: 3,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xB309090D),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0x66C9B47C),
                                  ),
                                ),
                                child: menu,
                              ),
                            ),
                          Positioned(
                            left: 9,
                            right: 7,
                            bottom: 7,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: cardWaveCream,
                                          fontSize: 13,
                                          height: 1.12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFFBDB29D),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (onPlay != null) ...[
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: onPlay,
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xCC09090D),
                                        border: Border.all(
                                          color: cardWaveGold,
                                          width: 1.1,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: cardWaveCream,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _art({required double width, required double height}) {
    final fallback = Container(
      decoration: BoxDecoration(gradient: gradient),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.9),
          size: 42,
        ),
      ),
    );
    if (artTrackId == null) return fallback;
    return CachedArtwork(
      trackId: artTrackId!,
      width: width,
      height: height,
      radius: 0,
      fallback: fallback,
    );
  }
}

class _DeckBack extends StatelessWidget {
  final bool bright;

  const _DeckBack({this.bright = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF211B26), Color(0xFF0B0A0E)],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: bright ? const Color(0x99C9B47C) : const Color(0x665B503B),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 30,
            height: 1,
            color: bright ? cardWaveGold : const Color(0x665B503B),
          ),
        ),
      ),
    );
  }
}

class _DeckTag extends StatelessWidget {
  final IconData icon;

  const _DeckTag({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xB309090D),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x66C9B47C)),
      ),
      child: Icon(icon, color: cardWaveGold, size: 13),
    );
  }
}
