import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../models/audio_track.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';
import '../widgets/track_tile.dart';
import '../widgets/player_bar.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  List<AudioTrack> _tracks = [];
  bool _isLoading = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoad();
  }

  Future<void> _requestPermissionAndLoad() async {
    final status = await Permission.audio.request();
    
    if (status.isGranted) {
      setState(() {
        _hasPermission = true;
      });
      await _loadTracks();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTracks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      final tracks = songs
          .where((song) => song.duration != null && song.duration! > 5000)
          .map((song) => AudioTrack(
                id: song.id,
                title: song.title,
                artist: song.artist ?? 'Неизвестный',
                album: song.album,
                uri: song.uri ?? '',
                duration: song.duration ?? 0,
              ))
          .toList();

      setState(() {
        _tracks = tracks;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading tracks: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showFullPlayer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      transitionAnimationController: AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: Navigator.of(context),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => const FullPlayer(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    if (player.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(player.error!),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () => player.clearError(),
            ),
          ),
        );
        player.clearError();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Библиотека'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildContent(player),
          ),
          PlayerBar(onTap: _showFullPlayer),
        ],
      ),
    );
  }

  Widget _buildContent(PlayerProvider player) {
    if (!_hasPermission) {
      return _buildPermissionRequest();
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.accent),
            SizedBox(height: 16),
            Text(
              'Загрузка треков...',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.music_off,
              size: 64,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Треки не найдены',
              style: TextStyle(
                fontSize: 18,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Добавьте музыку в память устройства',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadTracks,
              icon: const Icon(Icons.refresh),
              label: const Text('Обновить'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (player.playlist.isEmpty) {
      player.setPlaylist(_tracks);
    }

    return ListView.builder(
      itemCount: _tracks.length,
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemBuilder: (context, index) {
        final track = _tracks[index];
        final isPlaying = player.currentTrack?.id == track.id;

        return TrackTile(
          track: track,
          isPlaying: isPlaying,
          onTap: () => player.playTrack(track),
        );
      },
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.folder_open,
              size: 80,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 24),
            const Text(
              'Доступ к музыке',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Для сканирования музыкальных файлов необходимо разрешение на доступ к аудио',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _requestPermissionAndLoad,
              icon: const Icon(Icons.check),
              label: const Text('Предоставить доступ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => openAppSettings(),
              child: const Text(
                'Настройки приложения',
                style: TextStyle(color: AppTheme.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
