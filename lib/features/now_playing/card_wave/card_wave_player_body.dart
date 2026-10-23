import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/audio_track.dart';
import '../../../providers/player_provider.dart';
import '../../../widgets/cached_artwork.dart';
import '../../../widgets/queue_sheet.dart';
import '../../../widgets/seek_slider.dart';
import '../../../widgets/track_actions_sheet.dart';
import 'card_wave_theme.dart';

@visibleForTesting
int cardWaveSwipeAction(double dx, double velocity) {
  if (dx <= -28 || velocity <= -340) return 1;
  if (dx >= 28 || velocity >= 340) return -1;
  return 0;
}

class CardWavePlayerBody extends StatefulWidget {
  const CardWavePlayerBody({super.key});

  @override
  State<CardWavePlayerBody> createState() => _CardWavePlayerBodyState();
}

class _CardWavePlayerBodyState extends State<CardWavePlayerBody>
    with TickerProviderStateMixin {
  late final AnimationController _flip;
  late final AnimationController _motion;

  double _dragX = 0;
  bool _dragging = false;
  bool _flipped = false;
  bool _flying = false;
  int? _lastTrackId;
  int _motionToken = 0;
  Animation<double>? _motionTween;
  VoidCallback? _motionDone;

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 230),
    );
  }

  @override
  void dispose() {
    _flip.dispose();
    _motion.dispose();
    super.dispose();
  }

  double get _displayX =>
      _dragging ? _dragX : (_motionTween?.value ?? _dragX);

  void _toggleFlip() {
    if (_flying || _displayX.abs() > 3) return;
    setState(() => _flipped = !_flipped);
    if (_flipped) {
      _flip.forward();
    } else {
      _flip.reverse();
    }
  }

  void _onDragStart(DragStartDetails details) {
    if (_flying) return;
    _motionToken++;
    _motion.stop();
    _motionTween = null;
    setState(() {
      _dragging = true;
      _dragX = 0;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_flying) return;
    setState(() {
      _dragX = (_dragX + details.delta.dx).clamp(-180.0, 180.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    setState(() => _dragging = false);
    final action = cardWaveSwipeAction(
      _dragX,
      details.primaryVelocity ?? 0,
    );
    if (action == 0) {
      _settle();
      return;
    }
    _throwCard(action);
  }

  void _onDragCancel() {
    if (!_dragging) return;
    setState(() => _dragging = false);
    _settle();
  }

  void _settle() {
    _runMotion(
      0,
      onDone: () {
        if (!mounted) return;
        setState(() {
          _dragX = 0;
          _motionTween = null;
        });
      },
    );
  }

  void _throwCard(int direction) {
    if (_flying) return;
    setState(() => _flying = true);
    _runMotion(
      direction > 0 ? 620 : -620,
      onDone: () => unawaited(_afterThrow(direction)),
    );
  }

  Future<void> _afterThrow(int direction) async {
    final player = context.read<PlayerProvider>();
    final before = player.currentTrack?.id;
    if (direction > 0) {
      await player.next();
    } else {
      await player.previous(restartCurrent: false);
    }
    if (!mounted) return;
    final changed = player.currentTrack?.id != before;
    if (changed) {
      unawaited(HapticFeedback.mediumImpact());
      setState(() {
        _dragX = 0;
        _motionTween = null;
        _flying = false;
        _flipped = false;
      });
      _flip.value = 0;
      return;
    }
    setState(() => _flying = false);
    _settle();
  }

  void _runMotion(double target, {VoidCallback? onDone}) {
    final token = ++_motionToken;
    _motionTween = Tween<double>(begin: _displayX, end: target).animate(
      CurvedAnimation(parent: _motion, curve: Curves.easeOutCubic),
    );
    _motionDone = onDone;
    _motion.forward(from: 0).whenComplete(() {
      if (!mounted || token != _motionToken) return;
      final done = _motionDone;
      _motionDone = null;
      done?.call();
    });
  }

  void _resetFlipForNewTrack(int id) {
    if (_lastTrackId == id) return;
    _lastTrackId = id;
    if (!_flipped) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_flipped) return;
      setState(() => _flipped = false);
      _flip.value = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.select<
      PlayerProvider,
      ({
        AudioTrack? track,
        List<AudioTrack> queue,
        int index,
        bool playing,
        bool favorite,
        bool shuffle,
        PlayerRepeatMode repeat,
      })
    >(
      (p) {
        final track = p.currentTrack;
        return (
          track: track,
          queue: p.playlist,
          index: p.currentIndex,
          playing: p.isPlaying,
          favorite: track != null && p.isFavorite(track.id),
          shuffle: p.shuffleMode,
          repeat: p.repeatMode,
        );
      },
    );

    final track = state.track;
    if (track == null || state.queue.isEmpty) {
      return const _EmptyDeck();
    }
    _resetFlipForNewTrack(track.id);

    final index = state.index.clamp(0, state.queue.length - 1);
    final previous = index > 0 ? state.queue[index - 1] : null;
    final next = index + 1 < state.queue.length ? state.queue[index + 1] : null;

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardHeight = math.min(
                constraints.maxHeight * 0.96,
                (constraints.maxWidth * 0.74) / 0.68,
              );
              final cardWidth = cardHeight * 0.68;
              return Center(
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: cardHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      if (previous != null)
                        _PeekCard(
                          track: previous,
                          width: cardWidth * 0.82,
                          height: cardHeight * 0.82,
                          angle: -0.11,
                          offset: Offset(-cardWidth * 0.29, 12),
                        ),
                      if (next != null)
                        _PeekCard(
                          track: next,
                          width: cardWidth * 0.82,
                          height: cardHeight * 0.82,
                          angle: 0.11,
                          offset: Offset(cardWidth * 0.29, 12),
                        ),
                      GestureDetector(
                        onTap: _toggleFlip,
                        onHorizontalDragStart: _onDragStart,
                        onHorizontalDragUpdate: _onDragUpdate,
                        onHorizontalDragEnd: _onDragEnd,
                        onHorizontalDragCancel: _onDragCancel,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_flip, _motion]),
                          builder: (context, _) {
                            final x = _displayX;
                            final angle = (x / cardWidth) * 0.24;
                            final flip = _flip.value;
                            final showBack = flip >= 0.5;
                            final face = showBack
                                ? _CardBack(
                                    track: track,
                                    queue: state.queue,
                                    index: index,
                                    width: cardWidth,
                                    height: cardHeight,
                                    onOpenQueue: _openQueue,
                                  )
                                : _CardFront(
                                    track: track,
                                    index: index,
                                    width: cardWidth,
                                    height: cardHeight,
                                  );
                            return Transform.translate(
                              offset: Offset(x, 0),
                              child: Transform.rotate(
                                angle: angle,
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.0014)
                                    ..rotateY(flip * math.pi),
                                  child: showBack
                                      ? Transform(
                                          alignment: Alignment.center,
                                          transform: Matrix4.rotationY(math.pi),
                                          child: face,
                                        )
                                      : face,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 10, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: cardWaveCream,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: cardWaveMuted,
                        fontSize: 13,
                      ),
                    ),
                    if (track.album != null && track.album!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        track.album!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6F685C),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: state.favorite
                    ? 'Убрать из избранного'
                    : 'В избранное',
                onPressed: () => context
                    .read<PlayerProvider>()
                    .toggleFavorite(track),
                icon: Icon(
                  state.favorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: state.favorite ? cardWaveGold : cardWaveMuted,
                ),
              ),
              IconButton(
                tooltip: 'Ещё',
                onPressed: () => TrackActionsSheet.show(context, track),
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: cardWaveMuted,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
          child: SeekSlider(
            player: context.read<PlayerProvider>(),
            activeColor: cardWaveGoldSoft,
            inactiveColor: const Color(0x38FFFFFF),
            thumbColor: cardWaveCream,
            trackHeight: 3,
            thumbRadius: 6,
            activeThumbRadius: 8,
            overlayRadius: 17,
            overlayOpacity: 0.16,
            timeColor: cardWaveMuted,
            timeFontSize: 10,
            timesInRow: true,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Тасовать',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  context.read<PlayerProvider>().toggleShuffle();
                },
                icon: Icon(
                  Icons.shuffle_rounded,
                  color: state.shuffle ? cardWaveGold : cardWaveMuted,
                ),
              ),
              IconButton(
                tooltip: 'Предыдущая карта',
                onPressed: () => _throwCard(-1),
                icon: const Icon(
                  Icons.skip_previous_rounded,
                  color: cardWaveCream,
                  size: 30,
                ),
              ),
              _PlayCardButton(
                playing: state.playing,
                onTap: context.read<PlayerProvider>().togglePlay,
              ),
              IconButton(
                tooltip: 'Следующая карта',
                onPressed: () => _throwCard(1),
                icon: const Icon(
                  Icons.skip_next_rounded,
                  color: cardWaveCream,
                  size: 30,
                ),
              ),
              IconButton(
                tooltip: 'Джокер: повтор',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  context.read<PlayerProvider>().toggleRepeat();
                },
                icon: Icon(
                  state.repeat == PlayerRepeatMode.one
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  color: state.repeat == PlayerRepeatMode.off
                      ? cardWaveMuted
                      : cardWaveGold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openQueue() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cardWaveBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const QueueSheet(),
    );
  }
}

class _CardFront extends StatelessWidget {
  final AudioTrack track;
  final int index;
  final double width;
  final double height;

  const _CardFront({
    required this.track,
    required this.index,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1E4C5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardWaveGold, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedArtwork(
              trackId: track.id,
              width: width - 14,
              height: height - 14,
              radius: 0,
              fallback: const ColoredBox(
                color: Color(0xFF211D28),
                child: Icon(
                  Icons.music_note_rounded,
                  color: cardWaveGold,
                  size: 64,
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x22000000),
                    Color(0x00000000),
                    Color(0xCC000000),
                  ],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: _CardPip(
                value: '${index + 1}'.padLeft(2, '0'),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _CardPip(
                value: track.formattedDuration,
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CARDWAVE',
                    style: TextStyle(
                      color: Color(0xCCF1E4C5),
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF6EDDC),
                      fontSize: 17,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFC8BDA6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardPip extends StatelessWidget {
  final String value;

  const _CardPip({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x9909090D),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x66C9B47C)),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Color(0xFFE8D6AA),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  final AudioTrack track;
  final List<AudioTrack> queue;
  final int index;
  final double width;
  final double height;
  final VoidCallback onOpenQueue;

  const _CardBack({
    required this.track,
    required this.queue,
    required this.index,
    required this.width,
    required this.height,
    required this.onOpenQueue,
  });

  @override
  Widget build(BuildContext context) {
    final upcoming = <AudioTrack>[];
    for (var i = index + 1; i < queue.length && upcoming.length < 3; i++) {
      upcoming.add(queue[i]);
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF151218),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardWaveGold, width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _CardBackPainter()),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.style_rounded,
                        color: cardWaveGold,
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      const Expanded(
                        child: Text(
                          'THE DECK',
                          style: TextStyle(
                            color: cardWaveCream,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.2,
                          ),
                        ),
                      ),
                      Text(
                        '${index + 1}/${queue.length}',
                        style: const TextStyle(
                          color: cardWaveMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Center(
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0x66C9B47C),
                          width: 1.2,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'CW',
                          style: TextStyle(
                            color: cardWaveGold,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'РУБАШКА КОЛОДЫ',
                      style: TextStyle(
                        color: cardWaveMuted,
                        fontSize: 9,
                        letterSpacing: 2.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (upcoming.isNotEmpty) ...[
                    const Text(
                      'ДАЛЬШЕ НА СТОЛЕ',
                      style: TextStyle(
                        color: cardWaveGold,
                        fontSize: 9,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < upcoming.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          children: [
                            Text(
                              '${index + i + 2}'.padLeft(2, '0'),
                              style: const TextStyle(
                                color: Color(0xFF6F685C),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                upcoming[i].title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: cardWaveCream,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onOpenQueue,
                      icon: const Icon(Icons.layers_rounded, size: 16),
                      label: const Text('Открыть колоду'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cardWaveGold,
                        side: const BorderSide(color: Color(0x66C9B47C)),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      'Нажми на карту, чтобы вернуться',
                      style: TextStyle(
                        color: Color(0xFF6F685C),
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeekCard extends StatelessWidget {
  final AudioTrack track;
  final double width;
  final double height;
  final double angle;
  final Offset offset;

  const _PeekCard({
    required this.track,
    required this.width,
    required this.height,
    required this.angle,
    required this.offset,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.translate(
        offset: offset,
        child: Transform.rotate(
          angle: angle,
          child: Opacity(
            opacity: 0.62,
            child: Container(
              width: width,
              height: height,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1720),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x88C9B47C)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedArtwork(
                      trackId: track.id,
                      width: width - 10,
                      height: height - 10,
                      radius: 0,
                    ),
                    const ColoredBox(color: Color(0x9909090D)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayCardButton extends StatelessWidget {
  final bool playing;
  final VoidCallback onTap;

  const _PlayCardButton({required this.playing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A222E), Color(0xFF141117)],
          ),
          border: Border.all(color: cardWaveGold, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55C9B47C),
              blurRadius: 22,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: cardWaveCream,
          size: 32,
        ),
      ),
    );
  }
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 82,
            height: 110,
            decoration: BoxDecoration(
              color: const Color(0xFF151218),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x66C9B47C)),
            ),
            child: const Icon(
              Icons.style_rounded,
              color: cardWaveGold,
              size: 34,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Колода пуста',
            style: TextStyle(
              color: cardWaveCream,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Выбери трек в библиотеке',
            style: TextStyle(color: cardWaveMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0x1FC9B47C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const step = 26.0;
    for (var x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        line,
      );
      canvas.drawLine(
        Offset(x + size.height, 0),
        Offset(x, size.height),
        line,
      );
    }
    final frame = Paint()
      ..color = const Color(0x55C9B47C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      frame,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
