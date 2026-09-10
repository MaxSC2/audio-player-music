import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/ui_style.dart';
import '../../../models/audio_track.dart';
import '../../../providers/player_provider.dart';
import '../../../widgets/artwork_palette.dart';
import '../../../widgets/cached_artwork.dart';
import '../../../widgets/marquee_text.dart';
import '../../../widgets/queue_sheet.dart';
import '../../../widgets/track_actions_sheet.dart';
import '../../../core/debug_log.dart';

/// Текущий акцент cinematic: тема (Auto/фикс) + кеш палитры обложки.
Color cinematicAccent(BuildContext context, int? trackId) {
  final ui = context.watch<UiStyleController>();
  final art = (trackId == null)
      ? ArtworkPalette.fallback
      : (ArtworkPalette.cached(trackId) ?? ArtworkPalette.fallback);
  return ui.resolveCinematic(art)[0];
}

/// Фиксированная тёмная система Cinematic (п.14): near black, белый текст,
/// акцент — только из обложки. Не зависит от AppTheme/palette.
class CinematicTheme {
  static const Color bg = Color(0xFF050507);
  static const Color surface = Color(0x14FFFFFF);
  static const Color border = Color(0x24FFFFFF);
  static const Color text = Colors.white;
  static const Color textSoft = Color(0xB3FFFFFF);
  static const Color textDim = Color(0x80FFFFFF);
  static const double radiusCard = 20.0;
  static const double radiusControl = 34.0;
}

/// Тело кинематографичного плеера: ambient + карусель + визуализатор +
/// информация + прогресс + компакт-контролы. Используется и home, и full.
class CinematicPlayerBody extends StatelessWidget {
  final bool showFeatures;
  final Widget? features;

  /// Neon-режим: 5 кнопок, неоновая кромка центра, кольца сцены.
  final bool fullControls;
  final bool edgeGlow;
  final bool stageRings;

