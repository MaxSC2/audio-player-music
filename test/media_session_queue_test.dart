import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_player/models/audio_track.dart';
import 'package:audio_player/models/custom_playlist.dart';
import 'package:audio_player/providers/player_provider.dart';
import 'package:audio_player/services/recommendation_engine.dart';
import 'package:audio_player/services/audio_handler.dart';

void main() {
  group('calculateNativeWindowTrim', () {
    test('does not trim when the native queue is already bounded', () {
      expect(
        calculateNativeWindowTrim(
          currentLocalIndex: 40,
          nativeLength: 81,
          maxLength: 81,
        ),
        (removeStart: 0, removeEnd: 0),
      );
    });

    test('preserves the current item when trimming from the far side', () {
      final plan = calculateNativeWindowTrim(
        currentLocalIndex: 80,
        nativeLength: 82,
        maxLength: 81,
      );
      expect(plan.removeStart, 1);
      expect(plan.removeEnd, 0);
    });

    test('can trim both sides while keeping the current item', () {
      final plan = calculateNativeWindowTrim(
        currentLocalIndex: 40,
        nativeLength: 85,
        maxLength: 81,
      );
      expect(plan.removeStart + plan.removeEnd, 4);
      expect(plan.removeStart, greaterThanOrEqualTo(0));
      expect(plan.removeEnd, greaterThanOrEqualTo(0));
      expect(40 - plan.removeStart, greaterThanOrEqualTo(0));
      expect(
        85 - plan.removeStart - plan.removeEnd - 1 -
            (40 - plan.removeStart),
        greaterThanOrEqualTo(0),
      );
    });
  });

  group('providerIndexFromMediaQueueIndex', () {
    test('maps valid local indices into the provider queue', () {
      expect(providerIndexFromMediaQueueIndex(0, 120, 81), 120);
      expect(providerIndexFromMediaQueueIndex(40, 120, 81), 160);
      expect(providerIndexFromMediaQueueIndex(80, 120, 81), 200);
    });

    test('rejects indices outside the published window', () {
      expect(providerIndexFromMediaQueueIndex(-1, 120, 81), isNull);
      expect(providerIndexFromMediaQueueIndex(81, 120, 81), isNull);
      expect(providerIndexFromMediaQueueIndex(10, 120, 0), isNull);
    });
  });
}


group('recommendation history recency', () {
  test('newest-first history uses the first matching entry', () {
    final history = <Map<String, int>>[
      {'id': 7, 'ts': 300},
      {'id': 8, 'ts': 200},
      {'id': 7, 'ts': 100},
    ];
    expect(latestHistoryIndex(history, 7), 0);
    expect(latestHistoryIndex(history, 8), 1);
    expect(latestHistoryIndex(history, 9), -1);
  });

  test('history index equals distance from newest', () {
    expect(historyDistanceFromNewest(0), 0);
    expect(historyDistanceFromNewest(9), 9);
    expect(historyDistanceFromNewest(10), 10);
    expect(historyDistanceFromNewest(-1), -1);
  });
});

group('Android Auto browse', () {
  test('exposes root categories, paginates tracks and resolves playback ids', () async {
    final track1 = AudioTrack(
      id: 1,
      title: 'First',
      artist: 'Artist A',
      album: 'Album A',
      uri: 'file:///first.mp3',
      duration: 1000,
    );
    final track2 = AudioTrack(
      id: 2,
      title: 'Second',
      artist: 'Artist B',
      album: 'Album B',
      uri: 'file:///second.mp3',
      duration: 2000,
    );
    final player = AudioPlayer();
    final played = <int>[];
    final playlist = CustomPlaylist(
      id: 'pl_1',
      name: 'Favorites Set',
      trackIds: [2],
      createdAt: 1,
    );

    final handler = PlayerAudioHandler(
      player,
      onToggleRepeat: () {},
      onToggleShuffle: () {},
      onToggleFavorite: () {},
      onNext: () async {},
      onPrevious: () async {},
      onPlayAt: (_) async {},
      onApplyShuffle: (_) async {},
      onApplyRepeat: (_) async {},
      getLibraryTracks: () => [track1, track2],
      getFavoriteTracks: () => [track2],
      getRecentTracks: () => [track1],
      getPlaylists: () => [playlist],
      getPlaylistTracks: (_) => [track2],
      onPlayTrackById: (id) async => played.add(id),
    );

    final root = await handler.getChildren(AudioService.browsableRootId);
    expect(
      root.map((item) => item.id),
      containsAll(<String>[
        'neonwave:all_tracks',
        'neonwave:favorites',
        'neonwave:recent',
        'neonwave:playlists',
      ]),
    );

    final page0 = await handler.getChildren(
      'neonwave:all_tracks',
      <String, dynamic>{
        'android.media.browse.extra.PAGE': 0,
        'android.media.browse.extra.PAGE_SIZE': 1,
      },
    );
    expect(page0.single.id, 'neonwave:track:1');

    final page1 = await handler.getChildren(
      'neonwave:all_tracks',
      <String, dynamic>{
        'android.media.browse.extra.PAGE': 1,
        'android.media.browse.extra.PAGE_SIZE': 1,
      },
    );
    expect(page1.single.id, 'neonwave:track:2');

    final media = await handler.getMediaItem('neonwave:track:2');
    expect(media?.title, 'Second');
    expect(media?.playable, isTrue);

    await handler.playFromMediaId('neonwave:track:2');
    expect(played, [2]);

    final playlistItems =
        await handler.getChildren('neonwave:playlists');
    expect(playlistItems.single.id, 'neonwave:playlist:pl_1');

    final playlistTracks =
        await handler.getChildren('neonwave:playlist:pl_1');
    expect(playlistTracks.single.id, 'neonwave:track:2');

    await player.dispose();
  });
});
