class AudioTrack {
  final int id;
  final String title;
  final String artist;
  final String? album;
  final String uri;
  final int duration;

  AudioTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    required this.uri,
    required this.duration,
  });

  String get formattedDuration {
    final minutes = (duration / 60000).floor();
    final seconds = ((duration % 60000) / 1000).floor();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String formatDuration(int milliseconds) {
    if (milliseconds <= 0) return '0:00';
    final minutes = (milliseconds / 60000).floor();
    final seconds = ((milliseconds % 60000) / 1000).floor();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
