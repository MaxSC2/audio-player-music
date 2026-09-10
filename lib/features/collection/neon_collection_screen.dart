import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/audio_track.dart';
import '../../providers/player_provider.dart';
import '../../screens/artist_detail_screen.dart';
import '../../widgets/cached_artwork.dart';
import '../../widgets/collection_cards.dart';
import '../now_playing/cinematic/cinematic_player_body.dart';

/// Коллекция (фишка стиля Неон, референс 04): переключатель
/// Альбомы/Исполнители, chips-фильтр, сетка альбомов, аватары артистов.
class NeonCollectionScreen extends StatefulWidget {
  const NeonCollectionScreen({super.key});

  @override
  State<NeonCollectionScreen> createState() => _NeonCollectionScreenState();
}

class _NeonCollectionScreenState extends State<NeonCollectionScreen> {
  int _mode = 0; // 0 альбомы, 1 исполнители
  int _albumFilter = 0; // 0 все, 1 недавние, 2 популярные, 3 A–Z

  static const _filterNames = ['Все', 'Недавние', 'Популярные', 'A–Z'];

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return Scaffold(
      backgroundColor: CinematicTheme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: CinematicTheme.textSoft,
                      size: 24,
                    ),
                    tooltip: 'Назад',
                  ),
                  const Text(
                    'Коллекция',
                    style: TextStyle(
                      color: CinematicTheme.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

            // Switcher Альбомы/Исполнители
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  _ModeTab(
                    label: 'Альбомы',
                    selected: _mode == 0,
                    onTap: () => setState(() => _mode = 0),
                  ),
                  const SizedBox(width: 24),
                  _ModeTab(
                    label: 'Исполнители',
                    selected: _mode == 1,
                    onTap: () => setState(() => _mode = 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            if (_mode == 0) ...[
              // Filter chips
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: _filterNames.length,
                  itemBuilder: (context, i) {
                    final selected = _albumFilter == i;
                    return ChoiceChip(
                      label: Text(_filterNames[i]),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _albumFilter = i),
                      selectedColor: const Color(0xFFA855F7).withValues(
                        alpha: const Color(0xFFA855F7).a * 0.25,
                      ),
                      backgroundColor: const Color(0x14FFFFFF),
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : CinematicTheme.textDim,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: selected
                            ? const Color(0xFFA855F7)
                            : Colors.transparent,
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: _AlbumsGrid(player, filter: _albumFilter),
              ),
            ] else
              Expanded(child: _ArtistsBlock(player)),
          ],
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected
                  ? CinematicTheme.text
                  : CinematicTheme.textDim,
              fontSize: 16,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 3,
            width: selected ? 56 : 0,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFA855F7), Color(0xFF38BDF8)],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumsGrid extends StatelessWidget {
  final PlayerProvider player;
  final int filter;

  const _AlbumsGrid(this.player, {required this.filter});

  @override
  Widget build(BuildContext context) {
    final albums = player.albums.toList();

    if (albums.isEmpty) {
      return const Center(
        child: Text(
          'Альбомы не найдены',
          style: TextStyle(color: CinematicTheme.textDim),
        ),
      );
    }

    final entries = player.albumEntries.toList();
    final counts = player.playCounts;
    switch (filter) {
      case 1:
        entries.sort((a, b) {
          final da = a.tracks
              .map((t) => t.dateAdded ?? 0)
              .fold<int>(0, (p, e) => e > p ? e : p);
          final db = b.tracks
              .map((t) => t.dateAdded ?? 0)
              .fold<int>(0, (p, e) => e > p ? e : p);
          return db.compareTo(da);
        });
        break;
      case 2:
        int plays(List<AudioTrack> ts) =>
            ts.fold<int>(0, (p, t) => p + (counts[t.id] ?? 0));
        entries.sort((a, b) => plays(b.tracks).compareTo(plays(a.tracks)));
        break;
      case 3:
        entries.sort(
          (a, b) => a.album.toLowerCase().compareTo(b.album.toLowerCase()),
        );
        break;
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        childAspectRatio: 0.66,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final e = entries[index];
        return _CollectionAlbumCard(
          player: player,
          album: e.album,
          tracks: e.tracks,
        );
      },
    );
  }
}

/// Компактная карточка альбома для сетки 3 в ряд (тёмная, под Неон).
class _CollectionAlbumCard extends StatelessWidget {
  final PlayerProvider player;
  final String album;
  final List<AudioTrack> tracks;

