import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import '../../../ui/theme.dart';
import '../../library/library_bottom_nav.dart';
import '../../library/library_tabs.dart';
import '../../library/personal_dj_sheet.dart';
import '../../mini_player/mini_player.dart';
import '../../now_playing/card_wave/card_wave_theme.dart';
import '../../now_playing/now_playing_screen.dart';
import '../../settings/settings_screen.dart';

/// Cardwave home: library presented as the player's card table.
class CardWaveHomeScreen extends StatefulWidget {
  const CardWaveHomeScreen({super.key});

  @override
  State<CardWaveHomeScreen> createState() => _CardWaveHomeScreenState();
}

class _CardWaveHomeScreenState extends State<CardWaveHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const double _overlayInset = 170;
  static const double _overlayInsetNoMini = 92;

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

  void _openPlayer(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: 'NowPlaying'),
        pageBuilder: (_, __, ___) => const NowPlayingScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 260),
      ),
    );
  }

  Widget _bottomOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x0009090D),
            Color(0xE609090D),
            cardWaveBg,
          ],
          stops: [0.0, 0.62, 1.0],
        ),
      ),
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniPlayer(onExpand: () => _openPlayer(context)),
          LibraryBottomNav(
            current: _tabs.index.clamp(0, 8),
            accent: cardWaveGold,
            onSelect: (index) {
              if (_tabs.index != index) {
                setState(() => _tabs.index = index);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.select<PlayerProvider, ({int count, int? trackId})>(
      (p) => (
        count: p.allTracks.length,
        trackId: p.currentTrack?.id,
      ),
    );
    final hasMini = player.trackId != null;

    return Scaffold(
      backgroundColor: cardWaveBg,
      appBar: AppBar(
        backgroundColor: cardWaveBg,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CARDWAVE',
              style: TextStyle(
                color: cardWaveCream,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.8,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'YOUR MUSIC DECK',
              style: TextStyle(
                color: cardWaveMuted,
                fontSize: 9,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Personal DJ',
            icon: const Icon(Icons.auto_awesome_rounded),
            color: cardWaveGold,
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              backgroundColor: AppTheme.surface,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => const PersonalDJSheet(),
            ),
          ),
          IconButton(
            tooltip: 'Настройки',
            icon: const Icon(Icons.tune_rounded),
            color: cardWaveGold,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: 'Settings'),
                builder: (_) => const SettingsScreen(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
              child: Row(
                children: [
                  const Icon(Icons.style_rounded, color: cardWaveGold, size: 17),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'THE COLLECTION',
                      style: TextStyle(
                        color: cardWaveGold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
                  Text(
                    '${player.count} TRACKS',
                    style: const TextStyle(
                      color: Color(0xFF8E887C),
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardWaveSurface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: cardWaveBorder, width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(21),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: LibraryTabs(
                            controller: _tabs,
                            showTabBar: false,
                            bottomInset: hasMini
                                ? _overlayInset
                                : _overlayInsetNoMini,
                          ),
                        ),
                        const Positioned(
                          top: 8,
                          left: 8,
                          child: _DeckCorner(top: true, left: true),
                        ),
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: _DeckCorner(top: true, left: false),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _bottomOverlay(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckCorner extends StatelessWidget {
  final bool top;
  final bool left;

  const _DeckCorner({required this.top, required this.left});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: (top == left) ? 0 : 1.5708,
        child: const Icon(
          Icons.spa_outlined,
          size: 14,
          color: cardWaveGold,
        ),
      ),
    );
  }
}
