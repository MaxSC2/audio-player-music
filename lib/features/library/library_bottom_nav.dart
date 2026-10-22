import 'package:flutter/material.dart';

import '../now_playing/cinematic/cinematic_player_body.dart';

/// Компактная нижняя навигация библиотеки: пять крупных целей вместо
/// горизонтального скролла из девяти вкладок. Редкие разделы собраны
/// в шторке «Ещё», поэтому ничего не теряется и не обрезается.
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

  static const _primary = [0, 1, 2, 3];
  static const _secondary = [4, 5, 6, 7, 8];

  bool get _moreActive => _secondary.contains(current);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xB30D0D12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CinematicTheme.border),
        ),
        child: Row(
          children: [
            for (final index in _primary)
              Expanded(
                child: _NavButton(
                  icon: _icons[index],
                  label: _labels[index],
                  selected: current == index,
                  accent: accent,
                  onTap: () => onSelect(index),
                ),
              ),
            Expanded(
              child: _NavButton(
                icon: Icons.grid_view_rounded,
                label: 'Ещё',
                selected: _moreActive,
                accent: accent,
                showDot: _moreActive,
                onTap: () => _openMore(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMore(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111218),
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: CinematicTheme.textDim.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Ещё',
                      style: TextStyle(
                        color: CinematicTheme.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 2, 4, 10),
                    child: Text(
                      'Разделы библиотеки',
                      style: TextStyle(
                        color: CinematicTheme.textDim,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  for (final index in _secondary)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        color: current == index
                            ? accent.withValues(alpha: 0.14)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          minTileHeight: 52,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          leading: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _icons[index],
                              size: 18,
                              color: accent,
                            ),
                          ),
                          title: Text(
                            _labels[index],
                            style: const TextStyle(
                              color: CinematicTheme.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: current == index
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: accent,
                                  size: 20,
                                )
                              : const Icon(
                                  Icons.chevron_right_rounded,
                                  color: CinematicTheme.textDim,
                                ),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            onSelect(index);
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool showDot;
  final Color accent;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? CinematicTheme.text : CinematicTheme.textDim;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 20, color: color),
                  if (showDot)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
