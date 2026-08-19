import 'package:flutter/material.dart';
import '../models/audio_track.dart';
import '../ui/theme.dart';
import 'cached_artwork.dart';

class CoverFlowCard extends StatelessWidget {
  final AudioTrack track;
  final double width;
  final double height;
  final bool showReflection;
  final VoidCallback onTap;

  const CoverFlowCard({
    super.key,
    required this.track,
    required this.width,
    required this.height,
    this.showReflection = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final reflectionHeight = showReflection ? height * 0.16 : 0.0;
    final gap = showReflection ? 8.0 : 0.0;
    final artHeight = height - reflectionHeight - gap;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: width,
            height: artHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withOpacity(0.22),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CachedArtwork(
                trackId: track.id,
                width: width,
                height: artHeight,
                radius: 0,
              ),
            ),
          ),
        ),
        if (showReflection) ...[
          SizedBox(
            height: gap,
          ),
          SizedBox(
            width: width,
            height: reflectionHeight,
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Transform(
                      alignment: Alignment.topCenter,
                      transform: Matrix4.identity()..scale(1.0, -1.0),
                      child: Opacity(
                        opacity: 0.28,
                        child: CachedArtwork(
                          trackId: track.id,
                          width: width,
                          height: reflectionHeight,
                          radius: 0,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppTheme.background.withOpacity(0.2),
                              AppTheme.background,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}