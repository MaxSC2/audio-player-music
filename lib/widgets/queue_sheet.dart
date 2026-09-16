import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/audio_track.dart';
import '../models/queue_snapshot.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';
import 'animated_waveform.dart';
import 'numpad_sheet.dart';
import '../core/debug_log.dart';

class QueueSheet extends StatelessWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    DebugLog.rebuild('QueueSheet');
    // M6 (частично): вместо context.watch — точечные подписки через
    // context.select. Лист перестраивается только при смене очереди или
    // активного трека, а не на каждый тик позиции/буферизации.
    final queue = context.select<PlayerProvider, List<AudioTrack>>(
      (p) => p.playlist,
    );
    final currentIndex = context.select<PlayerProvider, int>(
      (p) => p.currentIndex,
    );
    // Действия и редкие списки: читаем провайдер без подписки на rebuild
    // (read не создаает зависимости — для снапшотов ниже отдельный select).
    final player = context.read<PlayerProvider>();
    final snapshots = context.select<PlayerProvider, List<QueueSnapshot>>(
      (p) => p.queueSnapshots,
    );
    final playingVisuals = context.select<PlayerProvider, bool>(
      (p) => p.playingVisuals,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    child: const Icon(
                      Icons.queue_music_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Очередь воспроизведения (${queue.length})',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.pin_rounded, color: AppTheme.textSecondary),
                onPressed: () {
                  if (queue.isEmpty) return;
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppTheme.surface,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    builder: (_) => const NumpadSheet(),
                  );
                },
                tooltip: 'Перейти к треку по номеру',
              ),
              IconButton(
                icon: Icon(
                  Icons.bookmark_add_outlined,
                  color: AppTheme.textSecondary,
                ),
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
                icon: Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Divider(color: AppTheme.cardBorder),

          // Saved queue snapshots
          if (snapshots.isNotEmpty) ...[
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
                children: snapshots.map((QueueSnapshot s) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(
                          alpha: AppTheme.accent.a * (0.14),
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.accent.withValues(
                            alpha: AppTheme.accent.a * (0.35),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              player.applyQueueSnapshot(s);
                              Navigator.pop(context);
                            },
                            // B15: долгое нажатие — переименовать снапшот
                            onLongPress: () {
                              final ctrl =
                                  TextEditingController(text: s.name);
                              showDialog<void>(
                                context: context,
                                builder: (dctx) => AlertDialog(
                                  backgroundColor: AppTheme.surface,
                                  title: const Text('Переименовать очередь'),
                                  content: TextField(
                                    controller: ctrl,
                                    autofocus: true,
                                    maxLength: 40,
                                    decoration: const InputDecoration(
                                      hintText: 'Название',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dctx),
                                      child: const Text('Отмена'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        final nn = ctrl.text.trim();
                                        if (nn.isNotEmpty &&
                                            nn != s.name) {
                                          player.renameQueueSnapshot(
                                              s.name, nn);
                                        }
                                        ctrl.dispose();
                                        Navigator.pop(dctx);
                                      },
                                      child: const Text('Сохранить'),
                                    ),
                                  ],
                                ),
                              ).then((_) => ctrl.dispose());
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.queue_music_rounded,
                                  color: AppTheme.accentLight,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  s.name,
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${s.trackIds.length}',
                                  style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 11,
                                  ),
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
                                  content: Text('Очередь «${s.name}» удалена'),
                                  duration: const Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: Icon(
                              Icons.close_rounded,
                              color: AppTheme.textMuted,
                              size: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Divider(color: AppTheme.cardBorder),
          ],

          // Queue List
          if (queue.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
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
                          ? AppTheme.accent.withValues(
                              alpha: AppTheme.accent.a * (0.16),
                            )
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isCurrent
                          ? Border.all(
                              color: AppTheme.accent.withValues(
                                alpha: AppTheme.accent.a * (0.5),
                              ),
                              width: 1,
                            )
                          : null,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
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
                                  isPlaying: playingVisuals,
                                  barCount: 3,
                                  height: 16,
                                  width: 16,
                                  gradient: const LinearGradient(
                                    colors: [Colors.white, Colors.white],
                                  ),
                                )
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
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
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        track.artist,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        track.formattedDuration,
                        style: TextStyle(
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
