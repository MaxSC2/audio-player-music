import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:audio_player/core/ui_style.dart';
import 'package:audio_player/state/palette_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('стиль, выбранный до init, сохраняется после загрузки prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final real = SharedPreferences.getInstance();
    final delayed = Completer<SharedPreferences>();
    final controller = UiStyleController(prefsFuture: delayed.future);

    await controller.setStyle(PlayerUIStyle.neon);
    delayed.complete(await real);
    await controller.init();

    final prefs = await real;
    expect(controller.style, PlayerUIStyle.neon);
    expect(prefs.getString('ui_style'), 'neon');
  });

  test('палитра, выбранная до init, сохраняется после загрузки prefs',
      () async {
    SharedPreferences.setMockInitialValues({});
    final real = SharedPreferences.getInstance();
    final delayed = Completer<SharedPreferences>();
    final controller = PaletteController(prefsFuture: delayed.future);

    controller.select(2);
    delayed.complete(await real);
    await controller.init();

    final prefs = await real;
    expect(controller.index, 2);
    expect(prefs.getInt('palette_mode'), 2);
  });
}
