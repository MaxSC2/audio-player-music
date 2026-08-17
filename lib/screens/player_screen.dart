import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';
import '../widgets/animated_waveform.dart';
import '../widgets/equalizer_dialog.dart';
import '../widgets/marquee_text.dart';
import '../widgets/queue_sheet.dart';
import '../widgets/sleep_timer_dialog.dart';
import '../widgets/spinning_vinyl.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
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
            'Выберите трек для воспроизведения',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    final progress = player.duration.inMilliseconds > 0
        ? (player.position.inMilliseconds / player.duration.inMilliseconds)
            .clamp(0.0, 1.0)
            .toDouble()
        : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Background Glow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.8),
                  radius: 1.2,
                  colors: [
                    AppTheme.accent.withOpacity(0.18),
                    AppTheme.background,
                    AppTheme.background,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.textSecondary, size: 30),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'СЕЙЧАС ИГРАЕТ',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _repeatLabel(player.repeatMode),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded,
                          color: AppTheme.textSecondary),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: AppTheme.surface,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (_) => const QueueSheet(),
                        );
                      },
                    ),
                  ],
                ),

                // Spinning Vinyl / Artwork
                Expanded(
                  flex: 5,
                  child: Center(
                    child: SpinningVinyl(
                      trackId: track.id,
                      isPlaying: player.isPlaying,
                      size: 250,
                    ),
                  ),
                ),

                // Track Info (marquee)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      MarqueeText(
                        text: track.title,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      MarqueeText(
                        text: '${track.artist}${track.album != null ? ' — ${track.album}' : ''}',
                        velocity: 18,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Live Waveform
                      AnimatedWaveform(
                        isPlaying: player.isPlaying,
                        barCount: 24,
                        height: 28,
                        width: double.infinity,
                      ),
                    ],
                  ),
                ),

                // Progress Slider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    children: [
                      Slider(
                        value: progress,
                        onChanged: (value) {
                          final target = Duration(
                            milliseconds:
                                (value * player.duration.inMilliseconds).round(),
                          );
                          player.seek(target);
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatPosition(player.position),
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            Text(
                              _formatPosition(player.duration),
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ControlButton(
                        icon: player.shuffleMode
                            ? Icons.shuffle_on_rounded
                            : Icons.shuffle_rounded,
                        color: player.shuffleMode
                            ? AppTheme.accentCyan
                            : AppTheme.textMuted,
                        onTap: player.toggleShuffle,
                      ),
                      _ControlButton(
                        icon: Icons.skip_previous_rounded,
                        size: 34,
                        onTap: player.previous,
                      ),
                      _PlayPauseButton(
                        isPlaying: player.isPlaying,
                        onTap: player.togglePlay,
                      ),
                      _ControlButton(
                        icon: Icons.skip_next_rounded,
                        size: 34,
                        onTap: player.next,
                      ),
                      _ControlButton(
                        icon: _repeatIcon(player.repeatMode),
                        color: _repeatColor(player.repeatMode),
                        onTap: player.toggleRepeat,
                      ),
                    ],
                  ),
                ),

                // Feature Actions Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Favorite
                      _FeatureButton(
                        icon: track.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: track.isFavorite
                            ? AppTheme.accentPink
                            : AppTheme.textSecondary,
                        onTap: () => player.toggleFavorite(track),
                      ),

                      // Speed
                      _SpeedBadge(
                        speed: player.speed,
                        onTap: player.cycleSpeed,
                      ),

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

                      // Equalizer Presets
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
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24)),
                            ),
                            builder: (_) => const QueueSheet(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _repeatLabel(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.off:
        return 'Повтор выключен';
      case RepeatMode.all:
        return 'Повтор всех';
      case RepeatMode.one:
        return 'Повтор одного';
    }
  }

  IconData _repeatIcon(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.off:
        return Icons.repeat_rounded;
      case RepeatMode.all:
        return Icons.repeat_rounded;
      case RepeatMode.one:
        return Icons.repeat_one_rounded;
    }
  }

  Color _repeatColor(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.off:
        return AppTheme.textMuted;
      case RepeatMode.all:
        return AppTheme.accent;
      case RepeatMode.one:
        return AppTheme.accentPink;
    }
  }

  String _formatPosition(Duration d) {
    final total = d.inSeconds;
    final m = (total ~/ 60).toString();
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    this.color,
    this.size = 26,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color ?? AppTheme.textPrimary, size: size),
      onPressed: onTap,
      splashRadius: 24,
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayPauseButton({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppTheme.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: isPlaying
                  ? AppTheme.accent.withOpacity(0.5)
                  : AppTheme.accentCyan.withOpacity(0.4),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }
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