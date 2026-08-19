import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/ui_style.dart';
import 'cover_flow/cover_flow_home_screen.dart';
import 'simple/simple_home_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final style = context.watch<UiStyleController>().style;
    return switch (style) {
      PlayerUIStyle.simple => const SimpleHomeScreen(),
      PlayerUIStyle.coverFlow3D => const CoverFlowHomeScreen(),
    };
  }
}