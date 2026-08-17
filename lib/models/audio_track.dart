class AudioTrack {
  final int id;
  final String title;
  final String artist;
  final String? album;
  final String uri;
  final int duration; // in milliseconds
  final int? size; // in bytes
  final int? dateAdded;
  final String? data; // file path
  final int? albumId;
  final bool isFavorite;

  AudioTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    required this.uri,
    required this.duration,
    this.size,
    this.dateAdded,
    this.data,
    this.albumId,
    this.isFavorite = false,
  });

  String get formattedDuration => formatDuration(duration);

  static String formatDuration(int milliseconds) {
    if (milliseconds <= 0) return '0:00';
    final totalSeconds = (milliseconds / 1000).floor();
    final minutes = (totalSeconds / 60).floor();
    final seconds = totalSeconds % 60;
    if (minutes >= 60) {
      final hours = (minutes / 60).floor();
      final remMinutes = minutes % 60;
      return '$hours:${remMinutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (size == null || size! <= 0) return '';
    final mb = size! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} МБ';
  }

  AudioTrack copyWith({
    int? id,
    String? title,
    String? artist,
    String? album,
    String? uri,
    int? duration,
    int? size,
    int? dateAdded,
    String? data,
    int? albumId,
    bool? isFavorite,
  }) {
    return AudioTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      uri: uri ?? this.uri,
      duration: duration ?? this.duration,
      size: size ?? this.size,
      dateAdded: dateAdded ?? this.dateAdded,
      data: data ?? this.data,
      albumId: albumId ?? this.albumId,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
