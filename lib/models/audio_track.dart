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
    Object? id = _sentinel,
    Object? title = _sentinel,
    Object? artist = _sentinel,
    Object? album = _sentinel,
    Object? uri = _sentinel,
    Object? duration = _sentinel,
    Object? size = _sentinel,
    Object? dateAdded = _sentinel,
    Object? data = _sentinel,
    Object? albumId = _sentinel,
    Object? isFavorite = _sentinel,
  }) {
    // B13: копия с возможностью явно сбросить nullable-поля в null —
    // передайте AudioTrack.unset вместо значения (обычный `null` = «не менять»).
    return AudioTrack(
      id: id == _sentinel ? this.id : id! as int,
      title: title == _sentinel ? this.title : title! as String,
      artist: artist == _sentinel ? this.artist : artist! as String,
      album: album == _sentinel ? this.album : album as String?,
      uri: uri == _sentinel ? this.uri : uri! as String,
      duration: duration == _sentinel ? this.duration : duration! as int,
      size: size == _sentinel ? this.size : size as int?,
      dateAdded:
          dateAdded == _sentinel ? this.dateAdded : dateAdded as int?,
      data: data == _sentinel ? this.data : data as String?,
      albumId: albumId == _sentinel ? this.albumId : albumId as int?,
      isFavorite:
          isFavorite == _sentinel ? this.isFavorite : isFavorite! as bool,
    );
  }

  /// Маркер «не менять поле» для [copyWith].
  static const Object _sentinel = _Unset();

  /// Передайте в [copyWith], чтобы сбросить nullable-поле в null:
  /// `track.copyWith(album: AudioTrack.unset)`.
  static const Object unset = _Unset();
}

class _Unset {
  const _Unset();
}
