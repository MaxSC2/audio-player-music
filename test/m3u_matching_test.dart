import 'package:flutter_test/flutter_test.dart';
import 'package:audio_player/models/audio_track.dart';
import 'package:audio_player/services/m3u_matcher.dart';

AudioTrack track(int id, String path) => AudioTrack(
  id: id,
  title: 'Track $id',
  artist: 'Artist',
  uri: 'file://$path',
  duration: 1000,
  data: path,
);

void main() {
  group('M3U matching', () {
    test('normalizes file URIs, separators and case', () {
      expect(
        normalizeM3uPath(r'FILE:///Music\\Album/Track.MP3?x=1'),
        '/music/album/track.mp3',
      );
    });

    test('prefers exact path when basename is duplicated', () {
      final a = track(1, '/music/track.mp3');
      final b = track(2, '/archive/track.mp3');
      final byPath = {
        normalizeM3uPath(a.data!): a,
        normalizeM3uPath(b.data!): b,
      };
      final byBasename = {
        'track.mp3': [a, b],
      };

      expect(
        matchM3uLine('/archive/track.mp3', byPath, byBasename)?.id,
        2,
      );
    });

    test('skips ambiguous basename instead of selecting arbitrary track', () {
      final a = track(1, '/music/track.mp3');
      final b = track(2, '/archive/track.mp3');
      final byBasename = {
        'track.mp3': [a, b],
      };

      expect(
        matchM3uLine('TRACK.MP3', const {}, byBasename),
        isNull,
      );
    });

    test('unique basename remains a valid fallback', () {
      final a = track(1, '/music/track.mp3');
      final byBasename = {
        'track.mp3': [a],
      };

      expect(
        matchM3uLine('track.mp3', const {}, byBasename)?.id,
        1,
      );
    });
  });
}
