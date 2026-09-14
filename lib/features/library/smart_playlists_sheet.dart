import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/audio_track.dart';
import '../../providers/player_provider.dart';
import '../../ui/theme.dart';

/// Умные автоплейлисты (P1): готовые подборки на основе реального
/// прослушивания — без ручной сборки. Каждая карточка — очередь,
/// которую можно запустить целиком или открыть для просмотра.
class SmartPlaylistsSheet extends StatelessWidget {
  const SmartPlaylistsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const SmartPlaylistsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final media = MediaQuery.of(context);

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Умные плейлисты',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Подборки на основе ваших прослушиваний',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 24 + media.viewPadding.bottom,
              ),
              children: [
                _SmartCard(
                  icon: Icons.trending_up_rounded,
                  color: AppTheme.accentCyan,
                  title: 'Топ недели',
                  subtitle: 'Что вы слушали больше всего за 7 дней',
                  tracks: player.smartTopWeek(),
                  onPlay: (t) =>
                      _playSmart(context, player, player.smartTopWeek(), t),
                ),
                const SizedBox(height: 12),
                _SmartCard(
                  icon: Icons.new_releases_rounded,
                  color: AppTheme.accentGreen,
                  title: 'Свежее',
                  subtitle: 'Недавно добавленные, которые почти не слушали',
                  tracks: player.smartFresh(),
                  onPlay: (t) =>
                      _playSmart(context, player, player.smartFresh(), t),
                ),
                const SizedBox(height: 12),
                _SmartCard(
                  icon: Icons.skip_next_rounded,
                  color: AppTheme.accentAmber,
                  title: 'Часто пропускаемые',
                  subtitle: 'Треки, которые вы чаще всего переключали',
                  tracks: player.smartSkipped(),
                  onPlay: (t) =>
                      _playSmart(context, player, player.smartSkipped(), t),
                ),
                const SizedBox(height: 12),
                _SmartCard(
                  icon: Icons.explore_rounded,
                  color: AppTheme.accentPink,
                  title: 'Неизведанное',
                  subtitle: 'Треки, которые вы ни разу не слушали',
                  tracks: player.smartDeepCuts(),
                  onPlay: (t) =>
                      _playSmart(context, player, player.smartDeepCuts(), t),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _playSmart(BuildContext context, PlayerProvider player,
      List<AudioTrack> list, AudioTrack track) {
    if (list.isEmpty) return;
    final idx = list.indexWhere((t) => t.id == track.id);
    player.playFromPlaylist(list, idx >= 0 ? idx : 0);
    Navigator.of(context).pop();
  }
}

class _SmartCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<AudioTrack> tracks;
  final void Function(AudioTrack) onPlay;

  const _SmartCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.tracks,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: color.a * 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap:
                        tracks.isEmpty ? null : () => onPlay(tracks.first),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: tracks.isEmpty ? null : AppTheme.primaryGradient,
                        color: tracks.isEmpty ? AppTheme.surfaceLight : null,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color:
                            tracks.isEmpty ? AppTheme.textMuted : Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (tracks.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                'Пока пусто — послушайте что-нибудь, и подборка появится',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            )
          else
            ...tracks.take(3).map((t) => Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onPlay(t),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${t.artist} — ${t.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            t.formattedDuration,
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
          if (tracks.length > 3)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
              child: Text(
                'ещё ${tracks.length - 3}…',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}