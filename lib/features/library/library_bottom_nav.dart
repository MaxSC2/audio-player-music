import 'package:flutter/material.dart';

import '../now_playing/cinematic/cinematic_player_body.dart';

/// Нижняя навигация библиотеки: все разделы в горизонтальном скролле,
/// ничего не выкидываем и не тесним. Общая для тёмных стилей.
class LibraryBottomNav extends StatelessWidget {
  /// Индекс вкладки LibraryTabs (0..8).
  final int current;
  final Color accent;
  final ValueChanged<int> onSelect;

  const LibraryBottomNav({
    super.key,
    required this.current,
    required this.accent,
    required this.onSelect,
  });

  static const _icons = [
    Icons.music_note_rounded,
    Icons.queue_music_rounded,
    Icons.album_rounded,
    Icons.mic_external_on_rounded,
    Icons.folder_rounded,
    Icons.favorite_rounded,
    Icons.history_rounded,
    Icons.fingerprint_rounded,
    Icons.category_rounded,
  ];
  static const _labels = [
    'Треки',
    'Плейлисты',
    'Альбомы',
    'Исполнители',
    'Папки',
    'Избранное',
    'История',
    'DNA',
    'Категории',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xB30D0D12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CinematicTheme.border),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_labels.length, (i) {
              final selected = current == i;
              return Padding(
                padding: EdgeInsets.only(
                  right: i == _labels.length - 1 ? 0 : 4,
                ),
                child: GestureDetector(
                  onTap: () => onSelect(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? accent.withValues(alpha: accent.a * 0.28)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: accent.withValues(
                                  alpha: accent.a * 0.25,
                                ),
                                blurRadius: 12,
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _icons[i],
                          size: 18,
                          color: selected
                              ? CinematicTheme.text
                              : CinematicTheme.textDim,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _labels[i],
                          style: TextStyle(
                            color: selected
                                ? CinematicTheme.text
                                : CinematicTheme.textDim,
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
