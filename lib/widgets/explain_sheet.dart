import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/audio_track.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';

class ExplainSheet extends StatelessWidget {
  final AudioTrack track;

  const ExplainSheet({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final breakdown = player.trackScoreBreakdown(track);
    final total = breakdown.values.fold<double>(0, (a, b) => a + b);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.psychology_rounded,
                    color: AppTheme.accentLight, size: 20),
                SizedBox(width: 8),
                Text(
                  'Почему Personal DJ выбрал это',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (breakdown.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Пока без явных причин — трек попал через случайный отбор. Слушай и ставь избранное, чтобы DJ учился.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: breakdown.entries.map((e) {
                    final positive = e.value > 0;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            positive
                                ? Icons.add_circle_outline_rounded
                                : Icons.remove_circle_outline_rounded,
                            color: positive
                                ? AppTheme.accentGreen
                                : AppTheme.accentPink,
                            size: 17,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              e.key,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '${positive ? '+' : ''}${e.value.toStringAsFixed(1)}',
                            style: TextStyle(
                              color: positive
                                  ? AppTheme.accentGreen
                                  : AppTheme.accentPink,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 10),
            Container(
              width: 100,
              height: 1,
              color: AppTheme.cardBorder,
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                children: [
                  const Spacer(),
                  Text(
                    'Итог: ${total.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: AppTheme.accentLight,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}