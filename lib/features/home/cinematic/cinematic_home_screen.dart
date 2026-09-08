import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import '../../library/library_bottom_nav.dart';
import '../../library/library_tabs.dart';
import '../../mini_player/cinematic/cinematic_mini_player.dart';
import '../../now_playing/cinematic/cinematic_player_body.dart';
import '../../now_playing/now_playing_screen.dart';
import '../../settings/settings_screen.dart';
import '../../../widgets/queue_sheet.dart';

/// Cinematic home: библиотека отдельным экраном, внизу мини-плеер,
/// под ним пилюля-навигация. Плеер — отдельный full-экран.
class CinematicHomeScreen extends StatefulWidget {
  const CinematicHomeScreen({super.key});

  @override
  State<CinematicHomeScreen> createState() => _CinematicHomeScreenState();
}

class _CinematicHomeScreenState extends State<CinematicHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 9, vsync: this);
    _tabs.addListener(_onTab);
  }

  void _onTab() {
    if (!_tabs.indexIsChanging && mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTab);
    _tabs.dispose();
    super.dispose();
  }

  void _expand(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return Scaffold(
      backgroundColor: CinematicTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(hasQueue: player.playlist.isNotEmpty),
            Expanded(
              child: LibraryTabs(
                controller: _tabs,
                showTabBar: false,
              ),
            ),
            CinematicMiniPlayer(onExpand: () => _expand(context)),
            LibraryBottomNav(
              current: _tabs.index.clamp(0, 8),
              accent: cinematicAccent(context, player.currentTrack?.id),
              onSelect: (i) {
                if (_tabs.index != i) {
                  setState(() => _tabs.index = i);
                }
              },
            ),
          ],
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
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
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
