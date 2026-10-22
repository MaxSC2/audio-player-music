import 'package:audio_player/features/library/library_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('five destinations stay on one row and More opens the rest', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: LibraryBottomNav(
            current: 0,
            accent: const Color(0xFFA855F7),
            onSelect: (index) => selected = index,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    for (final label in ['Треки', 'Плейлисты', 'Альбомы', 'Исполнители', 'Ещё']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Папки'), findsNothing);

    await tester.tap(find.text('Ещё'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (final label in ['Папки', 'Избранное', 'История', 'DNA', 'Категории']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Папки'));
    await tester.pumpAndSettle();

    expect(selected, 4);
  });

  testWidgets('More stays selected for a secondary section', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: LibraryBottomNav(
            current: 6,
            accent: const Color(0xFFA855F7),
            onSelect: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Ещё'), findsOneWidget);
    expect(find.text('История'), findsNothing);

    await tester.tap(find.text('Ещё'));
    await tester.pumpAndSettle();

    expect(find.text('История'), findsOneWidget);
  });
}
