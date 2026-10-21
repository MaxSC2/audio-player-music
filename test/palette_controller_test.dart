import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audio_player/state/palette_controller.dart';

void main() {
  group('PaletteColors.decode', () {
    const valid = '4278914068,4289222135,4290807036,4278630100,4293675161,4279286145,4294286859';

    test('decodes a valid seven-color payload', () {
      final palette = PaletteColors.decode(valid);
      expect(palette.background, const Color(0xFF0B0C14));
      expect(palette.accent, const Color(0xFFA855F7));
      expect(palette.accentCyan, const Color(0xFF06B6D4));
      expect(palette.accentAmber, const Color(0xFFF59E0B));
    });

    test('rejects a truncated payload', () {
      expect(
        () => PaletteColors.decode('4278910016,4289011180'),
        throwsFormatException,
      );
    });

    test('rejects malformed or out-of-range colors', () {
      expect(
        () => PaletteColors.decode('x,1,2,3,4,5,6'),
        throwsFormatException,
      );
      expect(
        () => PaletteColors.decode('1,2,3,4,5,6,4294967296'),
        throwsFormatException,
      );
    });
  });
}
