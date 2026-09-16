import 'package:flutter_test/flutter_test.dart';

import 'dart:math' as math;

void main() {
  group('trackFix обучение (E3-часть 2) — математика поправок', () {
    // Зеркало формулы из _learnFromVolumeChange:
    // next = clamp(cur * (1 + 0.5 * delta), 0.5, 1.6).
    double learn(double cur, double delta) =>
        (cur * (1 + 0.5 * delta)).clamp(0.5, 1.6);

    test('прибавил громкость → поправка растёт (трек был тихим)', () {
      expect(learn(1.0, 0.2), closeTo(1.1, 1e-9));
    });

    test('убавил громкость → поправка падает (трек был громким)', () {
      expect(learn(1.0, -0.2), closeTo(0.9, 1e-9));
    });

    test('потолок 1.6 не пробивается', () {
      expect(learn(1.5, 0.5), 1.6);
    });

    test('пол 0.5 не пробивается', () {
      expect(learn(0.55, -0.5), 0.5);
    });

    test('мелкий шум игнорируется вызывающей стороной (порог 0.02)', () {
      // Порог delta.abs() < 0.02 — проверяем границу формулы:
      // при delta=0.019 изменение < 1% — обучение бессмысленно.
      expect((learn(1.0, 0.019) - 1.0).abs(), lessThan(0.01));
    });

    test('дБ-пересчёт: ×1.6 ≈ +4.08 дБ, ×0.5 ≈ −6.02 дБ', () {
      double db(double fix) => 20 * math.log(fix) / math.ln10;
      expect(db(1.6), closeTo(4.08, 0.01));
      expect(db(0.5), closeTo(-6.02, 0.01));
      expect(db(1.0), closeTo(0.0, 1e-9));
    });

    test('effectiveVolume: user × fix × xBoost, потолок 1.0', () {
      double eff(double user, double fix, bool boost) {
        var v = user * fix.clamp(0.5, 1.6);
        if (boost) v *= 1.6;
        return v.clamp(0.0, 1.0);
      }

      expect(eff(0.8, 1.2, false), closeTo(0.96, 1e-9));
      expect(eff(0.8, 1.6, true), 1.0); // клиппинг обрезан
      expect(eff(0.5, 0.5, false), closeTo(0.25, 1e-9));
    });
  });
}