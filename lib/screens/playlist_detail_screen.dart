import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/custom_playlist.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';
import '../widgets/track_tile.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final index = player.playlists.indexWhere((p) => p.id == playlistId);

    if (index < 0) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Плейлист')),
        body: const Center(
          child: Text(
            'Плейлист не найден',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    final playlist = player.playlists[index];
    final tracks = player.tracksOfPlaylist(playlist);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          playlist.name,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppTheme.textSecondary),
            color: AppTheme.surfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppTheme.cardBorder),
            ),
            onSelected: (value) async {
              if (value == 'rename') {
                await _renamePlaylist(context, player, playlist);
              } else if (value == 'delete') {
                final ok = await _confirmDelete(context);
                if (ok == true && context.mounted) {
                  player.deletePlaylist(playlist.id);
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, color: AppTheme.accentCyan, size: 18),
                    SizedBox(width: 10),
                    Text('Переименовать'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded, color: AppTheme.accentPink, size: 18),
                    SizedBox(width: 10),
                    Text('Удалить плейлист'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Header
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.cardGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.pinkPurpleGradient,
                  ),
                  child: const Icon(Icons.queue_music_rounded,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: 12),
                Text(
                  playlist.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '${tracks.length} ${_plural(tracks.length)}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                if (tracks.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        player.playFromPlaylist(tracks, 0);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text(
                        'Слушать плейлист',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Tracks
          Expanded(
            child: tracks.isEmpty
                ? const Center(
                    child: Text(
                      'В плейлисте пока нет треков.\nДобавьте их через меню трека',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: tracks.length,
                    itemBuilder: (context, trackIndex) {
                      final track = tracks[trackIndex];
                      final isCurrent = player.currentTrack?.id == track.id;

                      return TrackTile(
                        track: track,
                        isPlaying: isCurrent && player.isPlaying,
                        isCurrent: isCurrent,
                        onTap: () {
                          player.playFromPlaylist(tracks, trackIndex);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _renamePlaylist(
      BuildContext context, PlayerProvider player, CustomPlaylist playlist) async {
    final controller = TextEditingController(text: playlist.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.cardBorder),
        ),
        title: const Text(
          'Переименовать плейлист',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
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
            child: const Text('Отмена',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Сохранить',
                style: TextStyle(
                    color: AppTheme.accentLight, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && context.mounted) {
      player.renamePlaylist(playlist.id, name);
    }
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.cardBorder),
        ),
        title: const Text(
          'Удалить плейлист?',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Треки в библиотеке останутся, удалится только плейлист.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: AppTheme.accentPink),
            ),
          ),
        ],
      ),
    );
  }

  String _plural(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return 'трек';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'трека';
    }
    return 'треков';
  }
}