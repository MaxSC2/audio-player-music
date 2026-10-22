import 'dart:async';

import 'package:audio_player/core/ui_style.dart';
import 'package:audio_player/features/boot/boot_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('splash занимает весь экран и центрирован', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final style = UiStyleController();
    final boot = Completer<void>();
    await tester.pumpWidget(
      ChangeNotifierProvider<UiStyleController>.value(
        value: style,
        child: MaterialApp(
          home: BootGate(
            bootFuture: boot.future,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();

    final screen = tester.getSize(find.byType(Scaffold));
    expect(screen.width, 360);
    expect(screen.height, 800);

    final logo = tester.getCenter(find.text('NEONWAVE'));
    expect(logo.dx, closeTo(180, 1));

    await tester.pumpWidget(const SizedBox());
    boot.complete();
  });
}
