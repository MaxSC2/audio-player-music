import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
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
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.pinkPurpleGradient,
      ),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}