  const _CollectionAlbumCard({
    required this.player,
    required this.album,
    required this.tracks,
  });

  @override
  Widget build(BuildContext context) {
    final artist = tracks.isNotEmpty ? tracks.first.artist : '';
    return GestureDetector(
      onTap: () {
        if (tracks.isNotEmpty) player.playFromPlaylist(tracks, 0);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: Colors.white.a * 0.14,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: Colors.black.a * 0.4,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: tracks.isNotEmpty
                    ? CachedArtwork(
                        trackId: tracks.first.id,
                        width: 200,
                        height: 200,
                        radius: 0,
                      )
                    : Container(
                        color: const Color(0xFF1A1C2B),
                        child: const Center(
                          child: Icon(
                            Icons.album_rounded,
                            color: Colors.white54,
                            size: 36,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      album,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      artist.isEmpty
                          ? '${tracks.length}'
                          : '$artist • ${tracks.length}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CinematicTheme.textDim,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              AlbumMenu(
                tracks: tracks,
                iconColor: CinematicTheme.textDim,
                iconSize: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArtistsBlock extends StatelessWidget {
  final PlayerProvider player;

  const _ArtistsBlock(this.player);

  @override
  Widget build(BuildContext context) {
    final artists = player.artists.toList();
    if (artists.isEmpty) {
      return const Center(
        child: Text(
          'Исполнители не найдены',
          style: TextStyle(color: CinematicTheme.textDim),
        ),
      );
    }

    List<AudioTrack> tracksOf(String artist) =>
        player.allTracks.where((t) => t.artist == artist).toList();

    int albumCountOf(List<AudioTrack> ts) => ts
        .map((t) => t.album ?? '')
        .where((a) => a.isNotEmpty)
        .toSet()
        .length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 0, 4),
            child: Row(
              children: [
                const Text(
                  'Исполнители',
                  style: TextStyle(
                    color: CinematicTheme.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  'Все ${artists.length} ›',
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemCount: artists.length > 12 ? 12 : artists.length,
              itemBuilder: (context, i) {
                final artist = artists[i];
                final ts = tracksOf(artist);
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        settings: const RouteSettings(name: 'ArtistDetail'),
                        builder: (_) =>
                            ArtistDetailScreen(artist: artist),
                      ),
                    );
                  },
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      children: [
                        ts.isNotEmpty
                            ? ClipOval(
                                child: CachedArtwork(
                                  trackId: ts.first.id,
                                  width: 64,
                                  height: 64,
                                  radius: 0,
                                ),
                              )
                            : Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF1A1C2B),
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white54,
                                ),
                              ),
                        const SizedBox(height: 6),
                        Text(
                          artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${albumCountOf(ts)}',
                          style: const TextStyle(
                            color: CinematicTheme.textDim,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          sliver: SliverList.builder(
            itemCount: artists.length,
            itemBuilder: (context, i) {
              final artist = artists[i];
              final ts = tracksOf(artist);
              return _DarkArtistRow(
                artist: artist,
                tracks: ts,
                albumCount: albumCountOf(ts),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      settings: const RouteSettings(name: 'ArtistDetail'),
                      builder: (_) => ArtistDetailScreen(artist: artist),
                    ),
                  );
                },
                onPlay: () {
                  if (ts.isNotEmpty) player.playFromPlaylist(ts, 0);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Тёмная строка исполнителя для Коллекции.
class _DarkArtistRow extends StatelessWidget {
  final String artist;
  final List<AudioTrack> tracks;
  final int albumCount;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  const _DarkArtistRow({
    required this.artist,
    required this.tracks,
    required this.albumCount,
    required this.onTap,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: Colors.white.a * 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: Colors.white.a * 0.10),
          ),
        ),
        child: Row(
          children: [
            tracks.isNotEmpty
                ? ClipOval(
                    child: CachedArtwork(
                      trackId: tracks.first.id,
                      width: 46,
                      height: 46,
                      radius: 0,
                    ),
                  )
                : Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1A1C2B),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white54,
                    ),
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '$albumCount • ${tracks.length}',
                    style: const TextStyle(
                      color: CinematicTheme.textDim,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onPlay,
              icon: const Icon(
                Icons.play_circle_fill_rounded,
                color: Color(0xFFA855F7),
                size: 30,
              ),
              tooltip: 'Слушать',
            ),
          ],
        ),
      ),
    );
  }
}
