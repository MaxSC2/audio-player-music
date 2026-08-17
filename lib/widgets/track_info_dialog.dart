import 'package:flutter/material.dart';
import '../models/audio_track.dart';
import '../ui/theme.dart';

class TrackInfoDialog extends StatelessWidget {
  final AudioTrack track;

  const TrackInfoDialog({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.cardBorder),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.info_outline_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'Информация о треке',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Название', track.title),
            _buildInfoRow('Исполнитель', track.artist),
            if (track.album != null && track.album!.isNotEmpty)
              _buildInfoRow('Альбом', track.album!),
            _buildInfoRow('Длительность', track.formattedDuration),
            if (track.formattedSize.isNotEmpty)
              _buildInfoRow('Размер файла', track.formattedSize),
            if (track.data != null && track.data!.isNotEmpty)
              _buildInfoRow('Путь к файлу', track.data!),
            _buildInfoRow('ID', track.id.toString()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Закрыть',
            style: TextStyle(
              color: AppTheme.accentLight,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(color: AppTheme.cardBorder, height: 12),
        ],
      ),
    );
  }
}
