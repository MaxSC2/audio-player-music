import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/audio_visualizer.dart';

/// Живой неоновый эквалайзер: полосы реагируют на РЕАЛЬНЫЙ звук
/// (данные из нативного Visualizer). Пока данных нет — рисует органичную
/// синтетику с бит-пульсацией, чтобы сцена не «умирала».
class LiveEqualizer extends StatefulWidget {
  final bool isPlaying;
  final Color accent;
  final double height;
  final int bands;

  const LiveEqualizer({
    super.key,
    required this.isPlaying,
    required this.accent,
    this.height = 72,
    this.bands = 40,
  });

  @override
  State<LiveEqualizer> createState() => _LiveEqualizerState();
}

class _LiveEqualizerState extends State<LiveEqualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tick;
  late final int _n = widget.bands;
  late final List<double> _vals = List<double>.filled(_n, 0.05);
  late final List<double> _peaks = List<double>.filled(_n, 0.05);
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _tick = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    // Лениво просим доступ к аудио только когда эквалайзер реально показан.
    // acquire() держит поток, пока виджет на экране (B4).
    AudioVisualizer.acquire();
  }

  @override
  void didUpdateWidget(covariant LiveEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      AudioVisualizer.ensureStarted();
    }
  }

  @override
  void dispose() {
    // B4: уходим с экрана — счётчик потребителей вниз; при нуле поток
    // и нативный Visualizer гасятся (микрофон/батарея).
    AudioVisualizer.release();
    _tick.dispose();
    super.dispose();
  }

  /// Синтетическая, но музыкальная замена (когда нет реальных данных).
  double _synth(int i, double t) {
    final a = math.sin(t * 2.4 + i * 0.7) * 0.5 + 0.5;
    final b = math.sin(t * 1.1 + i * 1.9) * 0.5 + 0.5;
    final c = math.sin(t * 5.2 + i * 0.37) * 0.5 + 0.5;
    final band = 1.0 - (i / _n) * 0.55;
    return ((a * 0.5 + b * 0.3 + c * 0.2) * band).clamp(0.0, 1.0);
  }

  void _step(double dt) {
    _t += dt;
    final real = AudioVisualizer.levels.value;
    final live = AudioVisualizer.available.value && widget.isPlaying;
    for (var i = 0; i < _n; i++) {
      double target;
      if (live && real.isNotEmpty) {
        final pos = (i * real.length / _n).floor();
        target = real[pos.clamp(0, real.length - 1)];
      } else if (widget.isPlaying) {
        target = _synth(i, _t);
      } else {
        target = 0.04 + 0.02 * math.sin(_t * 2 + i);
      }
      final prev = _vals[i];
      _vals[i] = target > prev
          ? prev + (target - prev) * 0.62
          : prev + (target - prev) * 0.10;
      // Пик держится, затем мягко опадает.
      _peaks[i] = _peaks[i] > _vals[i]
          ? math.max(_vals[i], _peaks[i] - 0.012)
          : _vals[i];
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _tick,
          builder: (context, _) {
            _step(1 / 60);
            return CustomPaint(
              painter: _EqPainter(
                vals: _vals,
                peaks: _peaks,
                accent: widget.accent,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EqPainter extends CustomPainter {
  final List<double> vals;
  final List<double> peaks;
  final Color accent;

  _EqPainter({
    required this.vals,
    required this.peaks,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = vals.length;
    if (n == 0) return;
    final gap = size.width / n;
    final barW = math.min(gap * 0.5, 8.0);
    final radius = Radius.circular(barW / 2);
    final midY = size.height / 2;

    var avg = 0.0;
    for (final v in vals) {
      avg += v;
    }
    avg /= n;

    // Неоновое «свечение пола» — пульсирует от громкости.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 1.15),
          radius: 0.95,
          colors: [
            accent.withValues(alpha: (0.22 + 0.3 * avg).clamp(0.0, 0.62)),
            accent.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );

    // Тихий спектральный «частокол» на фоне — глубина сцены.
    final barPaint = Paint()
      ..color = accent.withValues(alpha: 0.16 + 0.1 * avg);
    for (var i = 0; i < n; i++) {
      final v = vals[i].clamp(0.0, 1.0);
      final h = (0.08 + 0.55 * v) * size.height;
      final cx = gap * i + gap / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, midY), width: barW, height: h),
          radius,
        ),
        barPaint,
      );
    }

    // Зеркальная волна: верхняя и нижняя огибающие.
    final top = <Offset>[];
    final bottom = <Offset>[];
    for (var i = 0; i < n; i++) {
      final v = vals[i].clamp(0.0, 1.0);
      final next = vals[(i + 3) % n].clamp(0.0, 1.0);
      final cx = gap * i + gap / 2;
      final amp = (0.045 + 0.45 * v) * size.height;
      top.add(Offset(cx, midY - amp));
      bottom.add(Offset(cx, midY + amp * (0.68 + 0.32 * next)));
    }

    final topPath = Path();
    _addSmooth(topPath, top);
    final bottomPath = Path();
    _addSmooth(bottomPath, bottom.reversed.toList());

    final fill = Path();
    _addSmooth(fill, top);
    fill.lineTo(bottom.last.dx, bottom.last.dy);
    _addSmooth(fill, bottom.reversed.toList(), startNew: false);
    fill.close();

    final bodyShader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        accent.withValues(alpha: 0.06),
        accent.withValues(alpha: 0.34),
        Color.lerp(accent, Colors.white, 0.62)!.withValues(alpha: 0.5),
        accent.withValues(alpha: 0.34),
        accent.withValues(alpha: 0.06),
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
    ).createShader(Offset.zero & size);

    canvas.drawPath(fill, Paint()..shader = bodyShader);

    final glow = Paint()
      ..color = accent.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    canvas.drawPath(topPath, glow);
    canvas.drawPath(bottomPath, glow..color = accent.withValues(alpha: 0.35));

    final strokeShader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        accent.withValues(alpha: 0.2),
        Colors.white.withValues(alpha: 0.92),
        accent.withValues(alpha: 0.2),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Offset.zero & size);
    final line = Paint()
      ..shader = strokeShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(topPath, line);
    canvas.drawPath(bottomPath, line);

    // Центральная ось — тонкая неоновая линия.
    canvas.drawLine(
      Offset(0, midY),
      Offset(size.width, midY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 1,
    );
  }

  void _addSmooth(Path path, List<Offset> points, {bool startNew = true}) {
    if (points.isEmpty) return;
    if (startNew) {
      path.moveTo(points.first.dx, points.first.dy);
    } else {
      path.lineTo(points.first.dx, points.first.dy);
    }
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final cur = points[i];
      final mid = Offset((prev.dx + cur.dx) / 2, (prev.dy + cur.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
  }

  @override
  bool shouldRepaint(covariant _EqPainter old) => true;
}
