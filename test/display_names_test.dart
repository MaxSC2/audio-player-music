import 'package:flutter_test/flutter_test.dart';

import 'package:audio_player/models/display_names.dart';

void main() {
  group('DisplayNames.album — чистка мусора витрины Коллекции', () {
    test('файловый/теговый мусор обрезается, хвост остаётся', () {
      expect(DisplayNames.album('[muzmo.ru] - GOLDEN HITS'), 'GOLDEN HITS');
      expect(DisplayNames.album('(www.LOMASRANKIAO.com) Best'), 'Best');
      expect(DisplayNames.album('"GOLDEN OLDIES" vol.2'), 'OLDIES" vol.2');
      expect(DisplayNames.album('#райодиннаш TOP 100'), 'TOP 100');
    });

    test('пусто и <unknown> → «Без альбома»', () {
      expect(DisplayNames.album(null), 'Без альбома');
      expect(DisplayNames.album(''), 'Без альбома');
      expect(DisplayNames.album('<unknown>'), 'Без альбома');
      expect(DisplayNames.album('<UNKNOWN>'), 'Без альбома');
    });

    test('короткие остатки не режем — оставляем оригинал', () {
      expect(DisplayNames.album('#41'), '#41');
      expect(DisplayNames.album('"AB"'), '"AB"');
    });

    test('нормальные названия не трогаем', () {
      expect(DisplayNames.album('101 Ibiza'), '101 Ibiza');
      expect(DisplayNames.album('0.й'), '0.й');
      expect(DisplayNames.album('Сборник (2023)'), 'Сборник (2023)');
      expect(DisplayNames.album("Sweet Nothing"), 'Sweet Nothing');
    });
  });

  group('DisplayNames.artist / fileTitle / plural', () {
    test('artist: пусто и <unknown> → подпись', () {
      expect(DisplayNames.artist(null), 'Неизвестный исполнитель');
      expect(DisplayNames.artist('<unknown>'), 'Неизвестный исполнитель');
      expect(DisplayNames.artist('Artik & Asti'), 'Artik & Asti');
    });

    test('fileTitle вынимает имя из пути', () {
      expect(
        DisplayNames.fileTitle('/sdcard/Music/101 Ibiza - Modjo.mp3'),
        '101 Ibiza - Modjo',
      );
      expect(DisplayNames.fileTitle('a.mp3'), isNull);
      expect(DisplayNames.fileTitle(null), isNull);
    });

    test('plural: русская тройка форм', () {
      expect(DisplayNames.tracks(1), '1 трек');
      expect(DisplayNames.tracks(2), '2 трека');
      expect(DisplayNames.tracks(5), '5 треков');
      expect(DisplayNames.tracks(11), '11 треков');
      expect(DisplayNames.tracks(21), '21 трек');
      expect(DisplayNames.tracks(22), '22 трека');
      expect(DisplayNames.albums(3), '3 альбома');
    });
  });
}