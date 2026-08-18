import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/audio_track.dart';
import '../models/custom_playlist.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';
import '../widgets/player_bar.dart';
import '../widgets/track_tile.dart';
import 'player_screen.dart';
import 'playlist_detail_screen.dart';
import 'settings_screen.dart';

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
    _tabController = TabController(length: 6, vsync: this);
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
              child: const Text(
                'NeonWave',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            if (player.allTracks.isNotEmpty)
              Text(
                '${player.allTracks.length} ${_pluralTracks(player.allTracks.length)}',
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded,
                color: AppTheme.textSecondary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            tooltip: 'Настройки',
          ),
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
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.accent,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 3,
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Треки', icon: Icon(Icons.music_note_rounded, size: 18)),
            Tab(text: 'Плейлисты', icon: Icon(Icons.queue_music_rounded, size: 18)),
            Tab(text: 'Альбомы', icon: Icon(Icons.album_rounded, size: 18)),
            Tab(text: 'Исполнители', icon: Icon(Icons.mic_external_on_rounded, size: 18)),
            Tab(text: 'Папки', icon: Icon(Icons.folder_rounded, size: 18)),
            Tab(text: 'Избранное', icon: Icon(Icons.favorite_rounded, size: 18)),
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
                          _buildPlaylistList(player),
                          _buildAlbumList(player),
                          _buildArtistList(player),
                          _buildFolderList(player),
                          _buildFavoriteList(player),
                        ],
                      ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
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
          onLongPress: () => _showTrackActions(context, player, track),
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
          onLongPress: () => _showTrackActions(context, player, track),
        );
      },
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