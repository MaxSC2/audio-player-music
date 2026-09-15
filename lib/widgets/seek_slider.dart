import 'package:flutter/material.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';

/// Плавкий слайдер перемотки, который НЕ вызывает ANR.
///
/// Корень бага: использование `ValueListenableBuilder(positionTick)` напрямую
/// перестраивало слайдер на каждый тик позиции (5+ раз/сек) — в том числе во
/// время перетаскивания. Ребилды от потока складывались с setState от пальца,
/// интерфейс зависал → «Приложение не отвечает».
///
/// Решение: собственная подписка на поток позиции, которая ЗАМОРАЖИВАЕТСЯ
/// на время drag. Во время перетаскивания слайдер 100% локален — поток
/// позиции его не трогает. seek() вызывается ровно один раз — в onChangeEnd.
class SeekSlider extends StatefulWidget {
  final PlayerProvider player;
  final Color? activeColor;
  final Color? thumbColor;
  final Color? inactiveColor;
  final double trackHeight;
  final bool showTimes;

  /// B8-опции стилизации (чтобы cinematic/cover-flow не держали свои копии):
  /// [showRemaining] — справа «-остаток» вместо полной длительности;
  /// [timesInRow] — время по бокам от слайдера (cinematic) вместо строки снизу;
  /// [thumbRadius]/[activeThumbRadius] — радиус ручки в покое/при drag;
  /// [overlayRadius]/[overlayOpacity] — стилизация оверлея нажатия.
  final bool showRemaining;
  final bool timesInRow;
  final double thumbRadius;
  final double? activeThumbRadius;
  final double? overlayRadius;
  final double overlayOpacity;
  final Color? timeColor;
  final double timeFontSize;
  final double timeBoxWidth;

  const SeekSlider({
    super.key,
    required this.player,
    this.activeColor,
    this.thumbColor,
    this.inactiveColor,
    this.trackHeight = 4,
    this.showTimes = true,
    this.showRemaining = false,
    this.timesInRow = false,
    this.thumbRadius = 7,
    this.activeThumbRadius,
    this.overlayRadius,
    this.overlayOpacity = 0.15,
    this.timeColor,
    this.timeFontSize = 12,
    this.timeBoxWidth = 38,
  });

  @override
  State<SeekSlider> createState() => _SeekSliderState();
}

class _SeekSliderState extends State<SeekSlider> {
  /// Локальная позиция для отображения. Обновляется из потока ТОЛЬКО когда не
  /// тянем ползунок — иначе тики вызывают хаотичные ребилды прямо под пальцем.
  Duration _displayPos = Duration.zero;
  bool _dragging = false;
  double _dragFrac = 0;

  @override
  void initState() {
    super.initState();
    _displayPos = widget.player.position;
    // Подписка на тикер: обновляем позицию, только если сейчас не drag.
    widget.player.positionTick.addListener(_onTick);
  }

  void _onTick() {
    if (!_dragging && mounted) {
      setState(() => _displayPos = widget.player.positionTick.value);
    }
  }

  @override
  void dispose() {
    widget.player.positionTick.removeListener(_onTick);
    super.dispose();
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final durMs = widget.player.duration.inMilliseconds;
    final liveFrac = durMs > 0
        ? (_displayPos.inMilliseconds / durMs).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final frac = _dragging ? _dragFrac : liveFrac;

    final activeColor = widget.activeColor ?? AppTheme.accent;
    final thumbRadius = _dragging
        ? (widget.activeThumbRadius ?? widget.thumbRadius + 2)
        : widget.thumbRadius;
    final overlayRadius = widget.overlayRadius ?? (widget.thumbRadius + 11);
    final timeStyle = TextStyle(
      color: widget.timeColor ?? AppTheme.textMuted,
      fontSize: widget.timeFontSize,
    );

    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: widget.trackHeight,
        activeTrackColor: activeColor,
        inactiveTrackColor: widget.inactiveColor ?? AppTheme.surfaceLight,
        thumbColor: widget.thumbColor ?? AppTheme.accentLight,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: thumbRadius),
        overlayShape: RoundSliderOverlayShape(overlayRadius: overlayRadius),
        overlayColor: activeColor.withValues(alpha: activeColor.a * widget.overlayOpacity),
      ),
      child: Slider(
        value: frac,
        onChangeStart: (v) => setState(() {
          _dragging = true;
          _dragFrac = v;
        }),
        onChanged: (v) => setState(() => _dragFrac = v),
        onChangeEnd: (v) {
          setState(() {
            _dragging = false;
            // B7: сразу фиксируем позицию под пальцем — иначе до следующего
            // тика ползунок показывал бы старую позицию (микро-отскок).
            if (durMs > 0) {
              _displayPos = Duration(milliseconds: (v * durMs).round());
            }
          });
          if (durMs > 0) {
            widget.player.seek(Duration(milliseconds: (v * durMs).round()));
          }
        },
      ),
    );

    // Время скрыто — только слайдер.
    if (!widget.showTimes) return slider;

    // Cinematic-режим: время по бокам от слайдера в одном ряду.
    if (widget.timesInRow) {
      return Row(
        children: [
          SizedBox(
            width: widget.timeBoxWidth,
            child: Text(
              _fmt(_dragging
                  ? Duration(milliseconds: (frac * durMs).round())
                  : _displayPos),
              style: timeStyle,
            ),
          ),
          Expanded(child: slider),
          SizedBox(
            width: widget.timeBoxWidth,
            child: Text(
              _fmt(widget.player.duration),
              textAlign: TextAlign.right,
              style: timeStyle,
            ),
          ),
        ],
      );
    }

    // Классический режим: слайдер, ниже строка «позиция … остаток/длительность».
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        slider,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _dragging
                    ? _fmt(Duration(milliseconds: (frac * durMs).round()))
                    : _fmt(_displayPos),
                style: timeStyle,
              ),
              Text(
                widget.showRemaining
                    ? '-${_fmt(widget.player.duration - _displayPos)}'
                    : _fmt(widget.player.duration),
                style: timeStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}