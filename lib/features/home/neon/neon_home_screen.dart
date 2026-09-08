import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import '../../library/library_bottom_nav.dart';
import '../../library/library_tabs.dart';
import '../../mini_player/cinematic/cinematic_mini_player.dart';
import '../../now_playing/cinematic/cinematic_player_body.dart';
import '../../now_playing/now_playing_screen.dart';
import '../../settings/settings_screen.dart';

String _pluralTracks(int n) {
  final m10 = n % 10;
  final m100 = n % 100;
  if (m10 == 1 && m100 != 11) return 'трек';
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'трека';
  return 'треков';
}

/// Neon home: библиотека отдельным экраном + пилюля-навигация +
/// persistent мини-плеер. Плеер — на отдельном full-экране.
class NeonHomeScreen extends StatefulWidget {
  const NeonHomeScreen({super.key});

  @override
  State<NeonHomeScreen> createState() => _NeonHomeScreenState();
}

class _NeonHomeScreenState extends State<NeonHomeScreen>
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
    final count = player.visibleTracks.length;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: CinematicTheme.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
              child: Row(
                children: [
                  const Text(
                    'NEONWAVE',
                    style: TextStyle(
                      color: CinematicTheme.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '$count ${_pluralTracks(count)}',
                style: const TextStyle(
                  color: CinematicTheme.textDim,
                  fontSize: 12.5,
                ),
              ),
            ),
            Expanded(
              child: LibraryTabs(
                controller: _tabs,
                showTabBar: false,
              ),
            ),
            LibraryBottomNav(
              current: _tabs.index.clamp(0, 8),
              accent: cinematicAccent(context, player.currentTrack?.id),
              onSelect: (i) {
                if (_tabs.index != i) {
                  setState(() => _tabs.index = i);
                }
              },
            ),
            Padding(
              padding: EdgeInsets.only(bottom: bottom > 0 ? 4 : 10),
              child: CinematicMiniPlayer(
                onExpand: () => _expand(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
