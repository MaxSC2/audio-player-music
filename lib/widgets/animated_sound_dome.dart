import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bars arranged in a 3D dome/arch behind the album art.
/// The closer a bar is to the vertical center, the deeper (smaller, raised)
/// it appears; the two side rows (left and right) come forward and grow,
/// with each bar tilting toward the center.
class AnimatedSoundDome extends StatefulWidget {
  final bool isPlaying;
  final double width;
  final double height;
  final int barCount;

  const AnimatedSoundDome({
    super.key,
    required this.isPlaying,
    required this.width,
    required this.height,
    this.barCount = 20,
  });

  @override
  State<AnimatedSoundDome> createState() => _AnimatedSoundDomeState();
}

class _AnimatedSoundDomeState extends State<AnimatedSoundDome>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.isPlaying) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant AnimatedSoundDome oldWidget) {
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: CustomPaint(
            painter: _SoundDomePainter(
              anim: _controller.value,
              isPlaying: widget.isPlaying,
              barCount: widget.barCount,
            ),
          ),
        );
      },
    );
  }
}

class _SoundDomePainter extends CustomPainter {
  final double anim;
  final bool isPlaying;
  final int barCount;

  _SoundDomePainter({
    required this.anim,
    required this.isPlaying,
    required this.barCount,
  });

  static const _cCyan = Color(0xFF06B6D4);
  static const _cGreen = Color(0xFF22C55E);
  static const _cPurple = Color(0xFFA855F7);

  @override
  void paint(Canvas canvas, Size size) {
    final half = (barCount / 2).ceil();
    final maxBarH = size.height * 0.6;
    final baseY = size.height - size.height * 0.06;
    final cx = size.width / 2;
    final usable = size.width - 12.0;
    final t = anim * math.pi * 2;

    for (int k = 0; k < half; k++) {
      final pos = half <= 1 ? 0.0 : k / (half - 1); // 0 (center) .. 1 (edge)
      for (final side in const [-1, 1]) {
        final tNorm = side * pos;
        final depth = math.cos(tNorm.abs() * math.pi / 2); // 1 center, 0 edge
        final scale = 1.0 / (1.0 + depth * 0.55);
        final x = cx + tNorm * (usable / 2);
        final barW = math.max(2.0, (size.width / barCount) * 1.5 * scale);
        final wave = isPlaying
            ? 0.3 + 0.7 * ((math.sin(t + k * 0.9 + side) + 1.0) / 2.0)
            : 0.3;
        final barH = math.max(3.0, maxBarH * scale * wave);
        final barBase = baseY - (1.0 - scale) * maxBarH * 0.45;
        final angle = tNorm * 0.5;

        final color = side == -1
            ? Color.lerp(_cGreen, _cCyan, pos)!
            : Color.lerp(_cGreen, _cPurple, pos)!;

        canvas.save();
        canvas.translate(x, barBase);
        canvas.rotate(angle);
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(-barW / 2, -barH, barW, barH),
          Radius.circular(barW / 2),
        );
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = color.withOpacity(0.95)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SoundDomePainter oldDelegate) =>
      oldDelegate.anim != anim ||
      oldDelegate.isPlaying != isPlaying ||
      oldDelegate.barCount != barCount;
}