import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:audio_player/providers/player_provider.dart';

void main() {
  group('buildShuffleOrder', () {
    test('пустая и одноэлементная очередь — пустой порядок', () {
      expect(buildShuffleOrder(0, 0), isEmpty);
      expect(buildShuffleOrder(1, 0), isEmpty);
      expect(buildShuffleOrder(1, -1), isEmpty);
    });

    test('содержит все индексы ровно по одному разу', () {
      const n = 50;
      final order = buildShuffleOrder(n, 0, random: math.Random(42));
      expect(order.length, n);
      expect(order.toSet().length, n, reason: 'дубликаты недопустимы');
      expect(order.reduce(math.max), n - 1);
      expect(order.reduce(math.min), 0);
    });

    test('текущий трек идёт первым — воспроизведение не переключается', () {
      const n = 30;
      for (var cur = 0; cur < n; cur++) {
        final order = buildShuffleOrder(n, cur, random: math.Random(cur));
        expect(order.first, cur, reason: 'current=$cur должен быть первым');
      }
    });

    test('детерминирован при одном seed', () {
      final a = buildShuffleOrder(20, 3, random: math.Random(7));
      final b = buildShuffleOrder(20, 3, random: math.Random(7));
      expect(a, b);
    });

    test('реально перемешивает (не тождественная перестановка)', () {
      const n = 40;
      final order = buildShuffleOrder(n, 0, random: math.Random(1));
      final identity = List<int>.generate(n, (i) => i);
      expect(order, isNot(equals(identity)));
    });
  });

  group('buildNativeShuffleOrder (B24: автопереход в shuffle)', () {
    test('текущий трек идёт первым, перестановка покрывает всё окно', () {
      final round = buildShuffleOrder(10, 4, random: math.Random(3));
      final pos = shufflePosFor(round, 4);
      final order = buildNativeShuffleOrder(
        round: round,
        pos: pos,
        playlistLength: 10,
        current: 4,
        windowStartsAt: 0,
        windowLength: 10,
      );
      expect(order, isNotNull);
      expect(order!.first, 4, reason: 'раунд продолжается с текущего трека');
      expect(order.length, 10);
      expect(order.toSet().length, 10, reason: 'каждый трек окна — один раз');
    });

    test('после текущего идут НЕсыгранные, сыгранные — в конце', () {
      // Раунд: 0,1,2,3,4,5,6,7,8,9; курсор на 4 → сыграны 0..4.
      final round = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
      final order = buildNativeShuffleOrder(
        round: round,
        pos: 4,
        playlistLength: 10,
        current: 4,
        windowStartsAt: 0,
        windowLength: 10,
      )!;
      expect(order.sublist(1, 6), [5, 6, 7, 8, 9], reason: 'несыгранные по порядку раунда');
      expect(order.sublist(6), [0, 1, 2, 3], reason: 'сыгранные — в хвосте окна');
    });

    test('после исчерпания несыгранных автопереход попадает в сыгранные', () {
      final round = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
      final order = buildNativeShuffleOrder(
        round: round,
        pos: 4,
        playlistLength: 10,
        current: 4,
        windowStartsAt: 0,
        windowLength: 10,
      )!;
      // Пять «автопереходов» по нативному порядку после текущего.
      final tail = order.sublist(1);
      expect(tail.take(5), [5, 6, 7, 8, 9]);
      expect(tail.skip(5), [0, 1, 2, 3]);
    });

    test('треки окна вне раунда идут за несыгранными', () {
      // Раунд из 4 треков, окно из 6: индексы 4 и 5 в раунд не входят.
      final round = [1, 0, 3, 2];
      final order = buildNativeShuffleOrder(
        round: round,
        pos: 1,
        playlistLength: 4,
        current: 0,
        windowStartsAt: 0,
        windowLength: 6,
      );
      expect(order, isNull, reason: 'окно шире очереди — перестановка невозможна');
    });

    test('новые треки (без раунда) не ломают порядок', () {
      final order = buildNativeShuffleOrder(
        round: const [],
        pos: -1,
        playlistLength: 5,
        current: 2,
        windowStartsAt: 0,
        windowLength: 5,
      )!;
      expect(order.first, 2);
      expect(order.toSet().length, 5);
    });

    test('уже сыгранный раунд целиком: стартуем с хвоста, затем всё сначала', () {
      final round = [0, 1, 2, 3];
      final order = buildNativeShuffleOrder(
        round: round,
        pos: 3,
        playlistLength: 4,
        current: 3,
        windowStartsAt: 0,
        windowLength: 4,
      )!;
      expect(order.first, 3);
      expect(order.sublist(1), [0, 1, 2], reason: 'новый круг начнётся с начала');
    });

    test('курсор вне окна — порядок всё равно валиден', () {
      final round = [5, 6, 7, 8, 9, 0, 1, 2, 3, 4];
      final order = buildNativeShuffleOrder(
        round: round,
        pos: 0,
        playlistLength: 10,
        current: 5,
        windowStartsAt: 0,
        windowLength: 5,
      )!;
      expect(order.length, 5);
      expect(order.toSet().length, 5);
    });
  });

  group('nextShuffleStep', () {
    test('двигается по раунду и не выходит за границы', () {
      final round = [3, 1, 4, 0, 2];
      var pos = 0;
      final visited = <int>[round[pos]];
      for (var i = 0; i < round.length - 1; i++) {
        final step = nextShuffleStep(round, pos);
        expect(step.newRound, isFalse);
        pos = step.pos;
        visited.add(step.index);
      }
      expect(visited, round, reason: 'раунд проигрывается целиком без повторов');
      final wrap = nextShuffleStep(round, pos);
      expect(wrap.newRound, isTrue, reason: 'после последнего — новый раунд');
    });

    test('один трек — остаётся на нём', () {
      final step = nextShuffleStep([7], 0);
      expect(step.index, 7);
      expect(step.newRound, isFalse);
    });

    test('пустой раунд — безопасный результат', () {
      final step = nextShuffleStep(const [], -1);
      expect(step.index, -1);
      expect(step.newRound, isFalse);
    });
  });

  group('shufflePosFor', () {
    test('позиция курсора совпадает с индексом трека в раунде', () {
      final round = [4, 2, 0, 3, 1];
      expect(shufflePosFor(round, 0), 2);
      expect(shufflePosFor(round, 4), 0);
    });

    test('трека нет в раунде — безопасный старт', () {
      expect(shufflePosFor([1, 2], 9), 0);
      expect(shufflePosFor(const [], 9), 0);
    });
  });

  group('insertIntoShuffleRound (B27: «играть следующими» в shuffle)', () {
    test('новые треки встают сразу после курсора раунда', () {
      // Раунд [3,1,4,0,2], курсор на 1 (сыгран трек 3). Вставляем 2 трека
      // на позицию 2 списка: индексы 2 и выше сдвигаются на 2.
      final r = insertIntoShuffleRound(
        round: [3, 1, 4, 0, 2],
        pos: 1,
        index: 2,
        count: 2,
      );
      expect(r.pos, 1);
      expect(r.round.length, 7);
      expect(r.round.toSet().length, 7, reason: 'без дублей и потерь');
      expect(r.round.sublist(2, 4), [2, 3], reason: 'вставленные — следующие');
      expect(r.round.first, 3, reason: 'уже сыгранное остаётся на месте');
    });

    test('вставка в конец списка уходит в конец раунда', () {
      final r = insertIntoShuffleRound(
        round: [2, 0, 1],
        pos: 0,
        index: 3,
        count: 1,
        atEnd: true,
      );
      expect(r.round, [2, 0, 1, 3]);
      expect(r.pos, 0);
    });

    test('сдвиг индексов не теряет и не дублирует треки', () {
      final r = insertIntoShuffleRound(
        round: [0, 1, 2, 3],
        pos: 2,
        index: 0,
        count: 2,
      );
      expect(r.round.toSet(), {0, 1, 2, 3, 4, 5});
      expect(r.round.length, 6);
    });
  });

  group('removeFromShuffleRound (B27: удаление из раунда)', () {
    test('курсор не перескакивает на уже сыгранное', () {
      final r = removeFromShuffleRound(round: [3, 1, 4, 0, 2], pos: 1, index: 4);
      expect(r.round, [3, 1, 0, 2], reason: 'удалён 4, индексы > 4 сдвинуты');
      expect(r.pos, 1);
    });

    test('удаление до курсора сдвигает курсор влево', () {
      final r = removeFromShuffleRound(round: [3, 1, 4, 0, 2], pos: 3, index: 1);
      expect(r.round, [2, 3, 0, 1]);
      expect(r.pos, 2);
    });

    test('удаление единственного элемента обнуляет раунд', () {
      final r = removeFromShuffleRound(round: [9], pos: 0, index: 9);
      expect(r.round, isEmpty);
      expect(r.pos, -1);
    });
  });

  group('B31: ручной выбор трека в shuffle', () {
    test('курсор раунда встаёт на выбранный трек', () {
      final round = buildShuffleOrder(8, 0, random: math.Random(11));
      // Пользователь выбрал трек 5 из очереди.
      final pos = shufflePosFor(round, 5);
      expect(round[pos], 5);
      // Автопереход продолжает раунд с этого места, а не с начала.
      final step = nextShuffleStep(round, pos);
      expect(step.index, round[pos + 1 < round.length ? pos + 1 : 0]);
    });

    test('выбранного трека нет в раунде — безопасный фолбэк', () {
      final pos = shufflePosFor(const [0, 1, 2], 7);
      expect(pos, 0);
    });
  });

  group('appendToShuffleRound (B32: радио в shuffle)', () {
    test('новые треки дописываются в конец раунда, курсор на месте', () {
      // Раунд покрывает очередь из 5 треков, играет позиция 2.
      final r = appendToShuffleRound(
        round: const [4, 0, 3, 1, 2],
        pos: 2,
        appendIndex: 5,
        count: 3,
      );
      expect(r.round, [4, 0, 3, 1, 2, 5, 6, 7]);
      expect(r.pos, 2, reason: 'играющий трек не должен сдвигаться');
      // Новые треки ещё не звучали — они позже курсора.
      for (var p = 3; p < r.round.length; p++) {
        expect(r.round[p], greaterThanOrEqualTo(5));
      }
    });

    test('раунд короче очереди — не трогаем (перестроит вызывающий)', () {
      final r = appendToShuffleRound(
        round: const [1, 0],
        pos: 1,
        appendIndex: 4,
        count: 2,
      );
      expect(r.round, [1, 0]);
      expect(r.pos, 1);
    });

    test('count <= 0 — без изменений', () {
      final r = appendToShuffleRound(
        round: const [1, 0],
        pos: 0,
        appendIndex: 2,
        count: 0,
      );
      expect(r.round, [1, 0]);
      expect(r.pos, 0);
    });

    test('после догрузки автопереход играет новый трек, а не начинает раунд', () {
      final r = appendToShuffleRound(
        round: const [2, 0, 1],
        pos: 0,
        appendIndex: 3,
        count: 2,
      );
      final step = nextShuffleStep(r.round, r.pos);
      expect(step.newRound, isFalse, reason: 'раунд не должен считаться исчерпанным');
      expect(step.index, 0);
    });
  });

  group('B33/B34: сценарии shuffle на краях раунда', () {
    test('догрузка → полный обход всех треков без повторов', () {
      var round = buildShuffleOrder(4, 0, random: math.Random(3));
      var pos = 0;
      final r = appendToShuffleRound(round: round, pos: pos, appendIndex: 4, count: 3);
      round = r.round;
      pos = r.pos;
      final seen = <int>[round[pos]];
      // Доигрываем раунд до конца.
      while (true) {
        final step = nextShuffleStep(round, pos);
        if (step.newRound) break;
        pos = step.pos;
        seen.add(step.index);
        if (seen.length > round.length + 2) break;
      }
      expect(seen.toSet().length, seen.length, reason: 'ни один трек не повторён');
      expect(seen.length, 7, reason: 'все 7 треков раунда сыграны один раз');
    });

    test('начало раунда: nextShuffleStep остаётся в раунде (B34 — не список)', () {
      const round = [5, 2, 9, 0];
      final step = nextShuffleStep(round, 0);
      expect(step.newRound, isFalse);
      expect(step.index, 2, reason: 'идём по раунду, а не по списку');
      expect(step.pos, 1);
    });
  });
}
