import '../models/audio_track.dart';

/// Normalizes an M3U local path for case-insensitive matching.
String normalizeM3uPath(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final uri = Uri.tryParse(trimmed);
  final path = uri != null && uri.scheme.toLowerCase() == 'file'
      ? uri.path
      : trimmed.split('?').first;
  return path
      .replaceAll(r'', '/')
      .replaceAll(RegExp(r'/+'), '/')
      .toLowerCase();
}

String m3uBasename(String raw) {
  final normalized = normalizeM3uPath(raw);
  final slash = normalized.lastIndexOf('/');
  return slash >= 0 ? normalized.substring(slash + 1) : normalized;
}

/// Matches an M3U line against exact normalized paths first. A basename
/// fallback is allowed only when that basename identifies exactly one track;
/// ambiguous basenames are intentionally skipped instead of selecting an
/// arbitrary file.
AudioTrack? matchM3uLine(
  String line,
  Map<String, AudioTrack> byPath,
  Map<String, List<AudioTrack>> byBasename,
) {
  final exact = byPath[normalizeM3uPath(line)];
  if (exact != null) return exact;
  final candidates = byBasename[m3uBasename(line)];
  return candidates != null && candidates.length == 1
      ? candidates.single
      : null;
}
