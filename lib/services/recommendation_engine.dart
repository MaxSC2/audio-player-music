import 'dart:math' as math;

import '../models/audio_track.dart';
import '../models/recommendation_types.dart';

/// History is newest-first (index 0 = most recent).
int latestHistoryIndex(
  List<Map<String, int>> history,
  int trackId,
) {
  for (var i = 0; i < history.length; i++) {
    if (history[i]['id'] == trackId) return i;
  }
  return -1;
}

/// In a newest-first history, the index is already the distance from newest.
int historyDistanceFromNewest(int historyIndex) =>
    historyIndex < 0 ? -1 : historyIndex;

class RecommendationEngine {
  final List<AudioTrack> pool;
  final List<AudioTrack> catalog;
  final List<Map<String, int>> history;
  final Set<int> favoriteIds;
  final Map<ListeningContext, double> categoryWeights;
  final Set<ListeningContext> activeContexts;
  final AudioTrack? currentTrack;
  final Map<int, int> skipCount;
  final bool deepCuts;
  final DiscoveryLevel discovery;
  final Set<int> exclude;
  final String Function(AudioTrack) primaryGenre;
  final Set<ListeningContext> Function(AudioTrack) categoriesForTrack;

  RecommendationEngine({
    required this.pool,
    required this.catalog,
    required this.history,
    required this.favoriteIds,
    required this.categoryWeights,
    required this.activeContexts,
    required this.currentTrack,
    required this.skipCount,
    required this.deepCuts,
    required this.discovery,
    required this.primaryGenre,
    required this.categoriesForTrack,
    Set<int>? exclude,
  }) : exclude = exclude ?? const <int>{};

  _RecommendationContext _context() {
    final byId = <int, AudioTrack>{for (final t in catalog) t.id: t};
    final playCount = <int, int>{};
    final artistPlayCount = <String, int>{};
    final lastSeen = <int, int>{};
    final artistAffinity = <String, double>{};
    final genreAffinity = <String, double>{};

    for (var i = 0; i < history.length; i++) {
      final raw = history[i];
      final id = raw['id'];
      if (id == null) continue;
      lastSeen.putIfAbsent(id, () => i);
      playCount[id] = (playCount[id] ?? 0) + 1;

      final track = byId[id];
      if (track == null) continue;

      final weight = math.pow(0.88, i).toDouble();
      artistPlayCount[track.artist] =
          (artistPlayCount[track.artist] ?? 0) + 1;
      artistAffinity[track.artist] =
          (artistAffinity[track.artist] ?? 0) + weight;
      final genre = primaryGenre(track);
      genreAffinity[genre] = (genreAffinity[genre] ?? 0) + weight;
    }

    var favoriteWeight = 1.0;
    for (final context in activeContexts) {
      final weight = categoryWeights[context] ?? 1.0;
      if (weight > favoriteWeight) favoriteWeight = weight;
    }

    return _RecommendationContext(
      playCount: playCount,
      artistPlayCount: artistPlayCount,
      lastSeen: lastSeen,
      artistAffinity: artistAffinity,
      genreAffinity: genreAffinity,
      favoriteWeight: favoriteWeight,
      hasEnergy: activeContexts.any(
        (c) => c == ListeningContext.energy || c == ListeningContext.party,
      ),
      hasCalm: activeContexts.any(
        (c) => c == ListeningContext.calm || c == ListeningContext.focus,
      ),
    );
  }

