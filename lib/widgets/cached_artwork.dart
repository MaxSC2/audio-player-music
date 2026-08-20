import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import '../ui/theme.dart';

class ArtworkCache {
  static final Map<int, Uint8List?> _cache = {};
  static final Map<int, Future<Uint8List?>> _pending = {};
  static final OnAudioQuery _query = OnAudioQuery();

  static Future<Uint8List?> load(int trackId, {int size = 400}) {
    if (_cache.containsKey(trackId)) {
      return Future.value(_cache[trackId]);
    }
    final pending = _pending[trackId];
    if (pending != null) return pending;

    final future = _query.queryArtwork(
      trackId,
      ArtworkType.AUDIO,
      format: ArtworkFormat.PNG,
      size: size,
    );
    _pending[trackId] = future;
    future.then((bytes) {
      _cache[trackId] = bytes;
      _pending.remove(trackId);
    });
    return future;
  }
}

class CachedArtwork extends StatefulWidget {
  final int trackId;
  final double width;
  final double height;
  final double radius;
  final Widget? fallback;

  const CachedArtwork({
    super.key,
    required this.trackId,
    required this.width,
    required this.height,
    this.radius = 12,
    this.fallback,
  });

  @override
  State<CachedArtwork> createState() => _CachedArtworkState();
}

class _CachedArtworkState extends State<CachedArtwork> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CachedArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackId != widget.trackId) {
      _bytes = null;
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final bytes = await ArtworkCache.load(widget.trackId);
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: _bytes != null
              ? Image.memory(
                  _bytes!,
                  width: widget.width,
                  height: widget.height,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                )
              : (widget.fallback ?? _buildFallback()),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    final hash = widget.trackId;
    final palette = <Color>[
      AppTheme.accent,
      AppTheme.accentCyan,
      AppTheme.accentPink,
      AppTheme.accentGreen,
      AppTheme.accentAmber,
      AppTheme.accentLight,
    ];
    final c1 = palette[hash.abs() % palette.length];
    final c2 = palette[(hash.abs() ~/ 7) % palette.length];
    final iconSize =
        (widget.width < widget.height ? widget.width : widget.height) * 0.38;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1, c2],
        ),
      ),
      child: CustomPaint(
        painter: _CoverPatternPainter(hash: hash),
        child: Center(
          child: Icon(
            Icons.music_note_rounded,
            color: Colors.white,
            size: iconSize.clamp(18.0, 64.0),
          ),
        ),
      ),
    );
  }
}

class _CoverPatternPainter extends CustomPainter {
  final int hash;

  _CoverPatternPainter({required this.hash});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.12);
    final rng = hash.abs();
    final cx = size.width * (0.2 + (rng % 60) / 100);
    final cy = size.height * (0.15 + ((rng ~/ 13) % 70) / 100);
    final r0 = size.shortestSide * 0.55;
    canvas.drawCircle(Offset(cx, cy), r0, paint);
    paint.color = Colors.white.withOpacity(0.08);
    canvas.drawCircle(
      Offset(size.width - cx * 0.6, size.height - cy * 0.7),
      r0 * 0.7,
      paint,
    );
    paint.color = Colors.black.withOpacity(0.07);
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.3),
      r0 * 0.45,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CoverPatternPainter oldDelegate) =>
      oldDelegate.hash != hash;
}