import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/ui_style.dart';
import 'cover_flow/cover_flow_mini_player.dart';
import 'simple/simple_mini_player.dart';

class MiniPlayer extends StatelessWidget {
  final VoidCallback onExpand;

  const MiniPlayer({super.key, required this.onExpand});

  @override
  Widget build(BuildContext context) {
    final uiStyle = context.watch<UiStyleController>();
    final style = uiStyle.style;
    return GestureDetector(
      onLongPress: uiStyle.toggle,
      child: switch (style) {
        PlayerUIStyle.simple => SimpleMiniPlayer(onExpand: onExpand),
        PlayerUIStyle.coverFlow3D => CoverFlowMiniPlayer(onExpand: onExpand),
      },
    );
  }
}