import 'dart:math' as math;

import 'package:flutter/material.dart';

class CoverFlowCarousel extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final int initialIndex;
  final double viewportFraction;
  final double cardWidth;
  final double cardHeight;
  final PageController? controller;
  final ValueChanged<int>? onPageChanged;

  const CoverFlowCarousel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.initialIndex = 0,
    this.viewportFraction = 0.72,
    this.cardWidth = 240,
    this.cardHeight = 310,
    this.controller,
    this.onPageChanged,
  });

  @override
  State<CoverFlowCarousel> createState() => _CoverFlowCarouselState();
}

class _CoverFlowCarouselState extends State<CoverFlowCarousel> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        PageController(
          viewportFraction: widget.viewportFraction,
          initialPage: widget.initialIndex,
        );
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final double center;
        if (_controller.hasClients) {
          center = _controller.page ?? widget.initialIndex.toDouble();
        } else {
          center = widget.initialIndex.toDouble();
        }

        return PageView.builder(
          controller: _controller,
          itemCount: widget.itemCount,
          onPageChanged: widget.onPageChanged,
          itemBuilder: (context, index) {
            final delta = (center - index).clamp(-1.15, 1.15).toDouble();
            final angle = delta * 0.92;
            final scale = 1.0 - delta.abs() * 0.10;
            final rise = -delta.abs() * 16;

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0016)
                ..translate(0.0, rise, -delta.abs() * 70)
                ..rotateY(angle),
              child: Transform.scale(
                scale: scale,
                child: Center(
                  child: SizedBox(
                    width: widget.cardWidth,
                    height: widget.cardHeight,
                    child: widget.itemBuilder(context, index),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Helper: pixel-perfect 3D rotation for a widget (used by cover flow cards).
Transform rotate3D(Widget child, double angleY) {
  return Transform(
    alignment: Alignment.center,
    transform: Matrix4.identity()
      ..setEntry(3, 2, 0.0016)
      ..rotateY(angleY),
    child: child,
  );
}

/// Clamp helper for double.
double clampDouble(double v, double lo, double hi) =>
    math.min(hi, math.max(lo, v));