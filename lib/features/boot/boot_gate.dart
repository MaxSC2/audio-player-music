import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';

/// Показывает брендированный splash, пока main() прогревает настройки,
/// провайдер и медиа-сервис. После завершения плавно открывает HomeScreen.
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _ready
          ? widget.child
          : const _BootSplash(key: ValueKey('boot-splash')),
    );
  }
}

class _BootSplash extends StatefulWidget {
  const _BootSplash({super.key});

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
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C16),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 1.05,
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.18),
                    AppTheme.accentCyan.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = _controller.value;
                  final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _logo(pulse),
                      const SizedBox(height: 28),
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            AppTheme.primaryGradient.createShader(bounds),
                        child: const Text(
                          'NEONWAVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'ТВОЯ МУЗЫКА · ТВОЙ РИТМ',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.4,
                        ),
                      ),
                      const SizedBox(height: 36),
                      _bars(t),
                      const SizedBox(height: 20),
                      const Text(
                        'Запускаем плеер…',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logo(double pulse) {
    return Transform.scale(
      scale: 0.97 + pulse * 0.03,
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: AppTheme.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.32 + pulse * 0.16),
              blurRadius: 42 + pulse * 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.graphic_eq_rounded,
          color: Colors.white,
          size: 62,
        ),
      ),
    );
  }

  Widget _bars(double t) {
    return SizedBox(
      height: 30,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final wave = 0.5 + 0.5 * math.sin(t * math.pi * 2 + i * 0.85);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              width: 5,
              height: 8 + wave * 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [AppTheme.accent, AppTheme.accentCyan],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
