import 'package:flutter_test/flutter_test.dart';
import 'package:audio_player/models/audio_track.dart';
import 'package:audio_player/models/recommendation_types.dart';
import 'package:audio_player/services/recommendation_engine.dart';

AudioTrack track({
  required int id,
  required String artist,
  String? album,
  int duration = 180000,
  bool favorite = false,
}) =>
    AudioTrack(
      id: id,
      title: 'Track $id',
      artist: artist,
      album: album,
      uri: 'file:///track$id.mp3',
      duration: duration,
      isFavorite: favorite,
    );

RecommendationEngine engine({
  required List<AudioTrack> catalog,
  List<Map<String, int>>? history,
  Set<int>? favorites,
  Set<ListeningContext>? contexts,
  DiscoveryLevel discovery = DiscoveryLevel.balanced,
  bool deepCuts = false,
  Map<int, int>? skips,
}) =>
    RecommendationEngine(
      pool: catalog,
      catalog: catalog,
      history: history ?? const [],
      favoriteIds: favorites ?? const {},
      categoryWeights: const {
        ListeningContext.balanced: 1.0,
        ListeningContext.energy: 1.6,
        ListeningContext.calm: 1.25,
        ListeningContext.focus: 1.25,
        ListeningContext.party: 1.6,
      },
      activeContexts: contexts ?? {ListeningContext.balanced},
      currentTrack: null,
      skipCount: skips ?? const {},
      deepCuts: deepCuts,
      discovery: discovery,
      primaryGenre: (_) => 'Test',
      categoriesForTrack: (_) => {ListeningContext.balanced},
    );

void main() {
  group('RecommendationEngine', () {
    test('explanation uses the same favorite and context components as scoring', () {
      final tracks = [
        track(id: 1, artist: 'A', favorite: true),
        track(id: 2, artist: 'B'),
      ];
      final explanation = RecommendationEngine(
        pool: tracks,
        catalog: tracks,
        history: const [],
        favoriteIds: {1},
        categoryWeights: const {
          ListeningContext.energy: 1.6,
        },
        activeContexts: const {ListeningContext.energy},
        currentTrack: null,
        skipCount: const {},
        deepCuts: false,
        discovery: DiscoveryLevel.balanced,
        primaryGenre: (_) => 'Test',
        categoriesForTrack: (_) => {ListeningContext.energy},
      ).explain(tracks.first);

      expect(explanation['Избранное'], 53.0);
      expect(explanation['Под текущий контекст'], 12.0);
    });

    test('newest-first history uses the latest occurrence for recency', () {
      final tracks = [
        track(id: 1, artist: 'A'),
        track(id: 2, artist: 'B'),
      ];
      final result = engine(
        catalog: tracks,
        history: [
          {'id': 1, 'ts': 300},
          {'id': 2, 'ts': 200},
          {'id': 1, 'ts': 100},
        ],
      ).explain(tracks.first);

      expect(result['Играл недавно'], closeTo(-45.0, 0.0001));
    });

    test('excluded ids remain outside generated queue', () {
      final tracks = [
        track(id: 1, artist: 'A'),
        track(id: 2, artist: 'B'),
        track(id: 3, artist: 'C'),
      ];
      final result = RecommendationEngine(
        pool: tracks,
        catalog: tracks,
        history: const [],
        favoriteIds: const {},
        categoryWeights: const {
          ListeningContext.balanced: 1.0,
        },
        activeContexts: const {ListeningContext.balanced},
        currentTrack: null,
        skipCount: const {},
        deepCuts: false,
        discovery: DiscoveryLevel.balanced,
        exclude: {2},
        primaryGenre: (_) => 'Test',
        categoriesForTrack: (_) => {ListeningContext.balanced},
      ).buildQueue(count: 3);

      expect(result.map((t) => t.id), isNot(contains(2)));
      expect(result.length, 2);
    });

    test('large catalogs keep history lookup independent from candidate pool', () {
      final excludedHistoryTrack = track(id: 99, artist: 'Affinity Artist');
      final candidates = [
        track(id: 1, artist: 'Affinity Artist'),
        track(id: 2, artist: 'Other'),
      ];
      final result = RecommendationEngine(
        pool: candidates,
        catalog: [...candidates, excludedHistoryTrack],
        history: [
          {'id': 99, 'ts': 2},
          {'id': 99, 'ts': 1},
        ],
        favoriteIds: const {},
        categoryWeights: const {ListeningContext.balanced: 1.0},
        activeContexts: const {ListeningContext.balanced},
        currentTrack: null,
        skipCount: const {},
        deepCuts: false,
        discovery: DiscoveryLevel.balanced,
        primaryGenre: (_) => 'Test',
        categoriesForTrack: (_) => {ListeningContext.balanced},
      );

      final explanation = result.explain(candidates.first);
      expect(explanation['Любимый исполнитель'], greaterThan(0));
    });

    test('helper distance and latest index follow newest-first semantics', () {
      final history = <Map<String, int>>[
        {'id': 7, 'ts': 300},
        {'id': 8, 'ts': 200},
        {'id': 7, 'ts': 100},
      ];
      expect(latestHistoryIndex(history, 7), 0);
      expect(historyDistanceFromNewest(0), 0);
      expect(historyDistanceFromNewest(-1), -1);
    });
  });
}
