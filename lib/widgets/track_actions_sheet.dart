import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/audio_track.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';
import 'neon_snack.dart';
import 'playlist_picker_sheet.dart';
import 'queue_sheet.dart';
import 'track_info_dialog.dart';

/// Единое меню «три точки» для всех плееров (простой / кинематографичный /
/// neon / cover-flow).
///
/// Раньше кнопка «три точки» в разных интерфейсах открывала разные шторки
/// (в простом — очередь, в кинематографичном — ряд кнопок) с разным стилем
/// и неполной логикой. Теперь это одна и та же шторка NeonWave со всеми
/// действиями над треком.
class TrackActionsSheet extends StatelessWidget {
  final AudioTrack track;

  const TrackActionsSheet({super.key, required this.track});

  static Future<void> show(BuildContext context, AudioTrack track) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: Colors.black.a * 0.5),
      builder: (_) => TrackActionsSheet(track: track),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final isFav = player.isFavorite(track.id);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHandle(),
            _buildHeader(),
            const SizedBox(height: 18),
            _buildActions(context, player, isFav),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardBorder,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(
    BuildContext context,
    PlayerProvider player,
    bool isFav,
  ) {
    // Мессенджер берём ДО закрытия шторки: после Navigator.pop контекст
    // шторки становится недействительным, и снекбар не показался бы.
    final messenger = ScaffoldMessenger.of(context);
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: [
        _ActionTile(
          icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: isFav ? 'В избранном' : 'В избранное',
          accent: AppTheme.accentPink,
          active: isFav,
          onTap: () => player.toggleFavorite(track),
        ),
        _ActionTile(
          icon: Icons.playlist_play_rounded,
          label: 'Играть след.',
          accent: AppTheme.accentCyan,
          onTap: () async {
            Navigator.pop(context);
            await player.addToQueueNext(track);
            showNeonSnackOn(
              messenger,
              '«${track.title}» — следующим',
              icon: Icons.playlist_play_rounded,
              accent: AppTheme.accentCyan,
            );
          },
        ),
        _ActionTile(
          icon: Icons.playlist_add_rounded,
          label: 'В плейлист',
          accent: AppTheme.accentGreen,
          onTap: () {
            Navigator.pop(context);
            showModalBottomSheet<void>(
              context: context,
              backgroundColor: AppTheme.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => PlaylistPickerSheet(track: track),
            );
          },
        ),
        _ActionTile(
          icon: Icons.queue_music_rounded,
          label: 'Очередь',
          accent: AppTheme.accent,
          onTap: () {
            Navigator.pop(context);
            showModalBottomSheet<void>(
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
        _ActionTile(
          icon: Icons.info_outline_rounded,
          label: 'Информация',
          accent: AppTheme.accentLight,
          onTap: () {
            Navigator.pop(context);
            showDialog<void>(
              context: context,
              builder: (_) => TrackInfoDialog(track: track),
            );
          },
        ),
        _ActionTile(
          icon: Icons.delete_outline_rounded,
          label: 'Удалить',
          accent: const Color(0xFFEF4444),
          onTap: () => _confirmDelete(context, player),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PlayerProvider player,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.cardBorder),
        ),
        title: Text(
          'Удалить трек?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Файл «${track.title}» будет удалён с устройства. '
          'Это действие нельзя отменить.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Отмена',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await player.deleteTrack(track);
    if (!context.mounted) return;
    showDeleteResultSnack(context, ok, title: track.title);
    if (context.mounted) Navigator.pop(context);
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final bool active;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: accent.a * 0.14)
              : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? accent.withValues(alpha: accent.a * 0.6)
                : AppTheme.cardBorder,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: accent, size: 24),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? accent : AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
