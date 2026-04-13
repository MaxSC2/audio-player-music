import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';
import '../models/audio_track.dart';

class PlayerBar extends StatelessWidget {
  final VoidCallback onTap;

  const PlayerBar({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        final track = player.currentTrack;
        if (track == null) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: onTap,
          child: Container(
            height: 64,
            decoration: const BoxDecoration(
              color: AppTheme.card,
              border: Border(
                top: BorderSide(color: Colors.white10, width: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.music_note,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.artist,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: player.togglePlayPause,
                    icon: Icon(
                      player.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: AppTheme.textPrimary,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class FullPlayer extends StatelessWidget {
  const FullPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        final track = player.currentTrack;
        if (track == null) {
          return const Center(
            child: Text('No track selected'),
          );
        }

        return Column(
          children: [
            const Spacer(),
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.accent.withOpacity(0.8),
                    AppTheme.accent.withOpacity(0.4),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.music_note,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              track.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              track.artist,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                return StreamBuilder<Duration?>(
                  stream: player.durationStream,
                  builder: (context, durationSnapshot) {
                    final duration = durationSnapshot.data ?? Duration.zero;
                    final progress = duration.inMilliseconds > 0
                        ? position.inMilliseconds / duration.inMilliseconds
                        : 0.0;

                    return Column(
                      children: [
                        Slider.adaptive(
                          value: progress.clamp(0.0, 1.0),
                          onChanged: (value) {
                            final newPosition = Duration(
                              milliseconds:
                                  (value * duration.inMilliseconds).round(),
                            );
                            player.seek(newPosition);
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AudioTrack.formatDuration(
                                    position.inMilliseconds),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                AudioTrack.formatDuration(
                                    duration.inMilliseconds),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: player.previous,
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 40,
                  color: AppTheme.textPrimary,
                ),
                const SizedBox(width: 16),
                StreamBuilder<bool>(
                  stream: player.audioPlayer.playingStream,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data ?? false;
                    return IconButton(
                      onPressed: player.togglePlayPause,
                      icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
                      iconSize: 64,
                      color: AppTheme.accent,
                    );
                  },
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: player.next,
                  icon: const Icon(Icons.skip_next),
                  iconSize: 40,
                  color: AppTheme.textPrimary,
                ),
              ],
            ),
            const Spacer(),
          ],
        );
      },
    );
  }
}
