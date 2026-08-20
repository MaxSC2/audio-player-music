import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Symmetric 3D visualizer placed behind the album cover.
///
/// Bars are true 3D blocks: each has a beveled front face, a visible side
/// face, a lit top face, per-bar perspective projection (Matrix4-style via
/// manual projection), depth offset and rotation that grow with distance from
/// the center. The center is deepest and smallest; the edges are closest and
/// largest. Left/right halves are mirror-symmetric. Heights react to a smooth
/// audio wave (lerp-smoothed), never random.
class ThreeDVisualizer extends StatefulWidget {
  final bool isPlaying;
  final double width;
  final double height;
  final int barCount;

  const ThreeDVisualizer({
    super.key,
    required this.isPlaying,
    required this.width,
    required this.height,
    this.barCount = 19,
  });

  @override
  State<ThreeDVisualizer> createState() => _ThreeDVisualizerState();
}

class _ThreeDVisualizerState extends State<ThreeDVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<double> _heights;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _heights = List.filled(widget.barCount, 0.08);
    _controller.addListener(_onTick);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  List<double> _targetHeights(double t) {
    final n = widget.barCount;
    final c = (n - 1) / 2;
    final playing = widget.isPlaying;
    final pump = 0.6 + 0.4 * math.sin(t * 2 * math.pi * 0.9);
    return List<double>.generate(n, (i) {
      final d = (i - c).abs() / c;
      // static symmetric perspective: edge ~100%, center ~25%
      final persp = 0.22 + 0.78 * math.pow(d, 1.12);
      double amp;
      if (playing) {
        final wave = 0.5 + 0.5 * math.sin(t * 2 * math.pi * 1.3 + i * 0.55);
        amp = (0.3 + 0.7 * (0.5 * wave + 0.5 * pump)).clamp(0.2, 1.15);
      } else {
        amp = 0.16;
      }
      return persp * amp;
    });
  }

  void _onTick() {
    final target = _targetHeights(_controller.value);
    for (var i = 0; i < _heights.length; i++) {
      _heights[i] += (target[i] - _heights[i]) * 0.18;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: CustomPaint(
        painter: _VisualizerPainter(
          heights: _heights,
          barCount: widget.barCount,
        ),
      ),
    );
  }
}

class _VisualizerPainter extends CustomPainter {
  final List<double> heights;
  final int barCount;

  _VisualizerPainter({required this.heights, required this.barCount});

  static const _stops = <Color>[
    Color(0xFF22D3EE), // cyan
    Color(0xFF3B82F6), // blue
    Color(0xFFA855F7), // purple
    Color(0xFFEC4899), // magenta
  ];

  static Color _colorAt(double t) {
    final u = (t + 1) / 2;
    final seg = (u * 3).clamp(0.0, 2.99);
    final idx = seg.floor();
    final f = seg - idx;
    return Color.lerp(_stops[idx], _stops[idx + 1], f)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = (barCount - 1) / 2;
    final maxH = size.height * 0.74;
    final floorY = size.height - 10;
    final centerX = size.width / 2;
    final f = size.width * 2.1;
    final barW = (size.width / (barCount + 4)) * 1.7;
    final depth = barW * 1.05;

    for (var i = 0; i < barCount; i++) {
      final t = (i - c) / c;
      final d = t.abs();
      final scale = 0.55 + 0.45 * d;
      final x = centerX + t * (size.width / 2 - 6);
      final baseY = floorY - (1 - scale) * maxH * 0.42;
      final zDepth = -(1 - scale) * size.width * 0.30;
      final rotY = t * 0.30;
      final h = maxH * heights[i].clamp(0.0, 1.2);
      final color = _colorAt(t);
      if (h < 1.5) continue;
      _drawBar(
        canvas,
        x: x,
        baseY: baseY,
        zDepth: zDepth,
        rotY: rotY,
        scale: scale,
        w: barW,
        depth: depth,
        h: h,
        f: f,
        color: color,
      );
    }

    _drawFloorGlow(canvas, size, floorY);
  }

  Offset _project(
    double lx,
    double ly,
    double lz, {
    required double x,
    required double baseY,
    required double zDepth,
    required double rotY,
    required double scale,
    required double f,
  }) {
    lx *= scale;
    ly *= scale;
    lz *= scale;
    final cr = math.cos(rotY);
    final sr = math.sin(rotY);
    final rx = lx * cr + lz * sr;
    final rz = -lx * sr + lz * cr;
    final z = zDepth + rz;
    final p = f / (f - z);
    return Offset(x + rx * p, baseY - ly * p);
  }

