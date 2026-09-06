import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import '../../library/library_tabs.dart';
import '../../now_playing/cinematic/cinematic_player_body.dart';
import '../../settings/settings_screen.dart';
import '../../../widgets/queue_sheet.dart';

/// Cinematic home: музыкальное пространство сверху, библиотека снизу.
class CinematicHomeScreen extends StatelessWidget {
  const CinematicHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final track = player.currentTrack;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: CinematicTheme.bg,
      body: CinematicAmbient(
        trackId: track?.id,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopBar(hasQueue: player.playlist.isNotEmpty),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: CinematicPlayerBody(
                    key: ValueKey('home-${track?.id}'),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xCC050507),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border(
                      top: BorderSide(color: CinematicTheme.border),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottom > 0 ? 0 : 8),
                    child: const LibraryTabs(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Минималистичный top bar (п.11): логотип + LOCAL слева, иконки справа.
class _TopBar extends StatelessWidget {
  final bool hasQueue;

  const _TopBar({required this.hasQueue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 2),
      child: Row(
        children: [
          const Text(
            'NEONWAVE',
            style: TextStyle(
              color: CinematicTheme.text,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 3.0,
            ),
          ),
          if (hasQueue) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CinematicTheme.border),
              ),
              child: const Text(
                'LOCAL',
                style: TextStyle(
                  color: CinematicTheme.textDim,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF101014),
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const QueueSheet(),
              );
            },
            icon: const Icon(
              Icons.queue_music_rounded,
              color: CinematicTheme.textSoft,
              size: 22,
            ),
            tooltip: 'Очередь',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(
              Icons.settings_outlined,
              color: CinematicTheme.textSoft,
              size: 22,
            ),
            tooltip: 'Настройки',
          ),
        ],
      ),
    );
  }
}
