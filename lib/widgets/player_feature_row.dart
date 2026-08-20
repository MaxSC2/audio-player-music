import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/audio_track.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';
import 'equalizer_dialog.dart';
import 'explain_sheet.dart';
import 'queue_sheet.dart';
import 'sleep_timer_dialog.dart';

/// Единый ряд функций плеера — доступен во всех интерфейсах (простой/3D),
/// чтобы не нужно было переключаться между ними.
class PlayerFeatureRow extends StatelessWidget {
  final AudioTrack track;

  const PlayerFeatureRow({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Favorite
          _AnimatedFavoriteButton(
            isFavorite: track.isFavorite,
            onTap: () => player.toggleFavorite(track),
          ),
          const SizedBox(width: 14),

          // Music Bookmarks
          GestureDetector(
            onLongPress: () => _showTrackBookmarks(context, player, track),
            child: _FeatureButton(
              icon: player.bookmarksFor(track.id).isEmpty
                  ? Icons.bookmark_add_outlined
                  : Icons.bookmark_rounded,
              color: player.bookmarksFor(track.id).isEmpty
                  ? AppTheme.textSecondary
                  : AppTheme.accentLight,
              onTap: () {
                final pos = player.position.inMilliseconds;
                player.toggleBookmark(track.id, pos);
                final has = player.bookmarksFor(track.id).contains(pos);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(has
                        ? 'Закладка: ${AudioTrack.formatDuration(pos)}'
                        : 'Закладка убрана'),
                    duration: const Duration(milliseconds: 900),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 14),

          // X-Boost
          _FeatureButton(
            icon: Icons.bolt_rounded,
            color: player.xBoost
                ? AppTheme.accentAmber
                : AppTheme.textSecondary,
            onTap: player.toggleXBoost,
          ),
          const SizedBox(width: 14),

          // Repeat A-B
          _FeatureButton(
            icon: Icons.compare_arrows_rounded,
            color: player.repeatABActive
                ? AppTheme.accentCyan
                : AppTheme.textSecondary,
            onTap: player.tapRepeatAB,
          ),
          const SizedBox(width: 14),

          // Speed
          _SpeedBadge(speed: player.speed, onTap: player.cycleSpeed),
          const SizedBox(width: 14),

          // Sleep Timer
          _FeatureButton(
            icon: player.sleepTimerMinutes > 0
                ? Icons.nightlight_round
                : Icons.nightlight_outlined,
            color: player.sleepTimerMinutes > 0
                ? AppTheme.accentAmber
                : AppTheme.textSecondary,
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => const SleepTimerDialog(),
              );
            },
          ),
          const SizedBox(width: 14),

          // Equalizer
          _FeatureButton(
            icon: Icons.graphic_eq_rounded,
            color: player.equalizerPreset != 'Flat (Стандарт)'
                ? AppTheme.accentGreen
                : AppTheme.textSecondary,
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => const EqualizerDialog(),
              );
            },
          ),
          const SizedBox(width: 14),

          // Explain Recommendation
          _FeatureButton(
            icon: Icons.psychology_outlined,
            color: AppTheme.accentLight,
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: AppTheme.surface,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => ExplainSheet(track: track),
              );
            },
          ),
          const SizedBox(width: 14),

          // Queue
          _FeatureButton(
            icon: Icons.queue_music_rounded,
            color: AppTheme.textSecondary,
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: AppTheme.surface,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => const QueueSheet(),
              );
            },
          ),
          const SizedBox(width: 14),

          // Delete Track
          _FeatureButton(
            icon: Icons.delete_outline_rounded,
            color: AppTheme.textSecondary,
            onTap: () => _confirmDeleteTrack(context, player, track),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDeleteTrack(
    BuildContext context, PlayerProvider player, AudioTrack track) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text('Удалить трек?',
          style: TextStyle(color: AppTheme.textPrimary)),
      content: Text(
        'Файл «${track.title}» будет удалён с устройства. Это действие нельзя отменить.',
        style: TextStyle(color: AppTheme.textMuted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Удалить', style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final ok = await player.deleteTrack(track);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(ok ? 'Трек удалён' : 'Не удалось удалить трек')),
  );
  if (ok && player.currentTrack == null) {
    Navigator.pop(context);
  }
}

void _showTrackBookmarks(
    BuildContext context, PlayerProvider player, AudioTrack track) {
  final bookmarks = player.bookmarksFor(track.id);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 14),
            decoration: BoxDecoration(
              color: AppTheme.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Закладки — ${track.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (bookmarks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Нет закладок. Нажмите на иконку закладки во время трека.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: bookmarks.length,
                itemBuilder: (ctx, index) {
                  final ms = bookmarks[index];
                  return ListTile(
                    leading: Icon(Icons.bookmark_rounded,
                        color: AppTheme.accentLight, size: 20),
                    title: Text(
                      AudioTrack.formatDuration(ms),
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: AppTheme.textMuted, size: 20),
                      onPressed: () {
                        player.removeBookmark(track.id, ms);
                      },
                      tooltip: 'Удалить закладку',
                    ),
                    onTap: () {
                      player.playTrack(track);
                      player.seek(Duration(milliseconds: ms));
                      Navigator.of(ctx).pop();
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

class _FeatureButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FeatureButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _AnimatedFavoriteButton extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onTap;

  const _AnimatedFavoriteButton({
    required this.isFavorite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(isFavorite),
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: _FeatureButton(
        icon: isFavorite
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        color: isFavorite ? AppTheme.accentPink : AppTheme.textSecondary,
        onTap: onTap,
      ),
    );
  }
}

class _SpeedBadge extends StatelessWidget {
  final double speed;
  final VoidCallback onTap;

  const _SpeedBadge({required this.speed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCustom = speed != 1.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isCustom
              ? AppTheme.accentCyan.withOpacity(0.15)
              : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCustom ? AppTheme.accentCyan : AppTheme.cardBorder,
          ),
        ),
        child: Text(
          '${speed.toStringAsFixed(2)}x'.replaceFirst('.00', 'x'),
          style: TextStyle(
            color: isCustom ? AppTheme.accentCyan : AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}