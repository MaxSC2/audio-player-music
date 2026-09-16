import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/audio_track.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';

/// Список закладок конкретного трека.
/// Используется в меню действий трека и в ряду функций плеера — чтобы не
/// дублировать UI и держать один источник правды для отображения bookmarks.
class TrackBookmarksSheet extends StatelessWidget {
  final AudioTrack track;

  const TrackBookmarksSheet({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final bookmarks = player.bookmarksFor(track.id);

    return SafeArea(
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
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                ),
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
                    leading: Icon(
                      Icons.bookmark_rounded,
                      color: AppTheme.accentLight,
                      size: 20,
                    ),
                    title: Text(
                      AudioTrack.formatDuration(ms),
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
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
    );
  }
}

/// Удобный «показать как bottom sheet».
Future<void> showTrackBookmarks(BuildContext context, AudioTrack track) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => TrackBookmarksSheet(track: track),
  );
}