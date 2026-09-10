import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/audio_track.dart';
import '../../providers/player_provider.dart';
import '../../screens/artist_detail_screen.dart';
import '../../screens/playlist_detail_screen.dart';
import '../../ui/theme.dart';
import '../../widgets/cached_artwork.dart';
import '../../widgets/collection_cards.dart';
import '../../widgets/neon_snack.dart';
import '../../widgets/swipe_reveal.dart';
import '../../widgets/track_actions_sheet.dart';
import '../../models/custom_playlist.dart';
import '../../widgets/track_tile.dart';
import 'category_tab.dart';
import 'music_dna_tab.dart';
import '../../core/debug_log.dart';

/// Shared library content: search, 6 tabs (tracks, playlists, albums,
/// artists, folders, favorites), sort, grid toggle, multi-select.
/// Used by both the simple and the 3D cover flow home screens.
class LibraryTabs extends StatefulWidget {
  final bool threeD;

  /// Внешний контроллер (для нижней навигации). Если задан — созданием
  /// и dispose занимается владелец, TabBar можно скрыть через [showTabBar].
  final TabController? controller;
  final bool showTabBar;

  /// Neon-скин: тёмные полупрозрачные поля/карточки вместо фиолетовых,
  /// чтобы список визуально совпадал со сценой плеера и мини-плеером.
  final bool neon;

