import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import '../../collection/neon_collection_screen.dart';
import '../../library/library_bottom_nav.dart';
import '../../library/library_tabs.dart';
import '../../mini_player/cinematic/cinematic_mini_player.dart';
import '../../now_playing/cinematic/cinematic_player_body.dart';
import '../../now_playing/now_playing_screen.dart';
import '../../settings/settings_screen.dart';
import '../../../core/debug_log.dart';

String _pluralTracks(int n) {
  final m10 = n % 10;
  final m100 = n % 100;
  if (m10 == 1 && m100 != 11) return 'трек';
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'трека';
  return 'треков';
}

/// Neon home: библиотека отдельным экраном, внизу мини-плеер,
/// под ним пилюля-навигация. Порядок как в референсе 02.
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
      MaterialPageRoute(
        settings: const RouteSettings(name: 'NowPlaying'),
        builder: (_) => const NowPlayingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    DebugLog.rebuild('NeonHome');
    // Изоляция от шторма: экран читает из провайдера только 2 значения
    // (количество треков и id текущего). Любые прочие нотификации
    // (позиция/состояние плеера/история) больше не перестраивают
    // домашний экран и вложенную библиотеку с 9 вкладками.
    final count = context.select<PlayerProvider, int>(
      (p) => p.visibleTracks.length,
    );
    final currentTrackId = context.select<PlayerProvider, int?>(
      (p) => p.currentTrack?.id,
    );

    return Scaffold(
      backgroundColor: CinematicTheme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        const LinearGradient(
                          colors: [
                            Color(0xFFA855F7),
                            Color(0xFF38BDF8),
                          ],
                        ).createShader(
                          Rect.fromLTWH(
                            0,
                            0,
                            bounds.width,
                            bounds.height,
                          ),
                        ),
                    child: const Text(
                      'NEONWAVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          settings:
                              const RouteSettings(name: 'Collection'),
                          builder: (_) => const NeonCollectionScreen(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.grid_view_rounded,
                      color: CinematicTheme.textSoft,
                      size: 22,
                    ),
                    tooltip: 'Коллекция',
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          settings:
                              const RouteSettings(name: 'Settings'),
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
            CinematicMiniPlayer(onExpand: () => _expand(context)),
            LibraryBottomNav(
              current: _tabs.index.clamp(0, 8),
              accent: cinematicAccent(context, currentTrackId),
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
