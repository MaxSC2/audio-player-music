import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';
import 'circular_timer_dial.dart';

class SleepTimerDialog extends StatefulWidget {
  const SleepTimerDialog({super.key});

  @override
  State<SleepTimerDialog> createState() => _SleepTimerDialogState();
}

class _SleepTimerDialogState extends State<SleepTimerDialog> {
  late int _minutes;
  // F4: опции таймера сна.
  late bool _fadeOut;
  late bool _untilEnd;

  @override
  void initState() {
    super.initState();
    final player = context.read<PlayerProvider>();
    _minutes = player.sleepTimerMinutes;
    _fadeOut = player.sleepFadeOut;
    _untilEnd = player.sleepUntilTrackEnd;
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final activeMinutes = player.sleepTimerMinutes;

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
            child: const Icon(
              Icons.nightlight_round,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Таймер сна',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (activeMinutes > 0)
                Text(
                  'Активен: $activeMinutes мин',
                  style: TextStyle(
                    color: AppTheme.accentLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularTimerDial(
                initialMinutes: _minutes,
                onChanged: (v) => setState(() => _minutes = v),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                value: _fadeOut,
                onChanged: (v) => setState(() => _fadeOut = v),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  'Плавное затухание',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Громкость уходит в 0 за ~8 секунд',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ),
              SwitchListTile(
                value: _untilEnd,
                onChanged: (v) => setState(() => _untilEnd = v),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  'Дослушать текущий трек',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Остановка на границе трека, а не на полуслове',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: BorderSide(color: AppTheme.cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_minutes == 0) {
                          player.cancelSleepTimer();
                        } else {
                          player.setSleepTimer(
                            _minutes,
                            fadeOut: _fadeOut,
                            untilTrackEnd: _untilEnd,
                          );
                        }
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(_minutes == 0 ? 'Выключить' : 'Старт'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
