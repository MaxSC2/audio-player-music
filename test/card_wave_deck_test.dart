import 'package:audio_player/features/library/card_wave_deck.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('deck renders and play does not open the collection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var opened = 0;
    var played = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: SizedBox(
              width: 160,
              height: 200,
              child: CardWaveDeck(
                title: 'Ночная колода',
                subtitle: '12 треков',
                icon: Icons.queue_music_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A2430), Color(0xFF0B0A0E)],
                ),
                onTap: () => opened++,
                onPlay: () => played++,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Ночная колода'), findsOneWidget);
    expect(find.text('12 треков'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(played, 1);
    expect(opened, 0);

    await tester.tap(find.text('Ночная колода'));
    await tester.pump();
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long deck title fits a compact tile', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 140,
              height: 180,
              child: CardWaveDeck(
                title: 'Очень длинное название музыкальной колоды',
                subtitle: 'Артист • 123 трека',
                icon: Icons.album_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A2430), Color(0xFF0B0A0E)],
                ),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
