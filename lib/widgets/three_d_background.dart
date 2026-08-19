import 'package:flutter/material.dart';

class ThreeDBackground extends StatelessWidget {
  final Widget? child;

  const ThreeDBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0B0C14), Color(0xFF151228)],
            ),
          ),
        ),
        const Positioned(
          top: -80,
          left: -60,
          child: GlowBlob(size: 260, color: Color(0x334433FF)),
        ),
        const Positioned(
          top: 90,
          right: -70,
          child: GlowBlob(size: 220, color: Color(0x3306B6D4)),
        ),
        const Positioned(
          bottom: 60,
          right: -90,
          child: GlowBlob(size: 320, color: Color(0x33A855F7)),
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