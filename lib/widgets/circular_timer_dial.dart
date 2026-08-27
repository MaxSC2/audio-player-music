import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../ui/theme.dart';

class CircularTimerDial extends StatefulWidget {
  final int initialMinutes;
  final ValueChanged<int> onChanged;
  final int minMinutes;
  final int maxMinutes;
  final int step;

  const CircularTimerDial({
    super.key,
    required this.initialMinutes,
    required this.onChanged,
    this.minMinutes = 0,
    this.maxMinutes = 180,
    this.step = 5,
  });

  @override
  State<CircularTimerDial> createState() => _CircularTimerDialState();
}

class _CircularTimerDialState extends State<CircularTimerDial> {
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _minutes = widget.initialMinutes.clamp(widget.minMinutes, widget.maxMinutes);
  }

  void _updateFromPosition(Offset local, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = local.dx - center.dx;
    final dy = local.dy - center.dy;
    var angle = math.atan2(dy, dx) * 180 / math.pi + 90;
    if (angle < 0) angle += 360;
    final raw = (angle / 360 * widget.maxMinutes).round();
    var stepped = (raw / widget.step).round() * widget.step;
    stepped = stepped.clamp(widget.minMinutes, widget.maxMinutes);
    if (stepped != _minutes) {
      setState(() => _minutes = stepped);
      widget.onChanged(_minutes);
    }
  }

  String get _label {
    if (_minutes == 0) return 'Выключен';
    if (_minutes < 60) return '$_minutes мин';
    final h = _minutes ~/ 60;
    final m = _minutes % 60;
    if (m == 0) return '$h ч';
    return '$h ч $m мин';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final size = math.min(constraints.maxWidth, 260).toDouble();
          return GestureDetector(
            onPanStart: (d) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              // Use global to local conversion via RenderBox
              final local = box.globalToLocal(d.globalPosition);
              // Need size of the dial itself, not the LayoutBuilder constraints
              // Approximate: we use the dial size
              _updateFromPosition(local, Size(size, size));
            },
            onPanUpdate: (d) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final local = box.globalToLocal(d.globalPosition);
              _updateFromPosition(local, Size(size, size));
            },
            child: SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: _DialPainter(
                  minutes: _minutes,
                  maxMinutes: widget.maxMinutes,
                  step: widget.step,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.nightlight_round, color: AppTheme.accentLight, size: 28),
                      const SizedBox(height: 6),
                      Text(
                        _label,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _minutes == 0 ? 'таймер выключен' : 'до паузы',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [0, 5, 15, 30, 45, 60, 90, 120, 180].map((m) {
            final selected = m == _minutes;
            return ChoiceChip(
              label: Text(m == 0 ? 'Выкл' : m < 60 ? '$m м' : '${m ~/ 60}ч${m % 60 == 0 ? '' : ' ${m % 60}м'}'),
              selected: selected,
              onSelected: (_) {
                setState(() => _minutes = m);
                widget.onChanged(m);
              },
              selectedColor: AppTheme.accent.withOpacity(0.2),
              backgroundColor: AppTheme.surfaceLight,
              labelStyle: TextStyle(
                color: selected ? AppTheme.accentLight : AppTheme.textSecondary,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(color: selected ? AppTheme.accent : Colors.transparent),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DialPainter extends CustomPainter {
  final int minutes;
  final int maxMinutes;
  final int step;

  _DialPainter({required this.minutes, required this.maxMinutes, required this.step});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 18;
    final stroke = 14.0;

    final bgPaint = Paint()
      ..color = AppTheme.surfaceLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    if (minutes > 0) {
      final sweep = 2 * math.pi * (minutes / maxMinutes);
      final progressPaint = Paint()
        ..shader = SweepGradient(
          colors: [AppTheme.accent, AppTheme.accentCyan, AppTheme.accent],
          startAngle: -math.pi / 2,
          endAngle: -math.pi / 2 + sweep,
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweep,
        false,
        progressPaint,
      );

      // Glow
      final glowPaint = Paint()
        ..color = AppTheme.accent.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweep,
        false,
        glowPaint,
      );

      // Thumb
      final angle = -math.pi / 2 + sweep;
      final thumbX = center.dx + radius * math.cos(angle);
      final thumbY = center.dy + radius * math.sin(angle);
      final thumbPaint = Paint()..color = AppTheme.accentLight;
      canvas.drawCircle(Offset(thumbX, thumbY), 10, thumbPaint);
      canvas.drawCircle(Offset(thumbX, thumbY), 13,
          Paint()..color = AppTheme.accentLight.withOpacity(0.18)..style = PaintingStyle.stroke..strokeWidth = 6);
      canvas.drawCircle(Offset(thumbX, thumbY), 4, Paint()..color = Colors.white);
    }

    // Ticks
    final tickPaint = Paint()
      ..color = AppTheme.textMuted.withOpacity(0.35)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (int m = 0; m <= maxMinutes; m += step) {
      if (m % 30 != 0 && m % 15 != 0) continue;
      final isMajor = m % 30 == 0;
      final angle = -math.pi / 2 + 2 * math.pi * (m / maxMinutes);
      final r1 = radius - (isMajor ? 0 : 2);
      final r2 = radius + (isMajor ? 10 : 6);
      final p1 = Offset(center.dx + r1 * math.cos(angle), center.dy + r1 * math.sin(angle));
      final p2 = Offset(center.dx + r2 * math.cos(angle), center.dy + r2 * math.sin(angle));
      canvas.drawLine(p1, p2, tickPaint..strokeWidth = isMajor ? 2 : 1.2);
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.minutes != minutes || old.maxMinutes != maxMinutes;
}