  double _scoreTrack(
    AudioTrack track,
    _RecommendationContext ctx, {
    Map<String, double>? breakdown,
    Map<String, int>? usedArtistCount,
    double randomJitter = 0,
  }) {
    var total = 0.0;

    void add(String label, double value) {
      if (value == 0) return;
      total += value;
      breakdown?[label] = value;
    }

    if (favoriteIds.contains(track.id)) {
      add('Избранное', 45 * ctx.favoriteWeight + 8);
    }

    if (track.artist == currentTrack?.artist) {
      add('Похоже на текущего', 18);
    }

    final artistAffinity = ctx.artistAffinity[track.artist] ?? 0;
    if (artistAffinity > 0) {
      add('Любимый исполнитель', math.min(16.0, artistAffinity) * 1.3);
    }

    final targetGenre = primaryGenre(track);
    final genreAffinity = ctx.genreAffinity[targetGenre] ?? 0;
    if (genreAffinity > 0) {
      add('Любимый жанр', math.min(12.0, genreAffinity) * 1.1);
    }

    final lastSeen = ctx.lastSeen[track.id];
    if (lastSeen != null && lastSeen < 10) {
      add('Играл недавно', -45 * math.exp(-lastSeen / 2.2));
    }

    final skips = skipCount[track.id] ?? 0;
    if (skips > 0) {
      add('Скипали', -math.min(30.0, (skips * 12).toDouble()));
    }

    var categoryBoost = 0.0;
    for (final context in categoriesForTrack(track)) {
      if (!activeContexts.contains(context)) continue;
      final weight = categoryWeights[context] ?? 1.0;
      if (weight > categoryBoost) categoryBoost = weight;
    }
    if (categoryBoost > 0) {
      add('Под текущий контекст', 4 + categoryBoost * 5);
    }

    if (currentTrack != null &&
        track.album == currentTrack!.album &&
        track.id != currentTrack!.id) {
      add('С альбома текущего', 10);
    }

    if (track.id == currentTrack?.id) {
      add('Текущий трек', -50);
    }

    final played = ctx.playCount[track.id] ?? 0;
    if (deepCuts) {
      add('Deep Cuts', (1 - math.min(1.0, played / 8)) * 30);
    }

    final artistPlays = ctx.artistPlayCount[track.artist] ?? 0;
    final known = math.min(1.0, artistPlays / 10);
    final discoveryFactor = discovery.factor;
    if (discoveryFactor < 0.5) {
      add('Знакомый стиль', known * (1 - discoveryFactor) * 20);
    } else {
      add('Новый для тебя', (1 - known) * discoveryFactor * 20);
    }

    if (ctx.hasEnergy &&
        track.duration > 0 &&
        track.duration < 3 * 60 * 1000) {
      add('Короткий, под энергию', 12);
    }
    if (ctx.hasCalm && track.duration >= 3 * 60 * 1000) {
      add('Длинный, для спокойствия', 12);
    }

    final artistCount = usedArtistCount?[track.artist] ?? 0;
    if (artistCount > 0) {
      add('Разнообразие исполнителей', -artistCount * 34);
    }

    if (randomJitter != 0) {
      add('Случайность', randomJitter);
    }

    return total;
  }

  double _score(
    AudioTrack track,
    _RecommendationContext ctx, {
    required Map<String, int> usedArtistCount,
    double randomJitter = 0,
  }) =>
      _scoreTrack(
        track,
        ctx,
        usedArtistCount: usedArtistCount,
        randomJitter: randomJitter,
      );

  Map<String, double> explain(AudioTrack track) {
    final ctx = _context();
    final breakdown = <String, double>{};
    _scoreTrack(track, ctx, breakdown: breakdown);
    return breakdown;
  }

  List<AudioTrack> buildQueue({int count = 60}) {
    if (count <= 0 || pool.isEmpty) return const [];

    final candidates = pool
        .where((track) => !exclude.contains(track.id))
        .toList(growable: false);
    if (candidates.isEmpty) return const [];

    final ctx = _context();
    final queue = <AudioTrack>[];
    final used = <int>{};
    final usedArtistCount = <String, int>{};
    var seed = DateTime.now().millisecondsSinceEpoch;

    int nextRand() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed;
    }

    while (queue.length < count && used.length < candidates.length) {
      AudioTrack? best;
      var bestScore = -1e9;

      for (final track in candidates) {
        if (used.contains(track.id)) continue;
        final jitter = (nextRand() % 400) / 100.0;
        final scoreValue = _score(
          track,
          ctx,
          usedArtistCount: usedArtistCount,
          randomJitter: jitter,
        );
        if (scoreValue > bestScore) {
          bestScore = scoreValue;
          best = track;
        }
      }

      if (best == null) break;
      used.add(best.id);
      queue.add(best);
      usedArtistCount[best.artist] =
          (usedArtistCount[best.artist] ?? 0) + 1;
    }

    return queue;
  }
}

class _RecommendationContext {
  final Map<int, int> playCount;
  final Map<String, int> artistPlayCount;
  final Map<int, int> lastSeen;
  final Map<String, double> artistAffinity;
  final Map<String, double> genreAffinity;
  final double favoriteWeight;
  final bool hasEnergy;
  final bool hasCalm;

  const _RecommendationContext({
    required this.playCount,
    required this.artistPlayCount,
    required this.lastSeen,
    required this.artistAffinity,
    required this.genreAffinity,
    required this.favoriteWeight,
    required this.hasEnergy,
    required this.hasCalm,
  });
}
