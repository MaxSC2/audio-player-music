import 'package:flutter/material.dart';
import '../ui/theme.dart';

class ThreeDBackground extends StatelessWidget {
  final Widget? child;

  const ThreeDBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final base = AppTheme.background;
    final light = AppTheme.lightMode;
    final bottomColor = Color.lerp(
      base,
      light ? const Color(0xFFDCE4F2) : Colors.black,
      0.45,
    )!;
    final blobOpacity = light ? 0.14 : 0.20;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [base, bottomColor],
            ),
          ),
        ),
        Positioned(
          top: -80,
          left: -60,
          child: GlowBlob(
              size: 260, color: AppTheme.accent.withOpacity(blobOpacity)),
        ),
        Positioned(
          top: 90,
          right: -70,
          child: GlowBlob(
              size: 220,
              color: AppTheme.accentCyan.withOpacity(blobOpacity)),
        ),
        Positioned(
          bottom: 60,
          right: -90,
          child: GlowBlob(
              size: 320,
              color: AppTheme.accentPink.withOpacity(blobOpacity)),
        ),
        if (child != null) child!,
      ],
    );
  }
}

class GlowBlob extends StatelessWidget {
  final double size;
  final Color color;

  const GlowBlob({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0)],
          ),
        ),
      ),
    );
  }
}
