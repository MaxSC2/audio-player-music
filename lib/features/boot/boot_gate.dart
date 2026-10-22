import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui_style.dart';

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
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      // AnimatedSwitcher по умолчанию даёт детям loose-констрейнты: Stack
      // сжимался до ширины текста, и splash оказывался в левой половине.
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
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
  late final Animation<double> _breath;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _breath = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _SplashTheme.of(widget.style);
    return SizedBox.expand(
      child: Scaffold(
        backgroundColor: const Color(0xFF07080F),
        body: Stack(
          fit: StackFit.expand,
          children: [
            _SplashBackdrop(theme: theme),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _breath,
                          builder: (context, _) {
                            final pulse = _breath.value;
                            return Transform.scale(
                              scale: 0.985 + pulse * 0.03,
                              child: _LogoMark(theme: theme, pulse: pulse),
                            );
                          },
                        ),
                        const SizedBox(height: 26),
                        const Text(
                          'NEONWAVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 6,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          theme.tagline,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.50),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.1,
                          ),
                        ),
                        const SizedBox(height: 34),
                        SizedBox(
                          width: 128,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              minHeight: 2,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.08,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.accent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ЗАГРУЗКА · ${theme.label}',
                          style: TextStyle(
                            color: theme.accent.withValues(alpha: 0.85),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Настройки и библиотека',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.34),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop({required this.theme});

  final _SplashTheme theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.18),
          radius: 1.05,
          colors: [
            theme.accent.withValues(alpha: 0.15),
            theme.secondary.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          stops: const [0, 0.46, 1],
        ),
      ),
      child: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xCC07080F)],
          ),
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.theme, required this.pulse});

  final _SplashTheme theme;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final glow = 24 + pulse * 18;
    final radius = theme.circle ? 54.0 : 26.0;
    return SizedBox(
      width: 160,
      height: 136,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (theme.stacked) ...[
            Transform.translate(
              offset: const Offset(-27, 2),
              child: Transform.rotate(
                angle: -0.16,
                child: _backCard(theme.accent),
              ),
            ),
            Transform.translate(
              offset: const Offset(27, 2),
              child: Transform.rotate(
                angle: 0.16,
                child: _backCard(theme.secondary),
              ),
            ),
          ],
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: theme.circle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: theme.circle ? null : BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.accent, theme.secondary],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: theme.neon ? 0.28 : 0.16),
                width: theme.neon ? 1.3 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.accent.withValues(alpha: 0.32),
                  blurRadius: glow,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: theme.secondary.withValues(alpha: 0.16),
                  blurRadius: glow * 0.7,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(theme.icon, color: Colors.white, size: 46),
          ),
        ],
      ),
    );
  }

  Widget _backCard(Color color) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.24),
            color.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
    );
  }
}

class _SplashTheme {
  const _SplashTheme({
    required this.accent,
    required this.secondary,
    required this.icon,
    required this.tagline,
    required this.label,
    this.circle = false,
    this.stacked = false,
    this.neon = false,
  });

  final Color accent;
  final Color secondary;
  final IconData icon;
  final String tagline;
  final String label;
  final bool circle;
  final bool stacked;
  final bool neon;

  static _SplashTheme of(PlayerUIStyle style) {
    return switch (style) {
      PlayerUIStyle.simple => const _SplashTheme(
        accent: Color(0xFF8B5CF6),
        secondary: Color(0xFF22D3EE),
        icon: Icons.graphic_eq_rounded,
        tagline: 'ТВОЯ МУЗЫКА · ТВОЙ РИТМ',
        label: 'SIMPLE',
        neon: true,
      ),
      PlayerUIStyle.coverFlow3D => const _SplashTheme(
        accent: Color(0xFFEC4899),
        secondary: Color(0xFF06B6D4),
        icon: Icons.album_rounded,
        tagline: 'ОБЛОЖКИ В ДВИЖЕНИИ',
        label: 'COVER FLOW 3D',
        stacked: true,
      ),
      PlayerUIStyle.cinematic => const _SplashTheme(
        accent: Color(0xFFF59E0B),
        secondary: Color(0xFFB45309),
        icon: Icons.movie_filter_rounded,
        tagline: 'КИНО ДЛЯ ТВОИХ УШЕЙ',
        label: 'CINEMATIC',
        circle: true,
      ),
      PlayerUIStyle.neon => const _SplashTheme(
        accent: Color(0xFF06B6D4),
        secondary: Color(0xFFA855F7),
        icon: Icons.bolt_rounded,
        tagline: 'НЕОН · РИТМ · ЭНЕРГИЯ',
        label: 'NEON',
        neon: true,
      ),
      PlayerUIStyle.cardWave => const _SplashTheme(
        accent: Color(0xFFD6A64D),
        secondary: Color(0xFF735018),
        icon: Icons.album_rounded,
        tagline: 'ТВОЯ МУЗЫКА · ТВОЯ КОЛОДА',
        label: 'CARDWAVE',
        stacked: true,
      ),
    };
  }
}
