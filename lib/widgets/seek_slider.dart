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
  final double trackHeight;
  final bool showTimes;

  const SeekSlider({
    super.key,
    required this.player,
    this.activeColor,
    this.thumbColor,
    this.trackHeight = 4,
    this.showTimes = true,
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

    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: widget.trackHeight,
        activeTrackColor: widget.activeColor ?? AppTheme.accent,
        inactiveTrackColor: AppTheme.surfaceLight,
        thumbColor: widget.thumbColor ?? AppTheme.accentLight,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayColor: (widget.activeColor ?? AppTheme.accent).withValues(
          alpha: (widget.activeColor ?? AppTheme.accent).a * 0.15,
        ),
      ),
      child: Slider(
        value: frac,
        onChangeStart: (v) => setState(() {
          _dragging = true;
          _dragFrac = v;
        }),
        onChanged: (v) => setState(() => _dragFrac = v),
        onChangeEnd: (v) {
          setState(() => _dragging = false);
          if (durMs > 0) {
            widget.player.seek(Duration(milliseconds: (v * durMs).round()));
          }
        },
      ),
    );

    if (!widget.showTimes) return slider;

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
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              Text(
                _fmt(widget.player.duration),
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}