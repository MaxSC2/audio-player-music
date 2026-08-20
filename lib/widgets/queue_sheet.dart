import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/queue_snapshot.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';
import 'animated_waveform.dart';

class QueueSheet extends StatelessWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final queue = player.playlist;
    final currentIndex = player.currentIndex;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.queue_music_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Очередь воспроизведения (${queue.length})',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.bookmark_add_outlined,
                    color: AppTheme.textSecondary),
                onPressed: () {
                  if (queue.isEmpty) return;
                  final now = DateTime.now();
                  final name =
                      'Очередь ${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')} '
                      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                  player.saveQueueSnapshot(name);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Очередь сохранена как «$name»'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                tooltip: 'Сохранить очередь',
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppTheme.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: AppTheme.cardBorder),

          // Saved queue snapshots
          if (player.queueSnapshots.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  'Сохранённые очереди',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: player.queueSnapshots.map((QueueSnapshot s) {
                  final t = DateTime.fromMillisecondsSinceEpoch(s.createdAt);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.accent.withOpacity(0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              player.applyQueueSnapshot(s);
                              Navigator.pop(context);
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.queue_music_rounded,
                                    color: AppTheme.accentLight, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  s.name,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${s.trackIds.length}',
                                  style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              player.deleteQueueSnapshot(s.name);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Очередь «${s.name}» удалена'),
                                  duration: const Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: const Icon(Icons.close_rounded,
                                color: AppTheme.textMuted, size: 15),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(color: AppTheme.cardBorder),
          ],

          // Queue List
          if (queue.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'Очередь пуста',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: queue.length,
                itemBuilder: (context, index) {
                  final track = queue[index];
                  final isCurrent = index == currentIndex;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppTheme.accent.withOpacity(0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isCurrent
                          ? Border.all(
                              color: AppTheme.accent.withOpacity(0.5),
                              width: 1,
                            )
                          : null,
                    ),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppTheme.accent
                              : AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: isCurrent
                              ? AnimatedWaveform(
                                  isPlaying: player.isPlaying,
                                  barCount: 3,
                                  height: 16,
                                  width: 16,
                                  gradient: const LinearGradient(
                                    colors: [Colors.white, Colors.white],
                                  ),
                                )
                              : Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      title: Text(
                        track.title,
                        style: TextStyle(
                          color: isCurrent
                              ? AppTheme.accentLight
                              : AppTheme.textPrimary,
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.w500,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        track.artist,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        track.formattedDuration,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        player.playTrack(track);
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
