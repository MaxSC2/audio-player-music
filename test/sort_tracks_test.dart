import 'package:flutter_test/flutter_test.dart';
import 'package:audio_player/models/audio_track.dart';
import 'package:audio_player/providers/player_provider.dart';

AudioTrack _t({
  required int id,
  String title = 'T',
  String artist = 'A',
  int? dateAdded,
  int duration = 100,
}) =>
    AudioTrack(
      id: id,
      title: title,
      artist: artist,
      uri: 'content://media/external/audio/media/$id',
      duration: duration,
      dateAdded: dateAdded,
    );

void main() {
  group('sortTracksPure', () {
    test('title: сортировка без учёта регистра', () {
      final r = sortTracksPure(
        [_t(id: 1, title: 'banana'), _t(id: 2, title: 'Apple'), _t(id: 3, title: 'cherry')],
        SortOrder.title,
      );
      expect(r.map((t) => t.title).toList(), ['Apple', 'banana', 'cherry']);
    });

    test('artist: сортировка без учёта регистра', () {
      final r = sortTracksPure(
        [_t(id: 1, artist: 'zeta'), _t(id: 2, artist: 'Alpha')],
        SortOrder.artist,
      );
      expect(r.first.artist, 'Alpha');
    });

    test('dateAddedNew: новые первыми; null считается 0', () {
      final r = sortTracksPure(
        [
          _t(id: 1, dateAdded: 100),
          _t(id: 2, dateAdded: 300),
          _t(id: 3), // null -> 0, в конец
        ],
        SortOrder.dateAddedNew,
      );
      expect(r.map((t) => t.id).toList(), [2, 1, 3]);
    });

    test('dateAddedOld: старые первыми', () {
      final r = sortTracksPure(
        [_t(id: 1, dateAdded: 100), _t(id: 2, dateAdded: 300)],
        SortOrder.dateAddedOld,
      );
      expect(r.first.id, 1);
    });

    test('duration: длинные первыми', () {
      final r = sortTracksPure(
        [_t(id: 1, duration: 50), _t(id: 2, duration: 500)],
        SortOrder.duration,
      );
      expect(r.first.id, 2);
    });

    test('исходный список не мутируется', () {
      final src = [_t(id: 2, title: 'b'), _t(id: 1, title: 'a')];
      sortTracksPure(src, SortOrder.title);
      expect(src.map((t) => t.id).toList(), [2, 1]);
    });
  });
}
