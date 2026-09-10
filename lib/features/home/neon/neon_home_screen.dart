import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import '../../collection/neon_collection_screen.dart';
import '../../library/library_bottom_nav.dart';
import '../../library/library_tabs.dart';
import '../../library/personal_dj_sheet.dart';
import '../../../ui/theme.dart';
import '../../mini_player/cinematic/cinematic_mini_player.dart';
import '../../now_playing/cinematic/cinematic_player_body.dart';
import '../../now_playing/now_playing_screen.dart';
import '../../settings/settings_screen.dart';
import '../../../core/debug_log.dart';

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

  /// Высота плавающего мини-плеера + нижней навигации (для отступа списка).
  static const double _overlayInset = 156;
  /// То же без мини-плеера (трека нет) — только нижняя навигация.
  static const double _overlayInsetNoMini = 88;

  Widget _buildBottomOverlay(int? currentTrackId) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            CinematicTheme.bg.withValues(alpha: 0.0),
            CinematicTheme.bg.withValues(alpha: 0.92),
            CinematicTheme.bg,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
    );
  }

  @override
  Widget build(BuildContext context) {
    DebugLog.rebuild('NeonHome');
    // Изоляция от шторма: экран читает из провайдера только id текущего
    // трека. Любые прочие нотификации (позиция/состояние/история) больше
    // не перестраивают домашний экран и вложенную библиотеку с 9 вкладками.
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
                  // Стеклянная группа иконок — в едином неоновом стиле
                  // с нижней навигацией (жалоба: «верх смотрится не очень»).
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: const Color(0x14FFFFFF),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0x1FFFFFFF)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TopIcon(
                          icon: Icons.auto_awesome_rounded,
                          tooltip: 'Personal DJ',
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: AppTheme.surface,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24),
                                ),
                              ),
                              builder: (_) => const PersonalDJSheet(),
                            );
                          },
                        ),
                        _TopIcon(
                          icon: Icons.grid_view_rounded,
                          tooltip: 'Коллекция',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                settings:
                                    const RouteSettings(name: 'Collection'),
                                builder: (_) => const NeonCollectionScreen(),
                              ),
                            );
                          },
                        ),
                        _TopIcon(
                          icon: Icons.settings_outlined,
                          tooltip: 'Настройки',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                settings:
                                    const RouteSettings(name: 'Settings'),
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: LibraryTabs(
                      controller: _tabs,
                      showTabBar: false,
                      neon: true,
                      bottomInset: currentTrackId != null
                          ? _overlayInset
                          : _overlayInsetNoMini,
                    ),
                  ),
                  // Плавающий оверлей: мини-плеер + навигация ПОВЕРХ списка.
                  // Раньше они стояли под списком в Column — за ними была
                  // чёрная полоса. Теперь список уходит под них и плавно
                  // затухает градиентом: «вшитости» и чёрного фона нет.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildBottomOverlay(currentTrackId),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Компактная иконка верхней панели (в «стеклянной» группе).
class _TopIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TopIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: CinematicTheme.textSoft, size: 21),
        ),
      ),
    );
  }
}
