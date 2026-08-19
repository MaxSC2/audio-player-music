import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/ui_style.dart';
import 'cover_flow/cover_flow_now_playing_screen.dart';
import 'simple/simple_now_playing_screen.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final style = context.watch<UiStyleController>().style;
    return switch (style) {
      PlayerUIStyle.simple => const SimpleNowPlayingScreen(),
      PlayerUIStyle.coverFlow3D => const CoverFlowNowPlayingScreen(),
    };
  }
}