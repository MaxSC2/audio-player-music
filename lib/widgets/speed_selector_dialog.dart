import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';

class SpeedSelectorDialog extends StatefulWidget {
  const SpeedSelectorDialog({super.key});

  @override
  State<SpeedSelectorDialog> createState() => _SpeedSelectorDialogState();
}

class _SpeedSelectorDialogState extends State<SpeedSelectorDialog> {
  late double _speed;

  final List<double> _presets = const [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  void initState() {
    super.initState();
    _speed = context.read<PlayerProvider>().speed;
  }

  String get _label => '${_speed.toStringAsFixed(2).replaceFirst(RegExp(r'\.0+$'), '').replaceFirst(RegExp(r'\.$'), '')}x';

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppTheme.cardBorder),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.speed_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            'Скорость',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _speed == 1.0 ? AppTheme.surfaceLight : AppTheme.accentCyan.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _speed == 1.0 ? AppTheme.cardBorder : AppTheme.accentCyan),
            ),
            child: Text(
              _label,
              style: TextStyle(
                color: _speed == 1.0 ? AppTheme.textSecondary : AppTheme.accentCyan,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            // Slider
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppTheme.accent,
                inactiveTrackColor: AppTheme.surfaceLight,
                thumbColor: AppTheme.accentLight,
                overlayColor: AppTheme.accent.withOpacity(0.15),
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
              ),
              child: Slider(
                min: 0.5,
                max: 2.0,
                divisions: 30,
                value: _speed.clamp(0.5, 2.0),
                label: _label,
                onChanged: (v) {
                  final stepped = (v * 20).round() / 20; // step 0.05
                  setState(() => _speed = stepped.clamp(0.5, 2.0));
                  player.setSpeed(_speed);
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0.5x', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                Text('1.0x', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                Text('2.0x', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 16),
            // Presets
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _presets.map((p) {
                final label = '${p.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), '').replaceFirst(RegExp(r'\.0$'), '')}x';
                final selected = (p - _speed).abs() < 0.01;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _speed = p);
                    player.setSpeed(p);
                  },
                  selectedColor: AppTheme.accent.withOpacity(0.2),
                  backgroundColor: AppTheme.surfaceLight,
                  labelStyle: TextStyle(
                    color: selected ? AppTheme.accentLight : AppTheme.textSecondary,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  side: BorderSide(color: selected ? AppTheme.accent : Colors.transparent),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _speed = 1.0);
                      player.setSpeed(1.0);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: BorderSide(color: AppTheme.cardBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Сброс 1.0x'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Готово'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
