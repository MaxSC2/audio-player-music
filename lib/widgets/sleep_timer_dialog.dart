import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';

class SleepTimerDialog extends StatelessWidget {
  const SleepTimerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final activeMinutes = player.sleepTimerMinutes;

    final options = [
      {'label': 'Выключен', 'minutes': 0},
      {'label': '5 минут', 'minutes': 5},
      {'label': '15 минут', 'minutes': 15},
      {'label': '30 минут', 'minutes': 30},
      {'label': '45 минут', 'minutes': 45},
      {'label': '60 минут', 'minutes': 60},
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
            child: const Icon(Icons.nightlight_round, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            'Таймер сна',
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((opt) {
            final minutes = opt['minutes'] as int;
            final isSelected = activeMinutes == minutes;

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.accent.withOpacity(0.15) : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.accent : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: ListTile(
                title: Text(
                  opt['label'] as String,
                  style: TextStyle(
                    color: isSelected ? AppTheme.accentLight : AppTheme.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle_rounded, color: AppTheme.accent)
                    : null,
                onTap: () {
                  if (minutes == 0) {
                    player.cancelSleepTimer();
                  } else {
                    player.setSleepTimer(minutes);
                  }
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