  void _drawBar(
    Canvas canvas, {
    required double x,
    required double baseY,
    required double zDepth,
    required double rotY,
    required double scale,
    required double w,
    required double depth,
    required double h,
    required double f,
    required Color color,
  }) {
    final halfW = w / 2;
    final halfD = depth / 2;

    Offset pr(double lx, double ly, double lz) => _project(
          lx,
          ly,
          lz,
          x: x,
          baseY: baseY,
          zDepth: zDepth,
          rotY: rotY,
          scale: scale,
          f: f,
        );

    final pFL = pr(-halfW, 0, halfD);
    final pFR = pr(halfW, 0, halfD);
    final pTR = pr(halfW, h, halfD);
    final pTL = pr(-halfW, h, halfD);
    final bFL = pr(-halfW, 0, -halfD);
    final bFR = pr(halfW, 0, -halfD);
    final bTR = pr(halfW, h, -halfD);
    final bTL = pr(-halfW, h, -halfD);

    final nzFront = math.cos(rotY);
    final nzRight = -math.sin(rotY);
    final nzLeft = math.sin(rotY);

    // Soft glow concentrated near the base.
    final glowCenter = Offset((pFL.dx + pTR.dx) / 2, (pFL.dy + pTR.dy) / 2);
    final glowRect = Rect.fromCenter(
      center: glowCenter,
      width: w * scale * 1.7,
      height: math.max(10, h * scale * 1.1),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(glowRect, Radius.circular(w * scale * 0.5)),
      Paint()
        ..color = color.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Side face (one side per bar, turned into the scene).
    final sideFill = Color.lerp(color, Colors.black, 0.52)!.withOpacity(0.9);
    if (nzRight > 0.02) {
      final path = Path()
        ..moveTo(pFR.dx, pFR.dy)
        ..lineTo(bFR.dx, bFR.dy)
        ..lineTo(bTR.dx, bTR.dy)
        ..lineTo(pTR.dx, pTR.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = sideFill);
    } else if (nzLeft > 0.02) {
      final path = Path()
        ..moveTo(pFL.dx, pFL.dy)
        ..lineTo(bFL.dx, bFL.dy)
        ..lineTo(bTL.dx, bTL.dy)
        ..lineTo(pTL.dx, pTL.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = sideFill);
    }

    // Front face with bevel (rounded quad following the projected corners).
    if (nzFront > 0.02) {
      final r = math.max(1.5, w * scale * 0.22);
      final frontPath = _roundedQuad(pFL, pFR, pTR, pTL, r);
      final bounds = Rect.fromPoints(
        Offset(
          math.min(math.min(pFL.dx, pFR.dx), math.min(pTL.dx, pTR.dx)),
          math.min(math.min(pFL.dy, pFR.dy), math.min(pTL.dy, pTR.dy)),
        ),
        Offset(
          math.max(math.max(pFL.dx, pFR.dx), math.max(pTL.dx, pTR.dx)),
          math.max(math.max(pFL.dy, pFR.dy), math.max(pTL.dy, pTR.dy)),
        ),
      );
      final frontPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, 0.22)!,
            Color.lerp(color, Colors.black, 0.12)!,
          ],
        ).createShader(bounds);
      canvas.drawPath(frontPath, frontPaint);

      // Glowing top edge.
      canvas.drawLine(
        pTL,
        pTR,
        Paint()
          ..color = Color.lerp(color, Colors.white, 0.6)!
              .withOpacity(0.9)
          ..strokeWidth = math.max(1.4, w * scale * 0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // Top face (lit).
    if (h > 0.3) {
      final topPath = Path()
        ..moveTo(pTL.dx, pTL.dy)
        ..lineTo(pTR.dx, pTR.dy)
        ..lineTo(bTR.dx, bTR.dy)
        ..lineTo(bTL.dx, bTL.dy)
        ..close();
      canvas.drawPath(
        topPath,
        Paint()
          ..color = Color.lerp(color, Colors.white, 0.3)!
              .withOpacity(0.95),
      );
    }
  }

  Path _roundedQuad(Offset a, Offset b, Offset c, Offset d, double r) {
    // a = bottom-left, b = bottom-right, c = top-right, d = top-left
    final p = Path();
    p.moveTo(a.dx + r, a.dy);
    p.lineTo(b.dx - r, b.dy);
    p.quadraticBezierTo(b.dx, b.dy, b.dx, b.dy - r);
    p.lineTo(c.dx, c.dy + r);
    p.quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy);
    p.lineTo(d.dx + r, d.dy);
    p.quadraticBezierTo(d.dx, d.dy, d.dx, d.dy + r);
    p.lineTo(a.dx, a.dy - r);
    p.quadraticBezierTo(a.dx, a.dy, a.dx + r, a.dy);
    p.close();
    return p;
  }

  void _drawFloorGlow(Canvas canvas, Size size, double floorY) {
    final bandH = math.min(80.0, size.height * 0.28);
    final rect = Rect.fromLTWH(0, floorY - bandH, size.width, bandH);
    final g = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF22D3EE).withOpacity(0),
          const Color(0xFF22D3EE).withOpacity(0.10),
          const Color(0xFFA855F7).withOpacity(0.16),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, g);
  }

  @override
  bool shouldRepaint(covariant _VisualizerPainter oldDelegate) => true;
}