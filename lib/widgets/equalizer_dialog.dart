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
      'Flat (Стандарт)',
      'X-Bass',
      'Bass Boost',
      'Treble Boost',
      'X-Wide',
      'Reverb',
      'Rock',
      'Pop',
      'Jazz',
      'Classical',
      'Electronic',
      'Hip-Hop',
      'Acoustic',
      'Dance',
      'Bass & Treble',
      'Vocal Clarity',
      'Classic Rock',
      'Soft Rock',
      'Reggae',
      'Soul',
      'Country',
      'Lounge',
      'Piano',
      'Opera',
    ];

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
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
            child:
                const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
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
        height: 480,
        child: ListView(
          children: presets.map((name) {
            final gains = PlayerProvider.eqGainsFor(name);
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
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: gains.map((g) {
                        final h = 22 * ((g + 12) / 24).clamp(0.1, 1.0);
                        return Container(
                          width: 3,
                          height: h,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? AppTheme.primaryGradient
                                : LinearGradient(colors: [
                                    AppTheme.textMuted,
                                    AppTheme.textSecondary,
                                  ]),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(width: 8),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded,
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
    );
  }
}