  const CinematicPlayerBody({
    super.key,
    this.showFeatures = false,
    this.features,
    this.fullControls = false,
    this.edgeGlow = false,
    this.stageRings = false,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    DebugLog.rebuild('CinematicBody');
    final track = player.currentTrack;
    final playlist = player.playlist;

    if (track == null || playlist.isEmpty) {
      return _EmptyState(
        hasLibrary: player.visibleTracks.isNotEmpty,
      );
    }

    final accent = cinematicAccent(context, track.id);
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: _CinematicCarousel(
            key: ValueKey('carousel-${playlist.length}'),
            playlist: playlist,
            currentIndex: player.currentIndex,
            accent: accent,
            edgeGlow: edgeGlow,
            stageRings: stageRings,
          ),
        ),
        CinematicVisualizer(
          isPlaying: player.playingVisuals,
          trackId: track.id,
        ),
        _TrackInfo(track: track),
        const _ProgressRow(),
        _ControlsRow(full: fullControls),
        if (showFeatures && features != null) features!,
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasLibrary;

  const _EmptyState({required this.hasLibrary});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: CinematicTheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: CinematicTheme.border),
            ),
            child: const Icon(
              Icons.music_note_rounded,
              color: CinematicTheme.textDim,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Очередь пуста',
            style: TextStyle(
              color: CinematicTheme.text,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasLibrary
                ? 'Выберите трек из библиотеки ниже'
                : 'Добавьте музыку на устройство',
            style: const TextStyle(
              color: CinematicTheme.textDim,
              fontSize: 13,
            ),
          ),
          if (hasLibrary) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () {
                final p = context.read<PlayerProvider>();
                if (p.visibleTracks.isNotEmpty) {
                  p.playFromPlaylist(p.visibleTracks, 0);
                }
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('Слушать всё'),
              style: OutlinedButton.styleFrom(
                foregroundColor: CinematicTheme.text,
                side: const BorderSide(color: CinematicTheme.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ambient-фон: слабое свечение цветами текущей обложки (п.6).
/// Плавная интерполяция при смене трека, медленный дрейф.
class CinematicAmbient extends StatefulWidget {
  final int? trackId;
  final Widget child;

  const CinematicAmbient({
    super.key,
    required this.trackId,
    required this.child,
  });

  @override
  State<CinematicAmbient> createState() => _CinematicAmbientState();
}

class _CinematicAmbientState extends State<CinematicAmbient>
    with SingleTickerProviderStateMixin {
  List<Color> _from = ArtworkPalette.fallback;
  List<Color> _to = ArtworkPalette.fallback;
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _resolve(widget.trackId);
  }

  @override
  void didUpdateWidget(covariant CinematicAmbient oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackId != widget.trackId) {
      _from = _to;
      _resolve(widget.trackId);
    }
  }

  Future<void> _resolve(int? trackId) async {
    final colors = trackId == null
        ? ArtworkPalette.fallback
        : await ArtworkPalette.forTrack(trackId);
    if (!mounted) return;
    setState(() => _to = colors);
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Тема (Auto/фикс) применяется поверх цветов обложки.
    final ui = context.watch<UiStyleController>();
    final from = ui.resolveCinematic(_from);
    final to = ui.resolveCinematic(_to);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      key: ValueKey('${widget.trackId}-${ui.cinematicTheme.name}'),
      builder: (context, t, _) {
        final c1 = Color.lerp(from[0], to[0], t)!;
        final c2 = Color.lerp(
          from.length > 1 ? from[1] : from[0],
          to.length > 1 ? to[1] : to[0],
          t,
        )!;
        // Важно: child пробрасывается как есть, иначе дрейф перестраивал
        // бы весь экран 60 раз в секунду (это и были лаги).
        return _AmbientGlow(
          c1: c1,
          c2: c2,
          drift: _drift,
          child: widget.child,
        );
      },
    );
  }
}

/// Только пятна света перерисовываются каждый тик дрейфа,
/// контент (child) собирается один раз и переиспользуется.
class _AmbientGlow extends StatelessWidget {
  final Color c1;
  final Color c2;
  final Animation<double> drift;
  final Widget child;

  const _AmbientGlow({
    required this.c1,
    required this.c2,
    required this.drift,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: drift,
      child: child,
      builder: (context, glowChild) {
        final dx = math.sin(drift.value * 2 * math.pi) * 26;
        final dy = math.cos(drift.value * 2 * math.pi) * 18;
        return Container(
          color: CinematicTheme.bg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Верхнее пятно — основной цвет обложки, очень слабо.
              Positioned(
                top: -120 + dy,
                left: -80 + dx,
                right: -80 - dx,
                height: 420,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.75,
                        colors: [
                          c1.withValues(alpha: c1.a * 0.16),
                          c1.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Нижнее пятно — вторичный цвет.
              Positioned(
                bottom: -140 - dy,
                left: -60 - dx,
                right: -60 + dx,
                height: 380,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.75,
                        colors: [
                          c2.withValues(alpha: c2.a * 0.12),
                          c2.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              glowChild!,
            ],
          ),
        );
      },
    );
  }
}

/// 3D-карусель очереди (п.4, п.12): центр — крупный и чёткий,
/// соседи уходят в перспективу с затемнением. Свайп = next/previous.
class _CinematicCarousel extends StatefulWidget {
  final List<AudioTrack> playlist;
  final int currentIndex;
  final Color accent;
  final bool edgeGlow;
  final bool stageRings;

  const _CinematicCarousel({
    super.key,
    required this.playlist,
    required this.currentIndex,
    required this.accent,
    this.edgeGlow = false,
    this.stageRings = false,
  });

  @override
  State<_CinematicCarousel> createState() => _CinematicCarouselState();
}

class _CinematicCarouselState extends State<_CinematicCarousel> {
  PageController? _controller;
  int _lastSyncedKey = -1;
  bool _programmatic = false;

  int get _target =>
      widget.currentIndex.clamp(0, widget.playlist.length - 1).toInt();

  void _onPageChanged(int index) {
    if (_programmatic) {
      _programmatic = false;
      return;
    }
    if (index < 0 || index >= widget.playlist.length) return;
    // Фиксируем ключ СРАЗУ, иначе rebuild от playAt дернет animateToPage
    // навстречу drag'у — отсюда был глитч прокрутки.
    _lastSyncedKey = index;
    final player = context.read<PlayerProvider>();
    // Предзагрузка соседних обложек — меньше вспышек при свайпе.
    for (final n in [
      index - 3,
      index - 2,
      index - 1,
      index + 1,
      index + 2,
      index + 3,
    ]) {
      if (n >= 0 && n < widget.playlist.length) {
        ArtworkCache.load(widget.playlist[n].id);
      }
    }
    player.playAt(index);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = _target;
    _controller ??= PageController(
      viewportFraction: 0.62,
      initialPage: target,
    );
    if (_lastSyncedKey != target) {
      _lastSyncedKey = target;
      _programmatic = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _controller == null) return;
        final c = _controller!;
        if (c.hasClients && (c.page ?? 0).round() != target) {
          c.animateToPage(
            target,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
          );
        } else {
          _programmatic = false;
        }
      });
    }

    final accent = cinematicAccent(
      context,
      widget.playlist[target].id,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = math.min(constraints.maxWidth * 0.66, 320.0);
        final cardH = math.min(constraints.maxHeight * 0.88, cardW * 1.18);
        return Stack(
          alignment: Alignment.center,
          children: [
            // Локальное свечение под центральной обложкой.
            IgnorePointer(
              child: Container(
                width: cardW * 1.25,
                height: cardH * 0.9,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.7,
                    colors: [
                      accent.withValues(alpha: accent.a * 0.20),
                      accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Кольца сцены под каруселью (neon-режим).
            if (widget.stageRings)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 90,
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _StageRingsPainter(accent: accent),
                  ),
                ),
              ),
            ListenableBuilder(
              listenable: _controller!,
              builder: (context, _) {
                final double center;
                if (_controller!.hasClients) {
                  center = _controller!.page ?? target.toDouble();
                } else {
                  center = target.toDouble();
                }
                return PageView.builder(
                  controller: _controller,
                  itemCount: widget.playlist.length,
                  onPageChanged: _onPageChanged,
                  physics: const PageScrollPhysics(),
                  itemBuilder: (context, index) {
                    final delta = (center - index)
                        .clamp(-1.2, 1.2)
                        .toDouble();
                    final ad = delta.abs();
                    final angle = delta * 0.55;
                    final scale = 1.0 - ad * 0.17;
                    final dim = (ad * 0.52).clamp(0.0, 0.62);
                    final saturation =
                        (1.0 - ad * 0.45).clamp(0.4, 1.0);
                    // Блюр только самым дальним и слабый: saveLayer дорог.
                    final blur =
                        ad > 0.8 ? math.min(1.5, (ad - 0.8) * 4.0) : 0.0;
                    Widget card = _CinematicCard(
                      track: widget.playlist[index],
                      width: cardW,
                      height: cardH,
                      isCenter: ad < 0.5,
                      dim: dim,
                      delta: delta,
                      edgeColor:
                          widget.edgeGlow && ad < 0.5 ? accent : null,
                    );
                    final noFilters = context
                        .read<PlayerProvider>()
                        .debugNoImageFilters;
                    if (!noFilters && saturation < 0.99) {
                      card = ColorFiltered(
                        colorFilter: ColorFilter.matrix(
                          _saturationMatrix(saturation),
                        ),
                        child: card,
                      );
                    }
                    if (!noFilters && blur > 0.01) {
                      card = ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: blur,
                          sigmaY: blur,
                        ),
                        child: card,
                      );
                    }
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0016)
                        ..translateByDouble(0.0, ad * 10, -ad * 90, 1.0)
                        ..rotateY(angle),
                      child: Transform.scale(
                        scale: scale,
                        // Изолируем фильтры в свой слой: перестроения
                        // родителя не тянут за собой перерастр фильтров.
                        child: Center(
                          child: RepaintBoundary(child: card),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Эллиптические кольца сцены под каруселью (neon-режим).
/// Статичная отрисовка — дёшево, без анимаций.
class _StageRingsPainter extends CustomPainter {
  final Color accent;

  _StageRingsPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    for (var i = 0; i < 3; i++) {
      final t = i / 2; // 0 ближнее → 1 дальнее
      final w = size.width * (0.86 - t * 0.22);
      final h = 34.0 - t * 9;
      final y = size.height - 12 - t * 22;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 - t * 0.5
        ..color = accent.withValues(
          alpha: accent.a * (0.30 - t * 0.10),
        );
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, y), width: w, height: h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StageRingsPainter old) =>
      old.accent != accent;
}

/// Матрица насыщенности 0..1.
List<double> _saturationMatrix(double s) {
  const lumR = 0.2126;
  const lumG = 0.7152;
  const lumB = 0.0722;
  final ir = (1 - s) * lumR;
  final ig = (1 - s) * lumG;
  final ib = (1 - s) * lumB;
  return [
    ir + s, ig, ib, 0, 0,
    ir, ig + s, ib, 0, 0,
    ir, ig, ib + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// Центральная карточка: чёткая, приподнята, мягкая тень + лёгкий reflection.
class _CinematicCard extends StatefulWidget {
  final AudioTrack track;
  final double width;
  final double height;
  final bool isCenter;
  final double dim;

  /// Смещение от центра (-1.2..1.2) для parallax.
  final double delta;

  /// Неоновая кромка центральной карточки (neon-режим).
  final Color? edgeColor;

  const _CinematicCard({
    required this.track,
    required this.width,
    required this.height,
    required this.isCenter,
    required this.dim,
    this.delta = 0.0,
    this.edgeColor,
  });

  @override
  State<_CinematicCard> createState() => _CinematicCardState();
}

class _CinematicCardState extends State<_CinematicCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tap;

  @override
  void initState() {
    super.initState();
    _tap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      lowerBound: 0.965,
      upperBound: 1.0,
    )..value = 1.0;
  }

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  void _openQueue() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101014),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const QueueSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _tap.reverse(),
      onTapUp: (_) => _tap.forward(),
      onTapCancel: () => _tap.forward(),
      onLongPress: _openQueue,
      child: ScaleTransition(
        scale: _tap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(CinematicTheme.radiusCard),
                border: widget.edgeColor == null
                    ? null
                    : Border.all(
                        color: widget.edgeColor!.withValues(
                          alpha: widget.edgeColor!.a * 0.85,
                        ),
                        width: 1.5,
                      ),
                boxShadow: [
                  if (widget.edgeColor != null)
                    BoxShadow(
                      color: widget.edgeColor!.withValues(
                        alpha: widget.edgeColor!.a * 0.45,
                      ),
                      blurRadius: 30,
                      spreadRadius: 1,
                    ),
                  BoxShadow(
                    color: const Color(0x66000000),
                    blurRadius: widget.isCenter ? 34 : 18,
                    offset: Offset(0, widget.isCenter ? 16 : 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(CinematicTheme.radiusCard),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Лёгкий parallax обложки при свайпе.
                    Transform.translate(
                      offset: Offset(-widget.delta * 14, 0),
                      child: CachedArtwork(
                        trackId: widget.track.id,
                        width: widget.width + 28,
                        height: widget.height,
                        radius: 0,
                      ),
                    ),
                    // Затемнение боковых карточек (яркость/насыщенность ↓).
                    if (widget.dim > 0.01)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(
                            color: Colors.black.withValues(
                              alpha: Colors.black.a * widget.dim,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Лёгкий reflection.
            Container(
              width: widget.width * 0.86,
              height: 22,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: Colors.white.a * 0.07),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Тонкий визуализатор пространства: Bars / Wave / Particles (п.7).
class CinematicVisualizer extends StatefulWidget {
  final bool isPlaying;
  final int trackId;

  const CinematicVisualizer({
    super.key,
    required this.isPlaying,
    required this.trackId,
  });

  @override
  State<CinematicVisualizer> createState() => _CinematicVisualizerState();
}

enum _VizMode { bars, wave, particles, minimal }

class _CinematicVisualizerState extends State<CinematicVisualizer>
    with SingleTickerProviderStateMixin {
  _VizMode _mode = _VizMode.bars;
  late final AnimationController _anim;
  double _energy = 0.0;

  static const _modeIcons = {
    _VizMode.bars: Icons.bar_chart_rounded,
    _VizMode.wave: Icons.waves_rounded,
    _VizMode.particles: Icons.blur_on_rounded,
    _VizMode.minimal: Icons.horizontal_rule_rounded,
  };

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _energy = widget.isPlaying ? 1.0 : 0.0;
  }

  @override
  void didUpdateWidget(covariant CinematicVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_anim.isAnimating) {
      _anim.repeat();
    } else if (!widget.isPlaying && _anim.isAnimating) {
      _anim.stop();
    }
    final target = widget.isPlaying ? 1.0 : 0.06;
    if ((target - _energy).abs() > 0.001) {
      setState(() => _energy = target);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() {
        _mode = _VizMode.values[(_mode.index + 1) % _VizMode.values.length];
      }),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, _) {
                  switch (_mode) {
                    case _VizMode.bars:
                      return CustomPaint(
                        painter: _BarsPainter(
                          phase: _anim.value * 2 * math.pi,
                          energy: _energy,
                        ),
                      );
                    case _VizMode.wave:
                      return CustomPaint(
                        painter: _WavePainter(
                          phase: _anim.value * 2 * math.pi,
                          energy: _energy,
                        ),
                      );
                    case _VizMode.particles:
                      return CustomPaint(
                        painter: _ParticlesPainter(
                          phase: _anim.value,
                          energy: _energy,
                          seed: widget.trackId,
                        ),
                      );
                    case _VizMode.minimal:
                      return CustomPaint(
                        painter: _MinimalPainter(
                          phase: _anim.value * 2 * math.pi,
                          energy: _energy,
                        ),
                      );
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _modeIcons[_mode],
              color: CinematicTheme.textDim,
              size: 16,
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final double phase;
  final double energy;

  _BarsPainter({required this.phase, required this.energy});

  @override
  void paint(Canvas canvas, Size size) {
    const count = 22;
    final gap = size.width / count;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: Colors.white.a * 0.35)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final h = (3 +
              13 *
                  energy *
                  (0.35 + 0.65 * (0.5 + 0.5 * math.sin(phase + i * 0.9)))) *
          (1 - (i - count / 2).abs() / (count * 0.75)).clamp(0.25, 1.0);
      final x = gap * i + gap / 2;
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) =>
      old.phase != phase || old.energy != energy;
}

class _WavePainter extends CustomPainter {
  final double phase;
  final double energy;

  _WavePainter({required this.phase, required this.energy});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: Colors.white.a * 0.4)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var x = 0.0; x <= size.width; x += 3) {
      final y = size.height / 2 +
          math.sin(x / size.width * 2 * math.pi * 2 + phase) *
              (2 + 11 * energy);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.phase != phase || old.energy != energy;
}

class _ParticlesPainter extends CustomPainter {
  final double phase;
  final double energy;
  final int seed;

  _ParticlesPainter({
    required this.phase,
    required this.energy,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const count = 26;
    for (var i = 0; i < count; i++) {
      final r = ((seed + i * 37) % 100) / 100.0;
      final x = ((r * 7.3 + phase * (0.25 + r * 0.5)) % 1.0) * size.width;
      final yBase = ((r * 13.7) % 1.0) * size.height;
      var y = (yBase - phase * size.height * 0.35 * (0.3 + energy)) %
          size.height;
      if (y < 0) y += size.height;
      final paint = Paint()
        ..color = Colors.white.withValues(
          alpha: Colors.white.a * (0.10 + 0.30 * energy * r),
        );
      canvas.drawCircle(Offset(x, y), 1.4 + r * 1.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter old) =>
      old.phase != phase || old.energy != energy || old.seed != seed;
}

/// Почти статичная тонкая линия (п.7, Minimal).
class _MinimalPainter extends CustomPainter {
  final double phase;
  final double energy;

  _MinimalPainter({required this.phase, required this.energy});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: Colors.white.a * 0.30)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final midY = size.height / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), paint);
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: Colors.white.a * 0.55);
    final x = (0.5 + 0.42 * math.sin(phase * 0.5)) * size.width;
    final y = midY + math.sin(phase) * 3 * (0.3 + energy);
    canvas.drawCircle(Offset(x, y), 2.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _MinimalPainter old) =>
      old.phase != phase || old.energy != energy;
}

/// Информация о треке: крупное название, исполнитель, альбом, favorite (п.10).
class _TrackInfo extends StatelessWidget {
  final AudioTrack track;

  const _TrackInfo({required this.track});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final sub = track.album?.isNotEmpty == true ? track.album! : track.artist;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                MarqueeText(
                  text: track.title,
                  style: const TextStyle(
                    color: CinematicTheme.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: CinematicTheme.textSoft,
                    fontSize: 14,
                  ),
                ),
                if (sub != track.artist) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CinematicTheme.textDim,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _FavButton(
            isFavorite: track.isFavorite,
            onTap: () => player.toggleFavorite(track),
          ),
          IconButton(
            onPressed: () => TrackActionsSheet.show(context, track),
            icon: const Icon(
              Icons.more_vert_rounded,
              color: CinematicTheme.textDim,
              size: 22,
            ),
            tooltip: 'Действия с треком',
          ),
        ],
      ),
    );
  }
}

class _FavButton extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback onTap;

  const _FavButton({required this.isFavorite, required this.onTap});

  @override
  State<_FavButton> createState() => _FavButtonState();
}

class _FavButtonState extends State<_FavButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      lowerBound: 1.0,
      upperBound: 1.4,
    );
  }

  @override
  void didUpdateWidget(covariant _FavButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite != widget.isFavorite && widget.isFavorite) {
      _pop.forward(from: 1.0).then((_) {
        if (mounted) _pop.reverse();
      });
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
      child: IconButton(
        onPressed: widget.onTap,
        icon: Icon(
          widget.isFavorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          color: widget.isFavorite
              ? const Color(0xFFF472B6)
              : CinematicTheme.textDim,
          size: 24,
        ),
        tooltip: 'В избранное',
      ),
    );
  }
}

String _fmt(Duration d) {
  final total = d.inSeconds;
  final m = (total ~/ 60).toString();
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Тонкий luminous progress (п.9): акцент темы, крупный thumb при drag.
class _ProgressRow extends StatefulWidget {
  const _ProgressRow();

  @override
  State<_ProgressRow> createState() => _ProgressRowState();
}

class _ProgressRowState extends State<_ProgressRow> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final accent = cinematicAccent(context, player.currentTrack?.id);
    final durMs = player.duration.inMilliseconds;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: ValueListenableBuilder<Duration>(
        valueListenable: player.positionTick,
        builder: (_, pos, __) {
          final posMs = pos.inMilliseconds;
          final frac = durMs > 0
              ? (posMs / durMs).clamp(0.0, 1.0).toDouble()
              : 0.0;
          return Row(
            children: [
              SizedBox(
                width: 38,
                child: Text(
                  _fmt(pos),
                  style: const TextStyle(
                    color: CinematicTheme.textDim,
                    fontSize: 11,
                  ),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    activeTrackColor: accent,
                    inactiveTrackColor: const Color(0x3DFFFFFF),
                    thumbColor: Colors.white,
                    thumbShape: RoundSliderThumbShape(
                      enabledThumbRadius: _dragging ? 9 : 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 18,
                    ),
                    overlayColor: accent.withValues(
                      alpha: accent.a * 0.18,
                    ),
                  ),
                  child: Slider(
                    value: frac,
                    onChangeStart: (_) =>
                        setState(() => _dragging = true),
                    onChangeEnd: (_) =>
                        setState(() => _dragging = false),
                    onChanged: (v) => player.seek(
                      Duration(milliseconds: (durMs * v).round()),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 38,
                child: Text(
                  _fmt(player.duration),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: CinematicTheme.textDim,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Компактные контролы: стеклянный play + prev/next (п.8).
/// Свечение — цветом темы, press — с scale-анимацией.
class _ControlsRow extends StatefulWidget {
  /// Neon-режим: shuffle + repeat по бокам (ряд из 5, как в референсе).
  final bool full;

  const _ControlsRow({this.full = false});

  @override
  State<_ControlsRow> createState() => _ControlsRowState();
}

class _ControlsRowState extends State<_ControlsRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.92,
      upperBound: 1.0,
    )..value = 1.0;
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final accent = cinematicAccent(context, player.currentTrack?.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.full)
            IconButton(
              onPressed: player.toggleShuffle,
              icon: Icon(
                Icons.shuffle_rounded,
                color: player.shuffleMode
                    ? accent
                    : CinematicTheme.textDim,
                size: 22,
              ),
              tooltip: 'Перемешать',
            ),
          if (widget.full) const SizedBox(width: 6),
          IconButton(
            onPressed: player.previous,
            icon: const Icon(
              Icons.skip_previous_rounded,
              color: CinematicTheme.textSoft,
              size: 30,
            ),
            tooltip: 'Предыдущий',
          ),
          const SizedBox(width: 18),
          GestureDetector(
            onTapDown: (_) => _press.reverse(),
            onTapUp: (_) => _press.forward(),
            onTapCancel: () => _press.forward(),
            onTap: player.togglePlay,
            child: ScaleTransition(
              scale: _press,
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(
                    alpha: Colors.white.a * 0.10,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: Colors.white.a * 0.22,
                    ),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(
                        alpha: accent.a * 0.35,
                      ),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  player.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          IconButton(
            onPressed: player.next,
            icon: const Icon(
              Icons.skip_next_rounded,
              color: CinematicTheme.textSoft,
              size: 30,
            ),
            tooltip: 'Следующий',
          ),
          if (widget.full) const SizedBox(width: 6),
          if (widget.full)
            IconButton(
              onPressed: player.toggleRepeat,
              icon: Icon(
                player.repeatMode == PlayerRepeatMode.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                color: player.repeatMode == PlayerRepeatMode.off
                    ? CinematicTheme.textDim
                    : accent,
                size: 22,
              ),
              tooltip: 'Повтор',
            ),
        ],
      ),
    );
  }
}
