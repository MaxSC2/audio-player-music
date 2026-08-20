import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/audio_track.dart';
import '../../providers/player_provider.dart';
import '../../ui/theme.dart';

class MusicDnaTab extends StatelessWidget {
  const MusicDnaTab({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    if (player.totalPlays == 0) {
      return _buildEmptyState();
    }

    final topArtists = player.topArtists(limit: 5);
    final topTracks = player.topTracks(limit: 5);
    final profile = player.listeningTimeProfile;
    final totalMs = player.totalListeningTime.inMilliseconds;
    final hours = (totalMs / 3600000).floor();
    final minutes = ((totalMs % 3600000) / 60000).floor();

    final profileMax = [
      profile.morning,
      profile.day,
      profile.evening,
    ].fold<int>(1, (a, b) => a > b ? a : b);

    Widget timeBar(String label, int value, Color color) {
      return Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 34,
            height: 60,
            alignment: Alignment.bottomCenter,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: FractionallySizedBox(
              heightFactor: value / profileMax,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // DNA header card
        Container(
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.accent.withOpacity(0.2),
                AppTheme.accentPink.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.fingerprint_rounded,
                      color: AppTheme.accentLight, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Твоя музыкальная ДНК',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  _stat('Прослушано', '$hours ч $minutes м',
                      Icons.timer_outlined, AppTheme.accentCyan),
                  SizedBox(width: 8),
                  _stat('Треков', '${player.totalPlays}',
                      Icons.play_arrow_rounded, AppTheme.accentGreen),
                  SizedBox(width: 8),
                  _stat('Уникальных', '${player.uniqueTracksListened}',
                      Icons.music_note_rounded, AppTheme.accentPink),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Когда ты слушаешь',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  timeBar('Утро', profile.morning, AppTheme.accentAmber),
                  timeBar('День', profile.day, AppTheme.accentCyan),
                  timeBar('Вечер', profile.evening, AppTheme.accentPink),
                ],
              ),
            ],
          ),
        ),

        // Time Machine
        Container(
          margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history_toggle_off_rounded,
                      color: AppTheme.accentLight, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Машина времени',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Вернись в любой день и послушай его снова',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _pickDay(context, player),
                  icon: Icon(Icons.calendar_month_rounded, size: 18),
                  label: const Text('Выбрать день'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (topArtists.isNotEmpty) ...[
          _sectionHeader('Топ исполнители'),
          ...topArtists.asMap().entries.map((e) {
            final rank = e.key + 1;
            final item = e.value;
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              title: Text(
                item.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '${item.plays} ${_plural(item.plays)}',
                style: TextStyle(
                    color: AppTheme.textMuted, fontSize: 12),
              ),
              trailing: Icon(Icons.play_circle_outline_rounded,
                  color: AppTheme.accentLight, size: 22),
              onTap: () {
                final tracks = player.visibleTracks
                    .where((t) => t.artist == item.artist)
                    .toList();
                if (tracks.isNotEmpty) {
                  player.playFromPlaylist(tracks, 0);
                }
              },
            );
          }),
        ],

        if (topTracks.isNotEmpty) ...[
          _sectionHeader('Топ треки'),
          ...topTracks.asMap().entries.map((e) {
            final rank = e.key + 1;
            final item = e.value;
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      color: AppTheme.accentLight,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              title: Text(
                item.track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '${item.track.artist} • ${item.plays} ${_plural(item.plays)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppTheme.textMuted, fontSize: 12),
              ),
              trailing: Icon(Icons.play_circle_outline_rounded,
                  color: AppTheme.accentLight, size: 22),
              onTap: () => player.playTrack(item.track),
            );
          }),
        ],
      ],
    );
  }

  String _plural(int n) {
    final m10 = n % 10;
    final m100 = n % 100;
    if (m100 >= 11 && m100 <= 19) return 'прослушиваний';
    if (m10 == 1) return 'прослушивание';
    if (m10 >= 2 && m10 <= 4) return 'прослушивания';
    return 'прослушиваний';
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      child: Text(
        title,
        style: TextStyle(
          color: AppTheme.accentLight,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style:
                  const TextStyle(color: AppTheme.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.fingerprint_rounded,
                color: AppTheme.textMuted, size: 48),
            SizedBox(height: 12),
            Text(
              'Здесь появится твоя музыкальная ДНК',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            SizedBox(height: 6),
            Text(
              'Слушай музыку, и приложение изучит твой вкус',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDay(BuildContext context, PlayerProvider player) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      helpText: 'День для путешествия',
      cancelText: 'Отмена',
      confirmText: 'Открыть',
    );
    if (picked == null) return;

    final dayTracks = player.tracksForDay(picked);
    if (!context.mounted) return;

    if (dayTracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('В этот день ты ничего не слушал'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final dateLabel = '${picked.day.toString().padLeft(2, '0')}.'
        '${picked.month.toString().padLeft(2, '0')}.${picked.year}';

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
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Твой день — $dateLabel',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${dayTracks.length} ${_plural(dayTracks.length)}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: dayTracks.length,
                itemBuilder: (ctx, index) {
                  final entry = dayTracks[index];
                  final t = entry.track;
                  final h = entry.time.hour.toString().padLeft(2, '0');
                  final m = entry.time.minute.toString().padLeft(2, '0');
                  return ListTile(
                    dense: true,
                    leading: Text(
                      '$h:$m',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    title: Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 14),
                    ),
                    subtitle: Text(
                      t.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 12),
                    ),
                    onTap: () => player.playTrack(t),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final list =
                        dayTracks.map((e) => e.track).toList();
                    player.playFromPlaylist(list, 0);
                    Navigator.of(ctx).pop();
                  },
                  icon: Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Прожить этот день снова',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}