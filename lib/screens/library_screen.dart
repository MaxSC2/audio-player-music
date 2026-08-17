import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';
import '../widgets/player_bar.dart';
import '../widgets/track_tile.dart';
import 'player_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final player = context.read<PlayerProvider>();
    await player.requestPermission();
    if (!mounted) return;
    setState(() {
      _permissionDenied = player.allTracks.isEmpty;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('NeonWave'),
        actions: [
          if (player.allTracks.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort_rounded,
                  color: AppTheme.textSecondary),
              color: AppTheme.surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppTheme.cardBorder),
              ),
              onSelected: (value) {
                switch (value) {
                  case 'title':
                    player.sortOrder = SortOrder.title;
                  case 'artist':
                    player.sortOrder = SortOrder.artist;
                  case 'date':
                    player.sortOrder = SortOrder.dateAdded;
                  case 'duration':
                    player.sortOrder = SortOrder.duration;
                }
              },
              itemBuilder: (context) => [
                _buildSortItem(SortOrder.title, player.sortOrder, 'По названию'),
                _buildSortItem(
                    SortOrder.artist, player.sortOrder, 'По исполнителю'),
                _buildSortItem(
                    SortOrder.dateAdded, player.sortOrder, 'По дате добавления'),
                _buildSortItem(
                    SortOrder.duration, player.sortOrder, 'По длительности'),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 3,
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Треки'),
            Tab(text: 'Исполнители'),
            Tab(text: 'Альбомы'),
            Tab(text: 'Избранное'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim();
                });
              },
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Поиск треков, исполнителей...',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppTheme.textMuted),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: AppTheme.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.surfaceLight,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: _permissionDenied && player.allTracks.isEmpty
                ? _buildPermissionDenied()
                : player.allTracks.isEmpty
                    ? _buildLoading()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTrackList(player),
                          _buildArtistList(player),
                          _buildAlbumList(player),
                          _buildFavoriteList(player),
                        ],
                      ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniPlayerBar(
            onExpand: () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const PlayerScreen(),
                  transitionsBuilder: (_, anim, __, child) {
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.4),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                        ),
                        child: child,
                      ),
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 350),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.accent),
          SizedBox(height: 16),
          Text(
            'Сканируем музыку...',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.music_off_rounded,
                color: AppTheme.textSecondary,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Нет доступа к музыке',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Разрешите доступ к аудиофайлам, чтобы видеть вашу музыкальную библиотеку.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _requestPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Запросить доступ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackList(PlayerProvider player) {
    final query = _searchQuery;
    final tracks = player.searchTracks(query);
    final playlist = tracks;

    if (tracks.isEmpty) {
      return _buildEmptyState('Ничего не найдено', Icons.search_off_rounded);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isCurrent = player.currentTrack?.id == track.id;

        return TrackTile(
          track: track,
          isPlaying: isCurrent && player.isPlaying,
          isCurrent: isCurrent,
          onTap: () {
            if (playlist.length > 1) {
              player.playFromPlaylist(playlist, index);
            } else {
              player.playTrack(track);
            }
          },
        );
      },
    );
  }

  Widget _buildArtistList(PlayerProvider player) {
    final query = _searchQuery.toLowerCase();
    final artists = player.artists.where((a) => a.toLowerCase().contains(query)).toList();

    if (artists.isEmpty) {
      return _buildEmptyState('Исполнители не найдены', Icons.person_off_rounded);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        final tracks = player.allTracks
            .where((t) => t.artist == artist)
            .toList();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
              ),
              child: const Icon(Icons.person_rounded,
                  color: Colors.white, size: 26),
            ),
            title: Text(
              artist,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${tracks.length} треков',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            onTap: () {
              player.playFromPlaylist(tracks, 0);
            },
          ),
        );
      },
    );
  }

  Widget _buildAlbumList(PlayerProvider player) {
    final query = _searchQuery.toLowerCase();
    final albums = player.albums
        .where((a) => a.toLowerCase().contains(query))
        .toList();

    if (albums.isEmpty) {
      return _buildEmptyState('Альбомы не найдены', Icons.album_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        final tracks = player.allTracks
            .where((t) => t.album == album)
            .toList();
        final albumArtId = tracks.first.id;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: AppTheme.pinkPurpleGradient,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: const Icon(Icons.album_rounded,
                  color: Colors.white, size: 26),
            ),
            title: Text(
              album,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${tracks.length} треков',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            onTap: () {
              player.playFromPlaylist(tracks, 0);
            },
          ),
        );
      },
    );
  }

  Widget _buildFavoriteList(PlayerProvider player) {
    final query = _searchQuery;
    final favs = player.favoriteTracks
        .where((t) =>
            t.title.toLowerCase().contains(query) ||
            t.artist.toLowerCase().contains(query))
        .toList();

    if (favs.isEmpty) {
      return _buildEmptyState(
        'Нет избранных треков',
        Icons.favorite_border_rounded,
        subtitle: 'Нажимайте на сердечко у треков, чтобы добавить их сюда.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      itemCount: favs.length,
      itemBuilder: (context, index) {
        final track = favs[index];
        final isCurrent = player.currentTrack?.id == track.id;

        return TrackTile(
          track: track,
          isPlaying: isCurrent && player.isPlaying,
          isCurrent: isCurrent,
          onTap: () {
            if (favs.length > 1) {
              player.playFromPlaylist(favs, index);
            } else {
              player.playTrack(track);
            }
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String text, IconData icon,
      {String? subtitle}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.textMuted, size: 56),
          const SizedBox(height: 16),
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildSortItem(
      SortOrder order, SortOrder current, String label) {
    return PopupMenuItem(
      value: order.name,
      child: Row(
        children: [
          Icon(
            current == order
                ? Icons.check_circle_rounded
                : Icons.circle_outlined,
            color: current == order ? AppTheme.accent : AppTheme.textMuted,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}