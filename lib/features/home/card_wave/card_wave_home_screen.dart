import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import '../../../ui/theme.dart';
import '../../library/library_tabs.dart';
import '../../library/personal_dj_sheet.dart';
import '../../mini_player/mini_player.dart';
import '../../now_playing/now_playing_screen.dart';
import '../../settings/settings_screen.dart';

/// Cardwave home: library presented as the player's card table.
class CardWaveHomeScreen extends StatelessWidget {
  const CardWaveHomeScreen({super.key});

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
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 260),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = context.select<PlayerProvider, int>((p) => p.allTracks.length);

    return Scaffold(
      backgroundColor: const Color(0xFF09090D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090D),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CARDWAVE',
              style: TextStyle(
                color: Color(0xFFF0E7D2),
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.8,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'YOUR MUSIC DECK',
              style: TextStyle(
                color: Color(0xFF9B927F),
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
            color: const Color(0xFFC9B47C),
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
            color: const Color(0xFFC9B47C),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: 'Settings'),
                builder: (_) => const SettingsScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
            child: Row(
              children: [
                const Icon(Icons.style_rounded,
                    color: Color(0xFFC9B47C), size: 17),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'THE COLLECTION',
                    style: TextStyle(
                      color: Color(0xFFC9B47C),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
                Text(
                  '$count TRACKS',
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
          const Expanded(child: LibraryTabs()),
          SafeArea(
            top: false,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF09090D), Color(0xFF111016)],
                ),
                border: Border(top: BorderSide(color: Color(0x24C9B47C))),
              ),
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: MiniPlayer(onExpand: () => _openPlayer(context)),
            ),
          ),
        ],
      ),
    );
  }
}