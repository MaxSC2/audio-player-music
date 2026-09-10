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
    this.bands = AudioVisualizer.bands,
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
    if (widget.isPlaying) {
      AudioVisualizer.ensureStarted();
    }
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
      if (live && i < real.length) {
        target = real[i];
      } else if (widget.isPlaying) {
        target = _synth(i, _t);
      } else {
        target = 0.04 + 0.02 * math.sin(_t * 2 + i);
      }
      final prev = _vals[i];
      _vals[i] = target > prev
          ? prev + (target - prev) * 0.5
          : prev + (target - prev) * 0.12;
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
    final barW = gap * 0.6;
    final radius = Radius.circular(barW / 2);
    final midY = size.height / 2;

    // Неоновое «свечение пола» под полосами — пульсирует от громкости.
    var avg = 0.0;
    for (final v in vals) {
      avg += v;
    }
    avg /= n;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 1.15),
          radius: 0.95,
          colors: [
            accent.withValues(alpha: (0.26 + 0.34 * avg).clamp(0.0, 0.7)),
            accent.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );

    final path = Path();

    for (var i = 0; i < n; i++) {
      final v = vals[i].clamp(0.0, 1.0);
      final h = (0.06 + 0.94 * v) * (size.height * 0.94);
      final cx = gap * i + gap / 2;
      path.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, midY), width: barW, height: h),
          radius,
        ),
      );
    }

    // Свечение — один раз на всю фигуру (дёшево для GPU).
    canvas.drawPath(
      path,
      Paint()
        ..color = accent.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    // Тело: акцент сверху → белый к центру.
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent, Colors.white, accent],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Offset.zero & size),
    );

    // Затухающие пики.
    final peakPaint = Paint()..color = Colors.white.withValues(alpha: 0.75);
    for (var i = 0; i < n; i++) {
      final p = peaks[i].clamp(0.0, 1.0);
      final hv = (0.06 + 0.94 * p) * (size.height * 0.94);
      final cx = gap * i + gap / 2;
      canvas.drawCircle(Offset(cx, midY - hv / 2), barW * 0.34, peakPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EqPainter old) => true;
}