  const LibraryTabs({
    super.key,
    this.threeD = false,
    this.controller,
    this.showTabBar = true,
    this.neon = false,
  });

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
    _tabController =
        widget.controller ?? TabController(length: 9, vsync: this);
    _tabController.addListener(_onTabChanged);
    _requestPermission();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    if (widget.controller == null) {
      _tabController.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    final player = context.read<PlayerProvider>();
    await player.ensureNotificationPermission();
    if (!player.hasLibrary) {
      await player.requestPermission();
    }
    if (!mounted) return;
    setState(() {
      _permissionDenied = player.allTracks.isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    DebugLog.rebuild('LibraryTabs');
    final player = context.watch<PlayerProvider>();

    return Column(
      children: [
        _buildHeaderRow(player),
        if (widget.showTabBar)
          TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.accent,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 3,
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Треки', icon: Icon(Icons.music_note_rounded, size: 18)),
            Tab(
              text: 'Плейлисты',
              icon: Icon(Icons.queue_music_rounded, size: 18),
            ),
            Tab(text: 'Альбомы', icon: Icon(Icons.album_rounded, size: 18)),
            Tab(
              text: 'Исполнители',
              icon: Icon(Icons.mic_external_on_rounded, size: 18),
            ),
            Tab(text: 'Папки', icon: Icon(Icons.folder_rounded, size: 18)),
            Tab(
              text: 'Избранное',
              icon: Icon(Icons.favorite_rounded, size: 18),
            ),
            Tab(text: 'История', icon: Icon(Icons.history_rounded, size: 18)),
            Tab(text: 'DNA', icon: Icon(Icons.fingerprint_rounded, size: 18)),
            Tab(
              text: 'Категории',
              icon: Icon(Icons.category_rounded, size: 18),
            ),
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
                    const MusicDnaTab(),
                    const CategoryTab(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow(PlayerProvider player) {
    final neon = widget.neon;
    final fieldRadius = neon ? 14.0 : 12.0;
    final fieldFill = neon ? const Color(0x14FFFFFF) : AppTheme.surfaceLight;
    final fieldText = neon ? Colors.white : AppTheme.textPrimary;
    final fieldHint = neon ? Colors.white38 : AppTheme.textMuted;
    final fieldBorderSide = neon
        ? const BorderSide(color: Color(0x24FFFFFF))
        : BorderSide.none;

    if (_selectionMode) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 6, 2),
        child: Row(
          children: [
            Text(
              '${_selectedIds.length} выбрано',
              style: TextStyle(
                color: AppTheme.accentLight,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                Icons.playlist_add_rounded,
                color: AppTheme.accentGreen,
              ),
              onPressed: _pickPlaylistForSelected,
              tooltip: 'В плейлист',
            ),
            IconButton(
              icon: Icon(Icons.favorite_rounded, color: AppTheme.accentPink),
              onPressed: _addSelectedToFavorites,
              tooltip: 'В избранное',
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.accentPink,
              ),
              onPressed: _confirmDeleteSelected,
              tooltip: 'Удалить',
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, color: AppTheme.textSecondary),
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
              style: TextStyle(color: fieldText, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Поиск...',
                hintStyle: TextStyle(color: fieldHint),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: fieldHint,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: fieldHint,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: fieldFill,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(fieldRadius),
                  borderSide: fieldBorderSide,
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
                  color: neon ? Colors.white54 : AppTheme.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _albumGridView = !_albumGridView),
                tooltip: _albumGridView ? 'Списком' : 'Сеткой',
              ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.sort_rounded,
                color: neon ? Colors.white54 : AppTheme.textSecondary,
              ),
              color: neon ? const Color(0xFF141622) : AppTheme.surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: neon ? const Color(0x24FFFFFF) : AppTheme.cardBorder,
                ),
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
                _buildSortItem(
                  SortOrder.title,
                  player.sortOrder,
                  'По названию',
                ),
                _buildSortItem(
                  SortOrder.artist,
                  player.sortOrder,
                  'По исполнителю',
                ),
                _buildSortItem(
                  SortOrder.dateAddedNew,
                  player.sortOrder,
                  'По дате добавления (новые)',
                ),
                _buildSortItem(
                  SortOrder.dateAddedOld,
                  player.sortOrder,
                  'По дате добавления (старые)',
                ),
                _buildSortItem(
                  SortOrder.duration,
                  player.sortOrder,
                  'По длительности',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.accent),
          const SizedBox(height: 16),
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
              child: Icon(
                Icons.music_off_rounded,
                color: AppTheme.textSecondary,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Нет доступа к музыке',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
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
                  horizontal: 24,
                  vertical: 14,
                ),
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

  List<SwipeAction> _quickActions(PlayerProvider player, AudioTrack track) {
    void snack(String msg, {IconData icon = Icons.check_rounded}) {
      showNeonSnack(context, msg, icon: icon, accent: AppTheme.accentCyan);
    }

    return [
      SwipeAction(
        icon: Icons.playlist_play_rounded,
        color: AppTheme.accentCyan,
        tooltip: 'Играть следующим',
        label: 'В очередь',
        onTap: () {
          player.addToQueueNext(track);
          snack(
            'В очередь: ${track.title}',
            icon: Icons.playlist_play_rounded,
          );
        },
      ),
      SwipeAction(
        icon: player.isFavorite(track.id)
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        color: AppTheme.accentPink,
        tooltip: 'В избранное',
        label: 'Избранное',
        onTap: () => player.toggleFavorite(track),
      ),
      SwipeAction(
        icon: Icons.do_not_disturb_on_rounded,
        color: AppTheme.accentGreen,
        tooltip: 'Не хочу сейчас',
        label: 'Скрыть',
        onTap: () {
          player.toggleNotNow(track);
          snack(
            'Скрыто на неделю: ${track.title}',
            icon: Icons.do_not_disturb_on_rounded,
          );
        },
      ),
    ];
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

        return SwipeReveal(
          actions: _selectionMode ? const [] : _quickActions(player, track),
          child: TrackTile(
            track: track,
            isPlaying: isCurrent && player.isPlaying,
            isCurrent: isCurrent,
            selected: _selectedIds.contains(track.id),
            threeD: widget.threeD,
            neon: widget.neon,
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
          ),
        );
      },
    );
  }

  int _playlistSort = 0; // 0 имя, 1 новые, 2 старые, 3 треков
  static const _playlistSortNames = ['По имени', 'Сначала новые', 'Сначала старые', 'По трекам'];

  Widget _buildPlaylistList(PlayerProvider player) {
    final query = _searchQuery.toLowerCase();
    final playlists = player.playlists
        .where((p) => p.name.toLowerCase().contains(query))
        .toList();
    switch (_playlistSort) {
      case 1:
        playlists.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 2:
        playlists.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 3:
        playlists.sort(
          (a, b) => b.trackIds.length.compareTo(a.trackIds.length),
        );
        break;
      default:
        playlists.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }

    final items = <_PlaylistItem>[];

    if ('недавно добавленные'.contains(query)) {
      items.add(
        _PlaylistItem(
          id: 'smart_added',
          name: 'Недавно добавленные',
          count: player.smartRecentlyAdded.length,
          icon: Icons.fiber_new_rounded,
          gradient: AppTheme.cyanGreenGradient,
          artTrackId: player.smartRecentlyAdded.isNotEmpty
              ? player.smartRecentlyAdded.first.id
              : null,
          onPlay: () {
            final t = player.smartRecentlyAdded;
            if (t.isNotEmpty) player.playFromPlaylist(t, 0);
          },
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              settings: const RouteSettings(name: 'PlaylistDetail'),
              builder: (_) =>
                  const PlaylistDetailScreen(playlistId: 'smart_added'),
            ),
          ),
        ),
      );
    }

    if ('недавно сыгранные'.contains(query)) {
      items.add(
        _PlaylistItem(
          id: 'smart_played',
          name: 'Недавно сыгранные',
          count: player.smartRecentlyPlayed.length,
          icon: Icons.history_toggle_off_rounded,
          gradient: AppTheme.primaryGradient,
          artTrackId: player.smartRecentlyPlayed.isNotEmpty
              ? player.smartRecentlyPlayed.first.id
              : null,
          onPlay: () {
            final t = player.smartRecentlyPlayed;
            if (t.isNotEmpty) player.playFromPlaylist(t, 0);
          },
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              settings: const RouteSettings(name: 'PlaylistDetail'),
              builder: (_) =>
                  const PlaylistDetailScreen(playlistId: 'smart_played'),
            ),
          ),
        ),
      );
    }

