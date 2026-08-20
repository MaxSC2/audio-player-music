import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/audio_track.dart';
import '../../providers/player_provider.dart';
import '../../screens/playlist_detail_screen.dart';
import '../../ui/theme.dart';
import '../../widgets/cached_artwork.dart';
import '../../widgets/track_tile.dart';

/// Shared library content: search, 6 tabs (tracks, playlists, albums,
/// artists, folders, favorites), sort, grid toggle, multi-select.
/// Used by both the simple and the 3D cover flow home screens.
class LibraryTabs extends StatefulWidget {
  final bool threeD;

  const LibraryTabs({super.key, this.threeD = false});

  @override
  State<LibraryTabs> createState() => _LibraryTabsState();
}

class _LibraryTabsState extends State<LibraryTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _permissionDenied = false;
  bool _selectionMode = false;
  final Set<int> _selectedIds = <int>{};
  bool _albumGridView = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _requestPermission();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return Column(
      children: [
        _buildHeaderRow(player),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.accent,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 3,
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Треки', icon: Icon(Icons.music_note_rounded, size: 18)),
            Tab(
                text: 'Плейлисты',
                icon: Icon(Icons.queue_music_rounded, size: 18)),
            Tab(text: 'Альбомы', icon: Icon(Icons.album_rounded, size: 18)),
            Tab(
                text: 'Исполнители',
                icon: Icon(Icons.mic_external_on_rounded, size: 18)),
            Tab(text: 'Папки', icon: Icon(Icons.folder_rounded, size: 18)),
            Tab(
                text: 'Избранное',
                icon: Icon(Icons.favorite_rounded, size: 18)),
            Tab(
                text: 'История',
                icon: Icon(Icons.history_rounded, size: 18)),
          ],
        ),
        Expanded(
          child: _permissionDenied && player.allTracks.isEmpty
              ? _buildPermissionDenied()
              : player.allTracks.isEmpty
                  ? _buildLoading()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTrackList(player),
                        _buildPlaylistList(player),
                        _buildAlbumList(player),
                        _buildArtistList(player),
                        _buildFolderList(player),
                        _buildFavoriteList(player),
                        _buildHistoryList(player),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow(PlayerProvider player) {
    if (_selectionMode) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 6, 2),
        child: Row(
          children: [
            Text(
              '${_selectedIds.length} выбрано',
              style: const TextStyle(
                color: AppTheme.accentLight,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.playlist_add_rounded,
                  color: AppTheme.accentGreen),
              onPressed: _pickPlaylistForSelected,
              tooltip: 'В плейлист',
            ),
            IconButton(
              icon: const Icon(Icons.favorite_rounded,
                  color: AppTheme.accentPink),
              onPressed: _addSelectedToFavorites,
              tooltip: 'В избранное',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.accentPink),
              onPressed: _confirmDeleteSelected,
              tooltip: 'Удалить',
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: AppTheme.textSecondary),
              onPressed: _exitSelection,
              tooltip: 'Отмена',
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 2),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim();
                });
              },
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Поиск...',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppTheme.textMuted, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: AppTheme.textMuted, size: 18),
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
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (player.allTracks.isNotEmpty) ...[
            if (_tabController.index == 2)
              IconButton(
                icon: Icon(
                  _albumGridView
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () => setState(() => _albumGridView = !_albumGridView),
                tooltip: _albumGridView ? 'Списком' : 'Сеткой',
              ),
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
                    break;
                  case 'artist':
                    player.sortOrder = SortOrder.artist;
                    break;
                  case 'dateAddedNew':
                    player.sortOrder = SortOrder.dateAddedNew;
                    break;
                  case 'dateAddedOld':
                    player.sortOrder = SortOrder.dateAddedOld;
                    break;
                  case 'duration':
                    player.sortOrder = SortOrder.duration;
                    break;
                }
              },
              itemBuilder: (context) => [
                _buildSortItem(SortOrder.title, player.sortOrder, 'По названию'),
                _buildSortItem(
                    SortOrder.artist, player.sortOrder, 'По исполнителю'),
                _buildSortItem(SortOrder.dateAddedNew, player.sortOrder,
                    'По дате добавления (новые)'),
                _buildSortItem(SortOrder.dateAddedOld, player.sortOrder,
                    'По дате добавления (старые)'),
                _buildSortItem(
                    SortOrder.duration, player.sortOrder, 'По длительности'),
              ],
            ),
          ],
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
          selected: _selectedIds.contains(track.id),
          threeD: widget.threeD,
          onTap: () {
            if (_selectionMode) {
              _toggleSelection(track);
            } else if (playlist.length > 1) {
              player.playFromPlaylist(playlist, index);
            } else {
              player.playTrack(track);
            }
          },
          onLongPress: () {
            if (_selectionMode) {
              _toggleSelection(track);
            } else {
              setState(() {
                _selectionMode = true;
                _selectedIds.add(track.id);
              });
            }
          },
        );
      },
    );
  }

  Widget _buildPlaylistList(PlayerProvider player) {
    final query = _searchQuery.toLowerCase();
    final playlists = player.playlists
        .where((p) => p.name.toLowerCase().contains(query))
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      itemCount: playlists.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildCreatePlaylistTile();
        }
        final playlist = playlists[index - 1];
        final trackCount = playlist.trackIds.length;

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
                gradient: AppTheme.cyanGreenGradient,
              ),
              child: const Icon(Icons.queue_music_rounded,
                  color: Colors.white, size: 24),
            ),
            title: Text(
              playlist.name,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '$trackCount ${_pluralTracks(trackCount)}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.play_circle_fill_rounded,
                  color: AppTheme.accent),
              onPressed: () {
                final tracks = player.tracksOfPlaylist(playlist);
                if (tracks.isNotEmpty) {
                  player.playFromPlaylist(tracks, 0);
                }
              },
              tooltip: 'Слушать',
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PlaylistDetailScreen(playlistId: playlist.id),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCreatePlaylistTile() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
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
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
        ),
        title: const Text(
          'Создать плейлист',
          style: TextStyle(
            color: AppTheme.accentLight,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: const Text(
          'Соберите свою подборку',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        onTap: () => _createPlaylistDialog(),
      ),
    );
  }

  Future<void> _createPlaylistDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.cardBorder),
        ),
        title: const Text(
          'Новый плейлист',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Название плейлиста',
            hintStyle: const TextStyle(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Создать',
                style: TextStyle(
                    color: AppTheme.accentLight,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty && context.mounted) {
      context.read<PlayerProvider>().createPlaylist(name);
    }
  }

  String _pluralTracks(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return 'трек';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'трека';
    }
    return 'треков';
  }

  Widget _buildArtistList(PlayerProvider player) {
    final query = _searchQuery.toLowerCase();
    final artists =
        player.artists.where((a) => a.toLowerCase().contains(query)).toList();

    if (artists.isEmpty) {
      return _buildEmptyState(
          'Исполнители не найдены', Icons.person_off_rounded);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        final tracks =
            player.allTracks.where((t) => t.artist == artist).toList();

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

  Widget _buildFolderList(PlayerProvider player) {
    final query = _searchQuery.toLowerCase();
    final folders =
        player.folders.where((f) => f.toLowerCase().contains(query)).toList();

    if (folders.isEmpty) {
      return _buildEmptyState('Папки не найдены', Icons.folder_off_rounded);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        final tracks = player.tracksInFolder(folder);
        final parts = folder.split('/');
        final name = parts.isNotEmpty ? parts.last : folder;

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
                gradient: AppTheme.cyanGreenGradient,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: const Icon(Icons.folder_rounded,
                  color: Colors.white, size: 26),
            ),
            title: Text(
              name,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${tracks.length} ${_pluralTracks(tracks.length)}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.play_circle_fill_rounded,
                  color: AppTheme.accent),
              onPressed: () {
                if (tracks.isNotEmpty) {
                  player.playFromPlaylist(tracks, 0);
                }
              },
              tooltip: 'Слушать',
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
    final albums =
        player.albums.where((a) => a.toLowerCase().contains(query)).toList();

    if (albums.isEmpty) {
      return _buildEmptyState('Альбомы не найдены', Icons.album_outlined);
    }

    if (_albumGridView) {
      return LayoutBuilder(
        builder: (context, constraints) {
          const pad = 14.0;
          const spacing = 12.0;
          final cellW = (constraints.maxWidth - pad * 2 - spacing) / 2;
          return GridView.builder(
            padding: const EdgeInsets.all(pad),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.74,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              final tracks = player.allTracks
                  .where((t) => t.album == album)
                  .toList();
              return _buildAlbumCard(player, album, tracks, cellW);
            },
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        final tracks = player.allTracks
            .where((t) => t.album == album)
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

  Widget _buildAlbumCard(PlayerProvider player, String album,
      List<AudioTrack> tracks, double cellW) {
    return InkWell(
      onTap: () => player.playFromPlaylist(tracks, 0),
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CachedArtwork(
            trackId: tracks.first.id,
            width: cellW,
            height: cellW,
            radius: 18,
          ),
          const SizedBox(height: 8),
          Text(
            album,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${tracks.length} треков',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
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
          threeD: widget.threeD,
          onTap: () {
            if (favs.length > 1) {
              player.playFromPlaylist(favs, index);
            } else {
              player.playTrack(track);
            }
          },
          onLongPress: () => _showTrackActions(context, player, track),
        );
      },
    );
  }

  void _toggleSelection(AudioTrack track) {
    setState(() {
      if (!_selectedIds.add(track.id)) {
        _selectedIds.remove(track.id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      }
    });
  }

  Widget _buildHistoryList(PlayerProvider player) {
    final query = _searchQuery.toLowerCase();
    final entries = player.historyEntries
        .where((e) =>
            e.track.title.toLowerCase().contains(query) ||
            e.track.artist.toLowerCase().contains(query))
        .toList();

    if (entries.isEmpty) {
      return _buildEmptyState(
        'Нет истории',
        Icons.history_rounded,
        subtitle: 'Прослушанные треки появятся здесь.',
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    List<Widget> children = [];
    Widget header(String title, List<({AudioTrack track, DateTime time})> items,
        PlayerProvider p, int startIndex) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.accentLight,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          ...List.generate(items.length, (i) {
            final track = items[i].track;
            final isCurrent = p.currentTrack?.id == track.id;
            return TrackTile(
              track: track,
              isPlaying: isCurrent && p.isPlaying,
              isCurrent: isCurrent,
              threeD: widget.threeD,
              onTap: () {
                final ids = items.map((e) => e.track.id).toList();
                final idx = ids.indexOf(track.id);
                final list = items.map((e) => e.track).toList();
                if (list.length > 1) {
                  p.playFromPlaylist(list, idx);
                } else {
                  p.playTrack(track);
                }
              },
              onLongPress: () => _showTrackActions(context, p, track),
            );
          }),
        ],
      );
    }

    final todayItems = entries
        .where((e) => e.time.isAfter(today))
        .toList();
    final yesterdayItems = entries
        .where((e) => e.time.isAfter(yesterday) && !e.time.isAfter(today))
        .toList();
    final earlierItems = entries
        .where((e) => !e.time.isAfter(yesterday))
        .toList();

    if (todayItems.isNotEmpty) {
      children.add(header('Сегодня', todayItems, player, 0));
    }
    if (yesterdayItems.isNotEmpty) {
      children.add(header('Вчера', yesterdayItems, player, 0));
    }
    if (earlierItems.isNotEmpty) {
      children.add(header('Ранее', earlierItems, player, 0));
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _buildJourneyCard(player, entries),
        ...children,
        Center(
          child: TextButton.icon(
            onPressed: player.clearHistory,
            icon: const Icon(Icons.delete_sweep_outlined,
                color: AppTheme.textMuted, size: 18),
            label: const Text(
              'Очистить историю',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJourneyCard(
      PlayerProvider player, List<({AudioTrack track, DateTime time})> all) {
    if (all.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final today = all.where((e) => e.time.isAfter(todayStart)).toList();

    final playsToday = today.length;
    final uniqueToday = today.map((e) => e.track.id).toSet().length;
    final topArtistToday = <String, int>{};
    for (final e in today) {
      final a = e.track.artist;
      topArtistToday[a] = (topArtistToday[a] ?? 0) + 1;
    }
    final topArtist = topArtistToday.entries.isEmpty
        ? null
        : topArtistToday.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final totalPlays = all.length;

    String fmt(int n) {
      if (n >= 60) return '${(n / 60).floor()}ч ${n % 60}м';
      return '$n м';
    }

    Widget stat(String label, String value, IconData icon, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accent.withOpacity(0.16),
            AppTheme.accentLight.withOpacity(0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights_rounded, color: AppTheme.accentLight, size: 18),
              SizedBox(width: 8),
              Text(
                'Сегодня',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              stat(
                'Треков',
                '$playsToday',
                Icons.play_arrow_rounded,
                AppTheme.accentCyan,
              ),
              const SizedBox(width: 8),
              stat(
                'Уникальных',
                '$uniqueToday',
                Icons.music_note_rounded,
                AppTheme.accentGreen,
              ),
              const SizedBox(width: 8),
              stat(
                'Топ',
                topArtist ?? '—',
                Icons.person_rounded,
                AppTheme.accentPink,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Всего прослушиваний: $totalPlays',
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 11),
              ),
              Text(
                '${fmt(today.length)} сегодня',
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  List<AudioTrack> _selectedTracksFrom(PlayerProvider player) {
    return player.allTracks
        .where((t) => _selectedIds.contains(t.id))
        .toList();
  }

  void _addSelectedToFavorites() {
    final player = context.read<PlayerProvider>();
    final selected = _selectedTracksFrom(player);
    var added = 0;
    for (final t in selected) {
      if (!t.isFavorite) {
        player.toggleFavorite(t);
        added++;
      }
    }
    _exitSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added == selected.length
              ? '$added ${_pluralTracks(added)} добавлено в избранное'
              : 'Избранное обновлено',
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmDeleteSelected() async {
    final player = context.read<PlayerProvider>();
    final selected = _selectedTracksFrom(player);
    if (selected.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.cardBorder),
        ),
        title: Text(
          'Удалить ${selected.length} ${_pluralTracks(selected.length)}?',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Файлы будут удалены с устройства. Это действие нельзя отменить.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить',
                style: TextStyle(
                    color: AppTheme.accentPink,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    var deleted = 0;
    for (final t in selected) {
      if (await player.deleteTrack(t)) deleted++;
    }
    _exitSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted > 0
              ? 'Удалено $deleted ${_pluralTracks(deleted)}'
              : 'Не удалось удалить треки',
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickPlaylistForSelected() async {
    final player = context.read<PlayerProvider>();
    final selected = _selectedTracksFrom(player);
    if (selected.isEmpty) return;

    final playlistId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Добавить в плейлист · ${selected.length} треков',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1, color: AppTheme.cardBorder),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in player.playlists)
                    ListTile(
                      leading: const Icon(Icons.queue_music_rounded,
                          color: AppTheme.accentCyan),
                      title: Text(
                        p.name,
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                      trailing: Text(
                        '${p.trackIds.length}',
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                      onTap: () => Navigator.pop(sheetCtx, p.id),
                    ),
                  ListTile(
                    leading: const Icon(Icons.add_rounded,
                        color: AppTheme.accentGreen),
                    title: const Text(
                      'Новый плейлист',
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                    onTap: () async {
                      final name = await _promptPlaylistName(sheetCtx);
                      if (name != null && name.isNotEmpty) {
                        await player.createPlaylist(name);
                        final created = player.playlists.last.id;
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx, created);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (playlistId == null) return;
    for (final t in selected) {
      await player.addToPlaylist(playlistId, t);
    }
    _exitSelection();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${selected.length} ${_pluralTracks(selected.length)} добавлено в плейлист'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<String?> _promptPlaylistName(BuildContext ctx) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.cardBorder),
        ),
        title: const Text(
          'Новый плейлист',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Название плейлиста',
            hintStyle: const TextStyle(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Отмена',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, controller.text.trim()),
            child: const Text('Создать',
                style: TextStyle(
                    color: AppTheme.accentLight,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTrackActions(
      BuildContext context, PlayerProvider player, AudioTrack track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                track.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent),
              title: const Text('Удалить с устройства',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(sheetContext);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    backgroundColor: AppTheme.card,
                    title: const Text('Удалить трек?',
                        style: TextStyle(color: Colors.white)),
                    content: Text(
                      'Файл «${track.title}» будет удалён с устройства. Это действие нельзя отменить.',
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(dialogContext, false),
                        child: const Text('Отмена'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Удалить',
                            style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                final ok = await player.deleteTrack(track);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok
                          ? 'Трек удалён'
                          : 'Не удалось удалить трек'),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String text, IconData icon, {String? subtitle}) {
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