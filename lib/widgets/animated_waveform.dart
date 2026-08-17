import 'dart:math';
import 'package:flutter/material.dart';
import '../ui/theme.dart';

class AnimatedWaveform extends StatefulWidget {
  final bool isPlaying;
  final int barCount;
  final double height;
  final double width;
  final Gradient? gradient;

  const AnimatedWaveform({
    super.key,
    required this.isPlaying,
    this.barCount = 5,
    this.height = 24.0,
    this.width = 30.0,
    this.gradient,
  });

  @override
  State<AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<AnimatedWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barWidth = widget.width.isFinite
        ? (widget.width / widget.barCount) - 2
        : 3.5;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.barCount, (index) {
              final phase = (index / widget.barCount) * pi * 2;
              final t = _controller.value * pi * 2;
              final raw = (sin(t + phase) + sin(2 * t + phase * 1.5)) / 2;
              final scale = widget.isPlaying
                  ? (0.2 + (raw.abs() * 0.8)).clamp(0.15, 1.0)
                  : 0.2;

              return Container(
                width: max(2.5, barWidth),
                height: widget.height * scale,
                decoration: BoxDecoration(
                  gradient: widget.gradient ?? AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