    if ('часто прослушиваемые'.contains(query)) {
      items.add(
        _PlaylistItem(
          id: 'smart_most',
          name: 'Часто прослушиваемые',
          count: player.smartMostPlayed.length,
          icon: Icons.auto_awesome_rounded,
          gradient: AppTheme.pinkPurpleGradient,
          artTrackId: player.smartMostPlayed.isNotEmpty
              ? player.smartMostPlayed.first.id
              : null,
          onPlay: () {
            final t = player.smartMostPlayed;
            if (t.isNotEmpty) player.playFromPlaylist(t, 0);
          },
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              settings: const RouteSettings(name: 'PlaylistDetail'),
              builder: (_) =>
                  const PlaylistDetailScreen(playlistId: 'smart_most'),
            ),
          ),
        ),
      );
    }

    for (final pl in playlists) {
      final pts = player.tracksOfPlaylist(pl);
      items.add(
        _PlaylistItem(
          id: pl.id,
          name: pl.name,
          count: pl.trackIds.length,
          icon: Icons.queue_music_rounded,
          gradient: AppTheme.cyanGreenGradient,
          artTrackId: pts.isNotEmpty ? pts.first.id : null,
          onPlay: () {
            if (pts.isNotEmpty) player.playFromPlaylist(pts, 0);
          },
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              settings: const RouteSettings(name: 'PlaylistDetail'),
              builder: (_) => PlaylistDetailScreen(playlistId: pl.id),
            ),
          ),
          isCustom: true,
          custom: pl,
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildPlaylistHeader()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildPlaylistCard(player, items[index]),
              childCount: items.length,
            ),
            gridDelegate:
                const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  childAspectRatio: 0.86,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Плейлисты',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ваши музыкальные коллекции',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withValues(
                    alpha: AppTheme.accent.a * 0.4,
                  ),
                  blurRadius: 12,
                ),
              ],
            ),
            child: IconButton(
              onPressed: _createPlaylistDialog,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              tooltip: 'Создать плейлист',
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: PopupMenuButton<int>(
              icon: Icon(
                Icons.sort_rounded,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              tooltip: 'Сортировка',
              color: AppTheme.surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: AppTheme.cardBorder),
              ),
              onSelected: (v) => setState(() => _playlistSort = v),
              itemBuilder: (context) => [
                for (var i = 0; i < _playlistSortNames.length; i++)
                  PopupMenuItem(
                    value: i,
                    child: Row(
                      children: [
                        Icon(
                          _playlistSort == i
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: _playlistSort == i
                              ? AppTheme.accent
                              : AppTheme.textMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(_playlistSortNames[i]),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistCard(PlayerProvider player, _PlaylistItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: Colors.black.a * 0.3,
              ),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.artTrackId != null)
                CachedArtwork(
                  trackId: item.artTrackId!,
                  width: 220,
                  height: 256,
                  radius: 0,
                )
              else
                Container(
                  decoration: BoxDecoration(gradient: item.gradient),
                  child: Center(
                    child: Icon(
                      item.icon,
                      color: Colors.white.withValues(
                        alpha: Colors.white.a * 0.85,
                      ),
                      size: 48,
                    ),
                  ),
                ),
              // Затемнение снизу для читаемости.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0xCC000000),
                    ],
                    stops: [0.45, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 8,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: item.gradient,
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: Colors.white.a * 0.5,
                          ),
                        ),
                      ),
                      child: Icon(
                        item.icon,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${item.count} ${_pluralTracks(item.count)}',
                            style: TextStyle(
                              color: Colors.white.withValues(
                                alpha: Colors.white.a * 0.7,
                              ),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: item.onPlay,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(
                            alpha: Colors.white.a * 0.18,
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: Colors.white.a * 0.45,
                            ),
                          ),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
          side: BorderSide(color: AppTheme.cardBorder),
        ),
        title: Text(
          'Новый плейлист',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Название плейлиста',
            hintStyle: TextStyle(color: AppTheme.textMuted),
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
            child: Text(
              'Отмена',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(
              'Создать',
              style: TextStyle(
                color: AppTheme.accentLight,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty && mounted) {
      context.read<PlayerProvider>().createPlaylist(name);
    }
    // Освобождаем контроллер после закрытия диалога.
    controller.dispose();
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
    final artists = player.artists
        .where((a) => a.toLowerCase().contains(query))
        .toList();

    if (artists.isEmpty) {
      return _buildEmptyState(
        'Исполнители не найдены',
        Icons.person_off_rounded,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        final tracks = player.allTracks
            .where((t) => t.artist == artist)
            .toList();
        final albumCount = tracks
            .map((t) => t.album ?? '')
            .where((a) => a.isNotEmpty)
            .toSet()
            .length;

        return ArtistRow(
          artist: artist,
          tracks: tracks,
          albumCount: albumCount,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                settings: const RouteSettings(name: 'ArtistDetail'),
                builder: (_) => ArtistDetailScreen(artist: artist),
              ),
            );
          },
          onPlay: () {
            if (tracks.isNotEmpty) {
              player.playFromPlaylist(tracks, 0);
            }
          },
        );
      },
    );
  }

  Widget _buildFolderList(PlayerProvider player) {
    final query = _searchQuery.toLowerCase();
    final folders = player.folders
        .where((f) => f.toLowerCase().contains(query))
        .toList();

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
              decoration: BoxDecoration(
                gradient: AppTheme.cyanGreenGradient,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
              child: const Icon(
                Icons.folder_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            title: Text(
              name,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${tracks.length} ${_pluralTracks(tracks.length)}',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            trailing: IconButton(
              icon: Icon(
                Icons.play_circle_fill_rounded,
                color: AppTheme.accent,
              ),
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

  int _albumFilter = 0; // 0 все, 1 недавние, 2 популярные, 3 A-Z
  static const _albumFilterNames = ['Все', 'Недавние', 'Популярные', 'A–Z'];

  Widget _buildAlbumList(PlayerProvider player) {
    final query = _searchQuery.toLowerCase();
    final albums = player.albums
        .where((a) => a.toLowerCase().contains(query))
        .toList();

    if (albums.isEmpty) {
      return _buildEmptyState('Альбомы не найдены', Icons.album_outlined);
    }

    final entries = player.albumEntries
        .where((e) => e.album.toLowerCase().contains(query))
        .toList();
    final counts = player.playCounts;
    switch (_albumFilter) {
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
      case 2:
        int plays(List<AudioTrack> ts) =>
            ts.fold<int>(0, (p, t) => p + (counts[t.id] ?? 0));
        entries.sort((a, b) => plays(b.tracks).compareTo(plays(a.tracks)));
      case 3:
        entries.sort(
          (a, b) => a.album.toLowerCase().compareTo(b.album.toLowerCase()),
        );
    }

    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: _albumFilterNames.length,
            itemBuilder: (context, i) {
              final selected = _albumFilter == i;
              return ChoiceChip(
                label: Text(_albumFilterNames[i]),
                selected: selected,
                onSelected: (_) => setState(() => _albumFilter = i),
                selectedColor: AppTheme.accent.withValues(
                  alpha: AppTheme.accent.a * 0.2,
                ),
                backgroundColor: AppTheme.surfaceLight,
                labelStyle: TextStyle(
                  color: selected
                      ? AppTheme.accentLight
                      : AppTheme.textSecondary,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                side: BorderSide(
                  color: selected ? AppTheme.accent : Colors.transparent,
                ),
              );
            },
          ),
        ),
        Expanded(
          child: _albumGridView
              ? GridView.builder(
                  padding: const EdgeInsets.all(14),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final e = entries[index];
                    return _buildAlbumCard(player, e.album, e.tracks);
                  },
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 2, bottom: 16),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final e = entries[index];
                    final artist = e.tracks.isNotEmpty
                        ? e.tracks.first.artist
                        : '';
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        leading: e.tracks.isNotEmpty
                            ? CachedArtwork(
                                trackId: e.tracks.first.id,
                                width: 44,
                                height: 44,
                                radius: 10,
                              )
                            : Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.pinkPurpleGradient,
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(10),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.album_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                        title: Text(
                          e.album,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          artist.isEmpty
                              ? '${e.tracks.length} треков'
                              : '$artist • ${e.tracks.length} треков',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: AlbumMenu(
                          tracks: e.tracks,
                          iconColor: AppTheme.textSecondary,
                        ),
                        onTap: () {
                          player.playFromPlaylist(e.tracks, 0);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAlbumCard(
    PlayerProvider player,
    String album,
    List<AudioTrack> tracks,
  ) {
    return AlbumCard(player: player, album: album, tracks: tracks);
  }

  Widget _buildFavoriteList(PlayerProvider player) {
    final query = _searchQuery;
    final favs = player.favoriteTracks
        .where(
          (t) =>
              t.title.toLowerCase().contains(query) ||
              t.artist.toLowerCase().contains(query),
        )
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

        return SwipeReveal(
          actions: _quickActions(player, track),
          child: TrackTile(
            track: track,
            isPlaying: isCurrent && player.isPlaying,
            isCurrent: isCurrent,
            threeD: widget.threeD,
            neon: widget.neon,
            onTap: () {
              if (favs.length > 1) {
                player.playFromPlaylist(favs, index);
              } else {
                player.playTrack(track);
              }
            },
            onLongPress: () => TrackActionsSheet.show(context, track),
          ),
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
        .where(
          (e) =>
              e.track.title.toLowerCase().contains(query) ||
              e.track.artist.toLowerCase().contains(query),
        )
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
    Widget header(
      String title,
      List<({AudioTrack track, DateTime time})> items,
      PlayerProvider p,
      int startIndex,
    ) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Text(
              title,
              style: TextStyle(
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
            return SwipeReveal(
              actions: _quickActions(p, track),
              child: TrackTile(
                track: track,
                isPlaying: isCurrent && p.isPlaying,
                isCurrent: isCurrent,
                threeD: widget.threeD,
                neon: widget.neon,
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
                onLongPress: () => TrackActionsSheet.show(context, track),
              ),
            );
          }),
        ],
      );
    }

    final todayItems = entries.where((e) => e.time.isAfter(today)).toList();
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
      final byDay = <DateTime, List<({AudioTrack track, DateTime time})>>{};
      for (final e in earlierItems) {
        final d = DateTime(e.time.year, e.time.month, e.time.day);
        byDay.putIfAbsent(d, () => []).add(e);
      }
      final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
      for (final d in days) {
        children.add(header(_dayLabel(d), byDay[d]!, player, 0));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _buildJourneyCard(player, entries),
        _buildMomentsCard(player),
        ...children,
        Center(
          child: TextButton.icon(
            onPressed: player.clearHistory,
            icon: Icon(
              Icons.delete_sweep_outlined,
              color: AppTheme.textMuted,
              size: 18,
            ),
            label: Text(
              'Очистить историю',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  String _dayLabel(DateTime d) {
    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 2) return 'Позавчера';
    if (d.year == now.year) return '${d.day} ${months[d.month - 1]}';
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Widget _buildMomentsCard(PlayerProvider player) {
    final bookmarks = player.allBookmarks;
    if (bookmarks.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bookmark_rounded,
                color: AppTheme.accentLight,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Мои моменты',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...bookmarks.take(10).map((b) {
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.bookmark_outline_rounded,
                color: AppTheme.accentLight,
                size: 18,
              ),
              title: Text(
                b.track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              ),
              subtitle: Text(
                b.track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
              trailing: Text(
                AudioTrack.formatDuration(b.positionMs),
                style: TextStyle(
                  color: AppTheme.accentLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () {
                player.playTrack(b.track);
                player.seek(Duration(milliseconds: b.positionMs));
              },
              onLongPress: () =>
                  player.removeBookmark(b.track.id, b.positionMs),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildJourneyCard(
    PlayerProvider player,
    List<({AudioTrack track, DateTime time})> all,
  ) {
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
        : topArtistToday.entries
              .reduce((a, b) => a.value >= b.value ? a : b)
              .key;
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
            color: Colors.white.withValues(alpha: Colors.white.a * (0.05)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
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
            AppTheme.accent.withValues(alpha: AppTheme.accent.a * (0.16)),
            AppTheme.accentLight.withValues(
              alpha: AppTheme.accentLight.a * (0.12),
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: AppTheme.accent.a * (0.25)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights_rounded,
                color: AppTheme.accentLight,
                size: 18,
              ),
              const SizedBox(width: 8),
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
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
              Text(
                '${fmt(today.length)} сегодня',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
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
    return player.allTracks.where((t) => _selectedIds.contains(t.id)).toList();
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
          side: BorderSide(color: AppTheme.cardBorder),
        ),
        title: Text(
          'Удалить ${selected.length} ${_pluralTracks(selected.length)}?',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Файлы будут удалены с устройства. Это действие нельзя отменить.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Отмена',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Удалить',
              style: TextStyle(
                color: AppTheme.accentPink,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    var deleted = 0;
    for (final t in selected) {
      if (await player.deleteTrack(t)) deleted++;
    }
    if (!mounted) return;
    _exitSelection();
    showNeonSnack(
      context,
      deleted > 0
          ? 'Удалено $deleted ${_pluralTracks(deleted)}'
          : 'Не удалось удалить треки',
      icon: Icons.delete_outline_rounded,
      accent: AppTheme.accentPink,
      error: deleted == 0,
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
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Divider(height: 1, color: AppTheme.cardBorder),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in player.playlists)
                    ListTile(
                      leading: Icon(
                        Icons.queue_music_rounded,
                        color: AppTheme.accentCyan,
                      ),
                      title: Text(
                        p.name,
                        style: TextStyle(color: AppTheme.textPrimary),
                      ),
                      trailing: Text(
                        '${p.trackIds.length}',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      onTap: () => Navigator.pop(sheetCtx, p.id),
                    ),
                  ListTile(
                    leading: Icon(
                      Icons.add_rounded,
                      color: AppTheme.accentGreen,
                    ),
                    title: Text(
                      'Новый плейлист',
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                    onTap: () async {
                      final name = await _promptPlaylistName(sheetCtx);
                      if (name != null && name.isNotEmpty) {
                        // createPlaylist возвращает id созданного плейлиста —
                        // надёжнее, чем playlists.last (упадёт на пустом списке
                        // и завязан на порядок элементов).
                        final created = await player.createPlaylist(name);
                        if (created != null && sheetCtx.mounted) {
                          Navigator.pop(sheetCtx, created);
                        }
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selected.length} ${_pluralTracks(selected.length)} добавлено в плейлист',
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<String?> _promptPlaylistName(BuildContext ctx) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.cardBorder),
        ),
        title: Text(
          'Новый плейлист',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Название плейлиста',
            hintStyle: TextStyle(color: AppTheme.textMuted),
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
            child: Text(
              'Отмена',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, controller.text.trim()),
            child: Text(
              'Создать',
              style: TextStyle(
                color: AppTheme.accentLight,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      );
    } finally {
      // Освобождаем контроллер: диалог закрыт, поле больше не используется.
      controller.dispose();
    }
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
            style: TextStyle(
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
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildSortItem(
    SortOrder order,
    SortOrder current,
    String label,
  ) {
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

class _PlaylistItem {
  final String id;
  final String name;
  final int count;
  final IconData icon;
  final LinearGradient gradient;

  /// id трека для обложки карточки (первый трек), null — градиент+иконка.
  final int? artTrackId;
  final VoidCallback onPlay;
  final VoidCallback onTap;
  final bool isCustom;
  final CustomPlaylist? custom;

  _PlaylistItem({
    required this.id,
    required this.name,
    required this.count,
    required this.icon,
    required this.gradient,
    required this.onPlay,
    required this.onTap,
    this.artTrackId,
    this.isCustom = false,
    this.custom,
  });
}
