import 'package:flutter/material.dart';
import '../ui/theme.dart';

/// Диалог выбора цвета: HSV-слайдеры + живой предпросмотр + hex.
class ColorPickerDialog extends StatefulWidget {
  final Color initial;

  const ColorPickerDialog({super.key, required this.initial});

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late HSLColor _hsl;

  @override
  void initState() {
    super.initState();
    _hsl = HSLColor.fromColor(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsl.toColor();
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Цвет',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [color, color.withOpacity(0.6)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Center(
                child: Text(
                  '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _HsvSlider(
              label: 'Тон',
              value: _hsl.hue / 360,
              color: color,
              onChanged: (v) => setState(() => _hsl = _hsl.withHue(v * 360)),
            ),
            const SizedBox(height: 6),
            _HsvSlider(
              label: 'Насыщенность',
              value: _hsl.saturation,
              color: HSLColor.fromHue(_hsl.hue).toColor(),
              onChanged: (v) =>
                  setState(() => _hsl = _hsl.withSaturation(v)),
            ),
            const SizedBox(height: 6),
            _HsvSlider(
              label: 'Яркость',
              value: _hsl.lightness,
              color: HSLColor.fromHue(_hsl.hue)
                  .withSaturation(_hsl.saturation)
                  .toColor(),
              onChanged: (v) => setState(() => _hsl = _hsl.withLightness(v)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(color),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.black,
          ),
          child: const Text('Готово', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _HsvSlider extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  const _HsvSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(0.0, 1.0),
            activeColor: color,
            inactiveColor: AppTheme.surfaceLight,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}