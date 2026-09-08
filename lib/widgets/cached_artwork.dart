import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import '../ui/theme.dart';

class ArtworkCache {
  static const int _maxEntries = 200;
  static final LinkedHashMap<int, Uint8List?> _cache = LinkedHashMap();
  static final Map<int, Future<Uint8List?>> _pending = {};
  static final OnAudioQuery _query = OnAudioQuery();

  /// Есть ли запись в кеше (включая закэшированное отсутствие арта).
  static bool has(int trackId) => _cache.containsKey(trackId);

  /// Синхронное чтение с LRU-поднятием. null = нет записи ИЛИ арта нет
  /// (различать через has()).
  static Uint8List? getSync(int trackId) {
    if (!_cache.containsKey(trackId)) return null;
    final bytes = _cache.remove(trackId);
    _cache[trackId] = bytes;
    return bytes;
  }

  static Future<Uint8List?> load(int trackId, {int size = 400}) {
    if (_cache.containsKey(trackId)) {
      // LRU: поднимаем запрошенный ключ в конец.
      final bytes = _cache.remove(trackId);
      _cache[trackId] = bytes;
      return Future.value(bytes);
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
      while (_cache.length > _maxEntries) {
        _cache.remove(_cache.keys.first);
      }
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

  @override
  void initState() {
    super.initState();
    // Мгновенный хит из кеша — карточка никогда не стартует с плейсхолдера,
    // если арт уже грузили (ключевое для карусели при быстром скролле).
    _bytes = ArtworkCache.getSync(widget.trackId);
    if (_bytes == null && !ArtworkCache.has(widget.trackId)) {
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant CachedArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackId != widget.trackId) {
      if (ArtworkCache.has(widget.trackId)) {
        // Хит — мгновенная подмена без вспышки (setState не нужен,
        // build и так идёт следом за didUpdateWidget).
        _bytes = ArtworkCache.getSync(widget.trackId);
      } else {
        // Stale-while-revalidate: старый арт висит до загрузки нового,
        // чтобы при прокрутке не мигал встроенный плейсхолдер.
        _load();
      }
    }
  }

  Future<void> _load() async {
    final bytes = await ArtworkCache.load(widget.trackId);
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
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
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: Colors.white.a * (0.12));
    final rng = hash.abs();
    final cx = size.width * (0.2 + (rng % 60) / 100);
    final cy = size.height * (0.15 + ((rng ~/ 13) % 70) / 100);
    final r0 = size.shortestSide * 0.55;
    canvas.drawCircle(Offset(cx, cy), r0, paint);
    paint.color = Colors.white.withValues(alpha: Colors.white.a * (0.08));
    canvas.drawCircle(
      Offset(size.width - cx * 0.6, size.height - cy * 0.7),
      r0 * 0.7,
      paint,
    );
    paint.color = Colors.black.withValues(alpha: Colors.black.a * (0.07));
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
