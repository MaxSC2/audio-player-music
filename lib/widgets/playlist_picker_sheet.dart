import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/audio_track.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';

// ─── ФАЗА 2 (вариант A): выбор треков для нового плейлиста ─────────────
// Отдельный шит: поиск + «выбрать показанные/очистить» + счётчик.
part 'track_pick_sheet.dart';

class PlaylistPickerSheet extends StatelessWidget {
  final AudioTrack track;

  const PlaylistPickerSheet({super.key, required this.track});

  Future<void> _createPlaylist(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.cardBorder),
        ),
        title: Text(
          'Новый плейлист',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Название плейлиста',
            hintStyle: TextStyle(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Отмена',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(
              'Создать',
              style: TextStyle(
                color: AppTheme.accentLight,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) {
      controller.dispose();
      return;
    }
    if (!context.mounted) {
      controller.dispose();
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // ФАЗА 2 (вариант A): сначала выбираем треки (начальный уже отмечен),
    // затем создаём плейлист с именем и составом одним вызовом.
    final picked = await TrackPickSheet.show(context, initial: [track]);
    if (!context.mounted) {
      controller.dispose();
      return;
    }
    if (picked == null) {
      // Отмена выбора — возвращаемся в пикер, плейлист не создаём.
      controller.dispose();
      return;
    }

    final player = context.read<PlayerProvider>();
    final byId = <int, AudioTrack>{
      for (final t in player.visibleTracks) t.id: t,
      track.id: track,
    };
    final tracks = <AudioTrack>[
      for (final id in picked)
        if (byId[id] != null) byId[id]!,
    ];
        // createPlaylistWithTracks возвращает id — не завязываемся на
    // playlists.last; дедуп имён — B15, дедуп треков — внутри метода.
        final created =
        await player.createPlaylistWithTracks(name, tracks);
    controller.dispose();

    if (context.mounted) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            created == null
                ? 'Не удалось создать плейлист'
                : 'Плейлист «$name»: ${tracks.length}',
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// ФАЗА 2 (вариант A): создание плейлиста сразу с выбранными треками.
  /// Кнопка под списком пикеров (начальный трек не навязываем).
  Future<void> _createPlaylistWithTracks(BuildContext context) async {
    final controller = TextEditingController();
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppTheme.cardBorder),
          ),
          title: Text(
            'Новый плейлист',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Название плейлиста',
              hintStyle: TextStyle(color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Отмена',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(
                'Далее',
                style: TextStyle(
                  color: AppTheme.accentLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      if (name == null || name.isEmpty || !context.mounted) return;
      final picked = await TrackPickSheet.show(context);
      if (picked == null || !context.mounted) return;
      final player = context.read<PlayerProvider>();
      final byId = <int, AudioTrack>{
        for (final t in player.visibleTracks) t.id: t,
      };
      final tracks = <AudioTrack>[
        for (final id in picked)
          if (byId[id] != null) byId[id]!,
      ];
      final created = await player.createPlaylistWithTracks(name, tracks);
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created == null
                ? 'Не удалось создать плейлист'
                : 'Плейлист «$name»: ${tracks.length}',
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final playlists = player.playlists;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 40,
              height: 4,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.playlist_add_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Добавить «${track.title}» в плейлист',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Плейлистов пока нет',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    final contains = playlist.trackIds.contains(track.id);

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.queue_music_rounded,
                          color: AppTheme.accentCyan,
                        ),
                        title: Text(
                          playlist.name,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${playlist.trackIds.length} треков',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        trailing: contains
                            ? Icon(
                                Icons.check_rounded,
                                color: AppTheme.accentGreen,
                              )
                            : Icon(
                                Icons.add_rounded,
                                color: AppTheme.textSecondary,
                              ),
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          if (contains) {
                            navigator.pop(context);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Трек уже в этом плейлисте'),
                                duration: Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            await player.addToPlaylist(playlist.id, track);
                            navigator.pop();
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _createPlaylist(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Создать новый плейлист'),
            ),
            // ФАЗА 2 (вариант A): выбор треков для нового плейлиста —
            // имя спрашиваем здесь, треки отмечаем в TrackPickSheet.
            TextButton.icon(
              onPressed: () => _createPlaylistWithTracks(context),
              icon: Icon(
                Icons.checklist_rounded,
                color: AppTheme.accentLight,
                size: 18,
              ),
              label: Text(
                'Новый плейлист с выбором треков',
                style: TextStyle(color: AppTheme.accentLight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
