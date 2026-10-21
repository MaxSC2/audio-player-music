import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui_style.dart';
import '../../ui/theme.dart';

/// Брендированный splash, пока main() прогревает настройки, провайдер и
/// медиа-сервис. Внешний вид зависит от выбранного стиля плеера.
class BootGate extends StatefulWidget {
  const BootGate({
    super.key,
    required this.bootFuture,
    required this.child,
  });

  final Future<void> bootFuture;
  final Widget child;

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    widget.bootFuture.whenComplete(() {
      if (!mounted) return;
      setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = context.select<UiStyleController, PlayerUIStyle>(
      (controller) => controller.style,
    );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _ready
          ? widget.child
          : _BootSplash(
              key: ValueKey('boot-${style.name}'),
              style: style,
            ),
    );
  }
}

class _BootSplash extends StatefulWidget {
  const _BootSplash({super.key, required this.style});

  final PlayerUIStyle style;

  @override
  State<_BootSplash> createState() => _BootSplashState();
}

class _BootSplashState extends State<_BootSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _tagline => switch (widget.style) {
    PlayerUIStyle.simple => 'ТВОЯ МУЗЫКА · ТВОЙ РИТМ',
    PlayerUIStyle.coverFlow3D => 'ОБЛОЖКИ В ДВИЖЕНИИ',
    PlayerUIStyle.cinematic => 'КИНО ДЛЯ ТВОИХ УШЕЙ',
    PlayerUIStyle.neon => 'НЕОН · РИТМ · ЭНЕРГИЯ',
  };

  String get _styleName => switch (widget.style) {
    PlayerUIStyle.simple => 'SIMPLE',
    PlayerUIStyle.coverFlow3D => 'COVER FLOW 3D',
    PlayerUIStyle.cinematic => 'CINEMATIC',
    PlayerUIStyle.neon => 'NEON',
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2);
        return Scaffold(
          backgroundColor: const Color(0xFF07080F),
          body: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.25),
                      radius: 1.1,
                      colors: [
                        AppTheme.accent.withValues(alpha: 0.18),
                        AppTheme.accentCyan.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.48, 1],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _SplashBackdropPainter(style: widget.style, t: t),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 22,
                  ),
                  child: Column(
                    children: [
                      const Spacer(),
                      _logo(pulse),
                      const SizedBox(height: 28),
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            AppTheme.primaryGradient.createShader(bounds),
                        child: const Text(
                          'NEONWAVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 5.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        _tagline,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.4,
                        ),
                      ),
                      const SizedBox(height: 34),
                      _wave(pulse),
                      const SizedBox(height: 24),
                      Text(
                        'ЗАПУСК · $_styleName',
                        style: TextStyle(
                          color: AppTheme.accent.withValues(alpha: 0.9),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 142,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            minHeight: 2,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.07,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.accent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Загружаем настройки и библиотеку…',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.38),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'ЛОКАЛЬНАЯ МУЗЫКА · БЕЗ РЕКЛАМЫ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.28),
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _logo(double pulse) {
    final glow = 34 + pulse * 22;
    switch (widget.style) {
      case PlayerUIStyle.simple:
        return _logoBox(
          radius: 30,
          glow: glow,
          child: const Icon(
            Icons.graphic_eq_rounded,
            color: Colors.white,
            size: 58,
          ),
        );
      case PlayerUIStyle.coverFlow3D:
        return SizedBox(
          width: 150,
          height: 118,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: const Offset(-28, 5),
                child: Transform.rotate(
                  angle: -0.17,
                  child: _coverCard(0.55),
                ),
              ),
              Transform.translate(
                offset: const Offset(28, 5),
                child: Transform.rotate(
                  angle: 0.17,
                  child: _coverCard(0.55),
                ),
              ),
              _logoBox(
                radius: 22,
                glow: glow,
                size: 100,
                child: const Icon(
                  Icons.album_rounded,
                  color: Colors.white,
                  size: 54,
                ),
              ),
            ],
          ),
        );
      case PlayerUIStyle.cinematic:
        return Container(
          width: 124,
          height: 124,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.accent.withValues(alpha: 0.38),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.22),
                blurRadius: glow + 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF59E0B), Color(0xFF7C2D12)],
              ),
            ),
            child: const Icon(
              Icons.movie_filter_rounded,
              color: Colors.white,
              size: 52,
            ),
          ),
        );
      case PlayerUIStyle.neon:
        return Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.accentCyan.withValues(alpha: 0.75),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.42),
                blurRadius: glow + 18,
                spreadRadius: 3,
              ),
              BoxShadow(
                color: AppTheme.accentCyan.withValues(alpha: 0.26),
                blurRadius: glow,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _NeonLogoPainter(pulse: pulse),
                    ),
                  ),
                  const Center(
                    child: Icon(
                      Icons.bolt_rounded,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }

  Widget _logoBox({
    required double radius,
    required double glow,
    required Widget child,
    double size = 110,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: AppTheme.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.34),
            blurRadius: glow,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(child: child),
    );
  }

  Widget _coverCard(double opacity) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accentPink.withValues(alpha: opacity),
            AppTheme.accentCyan.withValues(alpha: opacity),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: Colors.white.withValues(alpha: 0.55),
        size: 34,
      ),
    );
  }

  Widget _wave(double pulse) {
    return SizedBox(
      height: 34,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(9, (i) {
          final t = _controller.value;
          final wave = 0.5 + 0.5 * math.sin(t * math.pi * 2 + i * 0.72);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              width: 4,
              height: 7 + wave * 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [AppTheme.accent, AppTheme.accentCyan],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.35 + pulse * 0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NeonLogoPainter extends CustomPainter {
  const _NeonLogoPainter({required this.pulse});

  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final inset = i * 18.0;
      canvas.drawCircle(
        Offset(size.width * 0.5, size.height * 0.5),
        size.width * 0.5 - inset + pulse * 3,
        paint,
      );
    }
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;
    for (double y = 12; y < size.height; y += 12) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant _NeonLogoPainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}

class _SplashBackdropPainter extends CustomPainter {
  const _SplashBackdropPainter({required this.style, required this.t});

  final PlayerUIStyle style;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    switch (style) {
      case PlayerUIStyle.simple:
        _simple(canvas, size);
      case PlayerUIStyle.coverFlow3D:
        _coverFlow(canvas, size);
      case PlayerUIStyle.cinematic:
        _cinematic(canvas, size);
      case PlayerUIStyle.neon:
        _neon(canvas, size);
    }
  }

  void _simple(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.33);
    for (var i = 0; i < 4; i++) {
      final radius = 92.0 + i * 52 + math.sin(t * math.pi * 2 + i) * 6;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = AppTheme.accent.withValues(alpha: 0.09 - i * 0.015)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    for (var i = 0; i < 18; i++) {
      final dx = (math.sin(i * 12.9898) * 43758.5453).abs() % 1;
      final dy = (math.sin(i * 78.233) * 12543.123).abs() % 1;
      final twinkle = 0.12 + 0.18 * (0.5 + 0.5 * math.sin(t * 6 + i));
      canvas.drawCircle(
        Offset(dx * size.width, dy * size.height),
        1.1,
        Paint()..color = Colors.white.withValues(alpha: twinkle),
      );
    }
  }

  void _coverFlow(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.34);
    for (var i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-0.42 + i * 0.42);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: 250 + i * 54,
        height: 168 + i * 26,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(28)),
        Paint()
          ..color = (i == 1 ? AppTheme.accentPink : AppTheme.accentCyan)
              .withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      canvas.restore();
    }
    final beam = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width * 0.02, size.height)
      ..lineTo(size.width * 0.98, size.height)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.accent.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  void _cinematic(Canvas canvas, Size size) {
    const bar = 58.0;
    final black = Paint()..color = Colors.black.withValues(alpha: 0.78);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, bar), black);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - bar, size.width, bar),
      black,
    );
    final edge = Paint()
      ..color = AppTheme.accent.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(0, bar), Offset(size.width, bar), edge);
    canvas.drawLine(
      Offset(0, size.height - bar),
      Offset(size.width, size.height - bar),
      edge,
    );

    final beam = Path()
      ..moveTo(size.width * 0.5, bar)
      ..lineTo(size.width * 0.16, size.height - bar)
      ..lineTo(size.width * 0.84, size.height - bar)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.accentAmber.withValues(alpha: 0.13),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, bar, size.width, size.height)),
    );

    final hole = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (double x = 20; x < size.width; x += 34) {
      canvas.drawCircle(Offset(x, bar * 0.5), 4, hole);
      canvas.drawCircle(Offset(x, size.height - bar * 0.5), 4, hole);
    }
  }

  void _neon(Canvas canvas, Size size) {
    final horizon = size.height * 0.64;
    final grid = Paint()
      ..color = AppTheme.accentCyan.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    for (var i = -10; i <= 10; i++) {
      final bottomX = size.width / 2 + i * size.width * 0.12;
      canvas.drawLine(
        Offset(size.width / 2, horizon),
        Offset(bottomX, size.height),
        grid,
      );
    }
    for (var i = 1; i <= 10; i++) {
      final k = i / 10;
      final y = horizon + (size.height - horizon) * k * k;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final line = Path();
    for (double x = 0; x <= size.width; x += 6) {
      final y =
          horizon +
          math.sin(x / 42 + t * math.pi * 2) * 16 +
          math.sin(x / 17 - t * math.pi * 2) * 5;
      if (x == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = AppTheme.accent.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = AppTheme.accentCyan.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );

    final scan = Paint()..color = Colors.white.withValues(alpha: 0.025);
    for (double y = 0; y < size.height; y += 5) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), scan);
    }
  }

  @override
  bool shouldRepaint(covariant _SplashBackdropPainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.t != t;
}
