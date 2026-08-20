import 'dart:math';
import 'package:flutter/material.dart';
import '../ui/theme.dart';
import 'cached_artwork.dart';

class SpinningVinyl extends StatefulWidget {
  final int? trackId;
  final bool isPlaying;
  final double size;
  final bool showVinylGrooves;

  const SpinningVinyl({
    super.key,
    this.trackId,
    required this.isPlaying,
    this.size = 220.0,
    this.showVinylGrooves = true,
  });

  @override
  State<SpinningVinyl> createState() => _SpinningVinylState();
}

class _SpinningVinylState extends State<SpinningVinyl>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _syncAnimations();
  }

  @override
  void didUpdateWidget(covariant SpinningVinyl oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimations();
  }

  void _syncAnimations() {
    if (widget.isPlaying) {
      if (!_spinController.isAnimating) _spinController.repeat();
      if (!_glowController.isAnimating) {
        _glowController.repeat(reverse: true);
      }
    } else {
      if (_spinController.isAnimating) _spinController.stop();
      if (_glowController.isAnimating) _glowController.stop();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_spinController, _glowController]),
        builder: (context, child) {
          final glow = _glowController.value;
          final artworkSize = widget.size * 0.55;

          return Transform.rotate(
            angle: _spinController.value * 2 * pi,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0F1017),
                boxShadow: [
                  BoxShadow(
                    color: widget.isPlaying
                        ? AppTheme.accent
                            .withOpacity(0.25 + glow * 0.3)
                        : Colors.black.withOpacity(0.4),
                    blurRadius: widget.isPlaying ? 20 + glow * 18 : 16,
                    spreadRadius: widget.isPlaying ? 3 + glow * 4 : 1,
                  ),
                  BoxShadow(
                    color: widget.isPlaying
                        ? AppTheme.accentCyan.withOpacity(0.12 + glow * 0.2)
                        : Colors.transparent,
                    blurRadius: 30 + glow * 20,
                    spreadRadius: 2 + glow * 2,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Vinyl Grooves
                  if (widget.showVinylGrooves)
                    CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: VinylGroovesPainter(),
                    ),

                  // Center Album Art (non-rotating)
                  Container(
                    width: artworkSize,
                    height: artworkSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: widget.trackId != null
                        ? CachedArtwork(
                            trackId: widget.trackId!,
                            width: artworkSize,
                            height: artworkSize,
                            radius: artworkSize / 2,
                          )
                        : _buildFallbackArtwork(artworkSize),
                  ),

                  // Gloss / shine overlay
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.35, -0.45),
                        radius: 0.9,
                        colors: [
                          Colors.white.withOpacity(widget.isPlaying ? 0.09 : 0.04),
                          Colors.transparent,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),

                  // Center Vinyl Spindle Hole
                  Container(
                    width: widget.size * 0.1,
                    height: widget.size * 0.1,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.background,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFallbackArtwork(double artworkSize) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.pinkPurpleGradient,
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: artworkSize * 0.5,
          color: Colors.white,
        ),
      ),
    );
  }
}

class VinylGroovesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0x18FFFFFF)
      ..strokeWidth = 1.0;

    for (double r = radius * 0.62; r < radius * 0.96; r += 7.0) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}