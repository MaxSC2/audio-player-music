import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';

class EqualizerDialog extends StatelessWidget {
  const EqualizerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final activePreset = player.equalizerPreset;

    final presets = [
      {'name': 'Flat (Стандарт)', 'bars': [0.5, 0.5, 0.5, 0.5, 0.5]},
      {'name': 'Bass Boost 💥', 'bars': [0.95, 0.8, 0.45, 0.35, 0.3]},
      {'name': 'Electronic ⚡', 'bars': [0.85, 0.65, 0.3, 0.75, 0.9]},
      {'name': 'Rock 🎸', 'bars': [0.8, 0.6, 0.7, 0.8, 0.85]},
      {'name': 'Pop 🎤', 'bars': [0.4, 0.65, 0.85, 0.7, 0.5]},
      {'name': 'Jazz 🎷', 'bars': [0.65, 0.5, 0.4, 0.65, 0.75]},
      {'name': 'Vocal Clarity 🗣️', 'bars': [0.3, 0.5, 0.95, 0.8, 0.4]},
      {'name': 'Hi-Fi Studio 🎧', 'bars': [0.75, 0.55, 0.5, 0.6, 0.8]},
    ];

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.cardBorder),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.graphic_eq_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'Эквалайзер / Пресеты',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: presets.map((preset) {
              final name = preset['name'] as String;
              final bars = preset['bars'] as List<double>;
              final isSelected = activePreset == name;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accent.withOpacity(0.18)
                      : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.accent : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                child: ListTile(
                  title: Text(
                    name,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.accentLight
                          : AppTheme.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: bars.map((b) {
                          return Container(
                            width: 3.5,
                            height: 20 * b,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? AppTheme.primaryGradient
                                  : const LinearGradient(
                                      colors: [
                                        AppTheme.textMuted,
                                        AppTheme.textSecondary,
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(width: 8),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded,
                            color: AppTheme.accent, size: 20),
                    ],
                  ),
                  onTap: () {
                    player.setEqualizerPreset(name);
                    Navigator.pop(context);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
