import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../ui/theme.dart';

/// Компактный регулятор громкости для ряда функций плеера (E3-часть 1).
///
/// Работает как SeekSlider: во время drag значение живёт локально и
/// применяется через лёгкий [PlayerProvider.previewVolume] (без prefs
/// и без `_notify` на каждый пиксель), финальное фиксируется
/// [PlayerProvider.setVolume] в `onChangeEnd`. Внешние изменения
/// громкости подхватываются через `select` когда не тянем.
class VolumeControl extends StatefulWidget {
  const VolumeControl({super.key});

  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl> {
  bool _dragging = false;
  double _dragValue = 1.0;

  @override
  Widget build(BuildContext context) {
    // Реактивно только на внешние изменения; во время drag select
    // не срабатывает (previewVolume не нотифицирует) — шторма нет.
    final external = context.select<PlayerProvider, double>((p) => p.volume);
    final value = _dragging ? _dragValue : external;

    final icon = value <= 0.01
        ? Icons.volume_off_rounded
        : value < 0.5
            ? Icons.volume_down_rounded
            : Icons.volume_up_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 18),
          SizedBox(
            width: 90,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: value.clamp(0.0, 1.0),
                activeColor: AppTheme.accentCyan,
                inactiveColor: AppTheme.cardBorder,
                onChangeStart: (v) => setState(() {
                  _dragging = true;
                  _dragValue = v;
                }),
                onChanged: (v) {
                  setState(() => _dragValue = v);
                  context.read<PlayerProvider>().previewVolume(v);
                },
                onChangeEnd: (v) async {
                  setState(() => _dragging = false);
                  await context.read<PlayerProvider>().setVolume(v);
                },
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
