import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import '../../library/library_tabs.dart';
import '../../now_playing/cinematic/cinematic_player_body.dart';
import '../../settings/settings_screen.dart';
import '../../../widgets/queue_sheet.dart';

/// Cinematic home: музыкальное пространство сверху, нижняя навигация,
/// компактная библиотека снизу.
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
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: CinematicPlayerBody(
                    key: ValueKey('home-${track?.id}'),
                  ),
                ),
              ),
              _BottomNav(
                current: _tabs.index.clamp(0, 3),
                accent: cinematicAccent(context, track?.id),
                onSelect: (i) {
                  if (_tabs.index != i) {
                    setState(() => _tabs.index = i);
                  }
                },
              ),
              Expanded(
                flex: 5,
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
                    child: LibraryTabs(
                      controller: _tabs,
                      showTabBar: false,
                    ),
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

/// Нижняя навигация-пилюля: 4 раздела библиотеки (п. "BOTTOM LIBRARY").
class _BottomNav extends StatelessWidget {
  final int current;
  final Color accent;
  final ValueChanged<int> onSelect;

  const _BottomNav({
    required this.current,
    required this.accent,
    required this.onSelect,
  });

  static const _icons = [
    Icons.music_note_rounded,
    Icons.queue_music_rounded,
    Icons.album_rounded,
    Icons.mic_external_on_rounded,
  ];
  static const _labels = ['Треки', 'Плейлисты', 'Альбомы', 'Исполнители'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xB30D0D12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CinematicTheme.border),
        ),
        child: Row(
          children: List.generate(4, (i) {
            final selected = current == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => onSelect(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? accent.withValues(alpha: accent.a * 0.28)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: accent.withValues(
                                alpha: accent.a * 0.25,
                              ),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _icons[i],
                        size: 20,
                        color: selected
                            ? CinematicTheme.text
                            : CinematicTheme.textDim,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? CinematicTheme.text
                              : CinematicTheme.textDim,
                          fontSize: 10.5,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
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
