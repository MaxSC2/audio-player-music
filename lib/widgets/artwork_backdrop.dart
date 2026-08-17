import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'cached_artwork.dart';

class AnimatedArtworkBackdrop extends StatefulWidget {
  final int trackId;

  const AnimatedArtworkBackdrop({super.key, required this.trackId});

  @override
  State<AnimatedArtworkBackdrop> createState() =>
      _AnimatedArtworkBackdropState();
}

class _AnimatedArtworkBackdropState extends State<AnimatedArtworkBackdrop>
    with SingleTickerProviderStateMixin {
  Uint8List? _bytes;
  int _loadedId = -1;

  late final AnimationController _kenBurns = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _load(widget.trackId);
  }

  @override
  void didUpdateWidget(covariant AnimatedArtworkBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackId != widget.trackId) _load(widget.trackId);
  }

  @override
  void dispose() {
    _kenBurns.dispose();
    super.dispose();
  }

  Future<void> _load(int id) async {
    if (id == _loadedId) return;
    _loadedId = id;
    final bytes = await ArtworkCache.load(id, size: 800);
    if (!mounted || id != widget.trackId) return;
    setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 900),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: AnimatedBuilder(
        key: ValueKey(_loadedId),
        animation: _kenBurns,
        builder: (context, child) {
          final t = _kenBurns.value;
          return Transform.scale(scale: 1.05 + 0.12 * t, child: child);
        },
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 48, sigmaY: 48),
          child: Image.memory(
            _bytes!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            filterQuality: FilterQuality.low,
          ),
        ),
      ),
    );
  }
}