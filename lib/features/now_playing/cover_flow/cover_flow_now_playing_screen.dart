import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/player_provider.dart';
import '../../../ui/theme.dart';
import '../../../widgets/cached_artwork.dart';

class CoverFlowNowPlayingScreen extends StatelessWidget {
  const CoverFlowNowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final track = player.currentTrack;

    if (track == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(leading: const SizedBox.shrink()),
        body: const Center(
          child: Text(
            'Нет воспроизводимого трека',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textSecondary, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: Center(
                child: Hero(
                  tag: 'cover_flow_art',
                  child: CachedArtwork(
                    trackId: track.id,
                    width: 260,
                    height: 260,
                    radius: 24,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(
                    track.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    track.artist,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '3D Cover Flow — в разработке',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}