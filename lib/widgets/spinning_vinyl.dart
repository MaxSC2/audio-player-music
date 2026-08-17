import 'dart:math';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../ui/theme.dart';

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
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SpinningVinyl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _controller.value * 2 * pi,
            child: child,
          );
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0F1017),
            boxShadow: [
              BoxShadow(
                color: widget.isPlaying
                    ? AppTheme.accent.withOpacity(0.35)
                    : Colors.black.withOpacity(0.4),
                blurRadius: widget.isPlaying ? 28 : 16,
                spreadRadius: widget.isPlaying ? 4 : 1,
              ),
              BoxShadow(
                color: widget.isPlaying
                    ? AppTheme.accentCyan.withOpacity(0.2)
                    : Colors.transparent,
                blurRadius: 36,
                spreadRadius: 2,
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

              // Center Album Art
              ClipRRect(
                borderRadius: BorderRadius.circular(widget.size * 0.45),
                child: Container(
                  width: widget.size * 0.55,
                  height: widget.size * 0.55,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                  ),
                  child: widget.trackId != null
                      ? QueryArtworkWidget(
                          id: widget.trackId!,
                          type: ArtworkType.AUDIO,
                          artworkBorder: BorderRadius.circular(widget.size),
                          nullArtworkWidget: _buildFallbackArtwork(),
                          errorBuilder: (ctx, err, stack) =>
                              _buildFallbackArtwork(),
                        )
                      : _buildFallbackArtwork(),
                ),
              ),

              // Center Vinyl Spindle Hole
              Container(
                width: widget.size * 0.12,
                height: widget.size * 0.12,
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
      ),
    );
  }

  Widget _buildFallbackArtwork() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.pinkPurpleGradient,
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: widget.size * 0.25,
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
