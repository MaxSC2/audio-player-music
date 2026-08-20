import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../state/palette_controller.dart';
import '../../ui/theme.dart';
import '../../widgets/color_picker_dialog.dart';
import '../../widgets/equalizer_dialog.dart';
import '../../core/ui_style.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final uiStyle = context.watch<UiStyleController>();
    final palette = context.watch<PaletteController>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: EdgeInsets.only(
            bottom: 24 + MediaQuery.viewPaddingOf(context).bottom),
        children: [
          const _SectionHeader('Система'),

          // Media service status (diagnostic)
          _SettingsCard(
            child: ListTile(
              leading: _TileIcon(Icons.notifications_active_rounded),
              title: const Text(
                'Медиа-сервис (шторка/локскрин)',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                player.mediaServiceReady
                    ? 'Активен'
                    : (player.mediaServiceError ?? 'Недоступен'),
                style: TextStyle(
                  color: player.mediaServiceReady
                      ? AppTheme.accentCyan
                      : AppTheme.accentPink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const _SectionHeader('Интерфейс'),

          _SettingsCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _TileTitle(
                    icon: Icons.palette_outlined,
                    title: 'Стиль интерфейса',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<PlayerUIStyle>(
                      segments: const [
                        ButtonSegment(
                          value: PlayerUIStyle.simple,
                          label: Text('Простой'),
                          icon: Icon(Icons.view_agenda_outlined, size: 18),
                        ),
                        ButtonSegment(
                          value: PlayerUIStyle.coverFlow3D,
                          label: Text('3D'),
                          icon: Icon(Icons.album_rounded, size: 18),
                        ),
                      ],
                      selected: {uiStyle.style},
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: AppTheme.accent,
                        selectedForegroundColor: Colors.white,
                        backgroundColor: AppTheme.surfaceLight,
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: AppTheme.cardBorder),
                        visualDensity: VisualDensity.compact,
                      ),
                      onSelectionChanged: (sel) =>
                          uiStyle.setStyle(sel.first),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Долгое нажатие на мини-плеер — быстрый переключатель.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          const _SectionHeader('Оформление'),

          // Пресеты палитр
          _SettingsCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _TileTitle(
                    icon: Icons.palette_outlined,
                    title: 'Палитра',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: PaletteController.presets.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        if (i == PaletteController.presets.length) {
                          final selected = palette.isCustom;
                          return _PaletteCard(
                            gradientColors: [
                              palette.active.accent,
                              palette.active.accentCyan,
                            ],
                            name: 'Своя',
                            selected: selected,
                            onTap: () => _showCustomPalette(context, palette),
                          );
                        }
                        final p = PaletteController.presets[i];
                        final selected = !palette.isCustom && palette.index == i;
                        return _PaletteCard(
                          gradientColors: [p.accent, p.accentCyan],
                          name: PaletteController.presetNames[i],
                          selected: selected,
                          onTap: () => palette.select(i),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const _SectionHeader('Воспроизведение'),

          // Default speed
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TileTitle(
                  icon: Icons.speed_rounded,
                  title: 'Скорость по умолчанию',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                    final selected = player.defaultSpeed == speed;
                    return ChoiceChip(
                      label: Text('${speed.toStringAsFixed(2)}x'
                          .replaceFirst('.00', 'x')),
                      selected: selected,
                      selectedColor: AppTheme.accent,
                      backgroundColor: AppTheme.surfaceLight,
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      onSelected: (_) => player.setDefaultSpeed(speed),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Equalizer preset
          _SettingsCard(
            child: ListTile(
              leading: _TileIcon(Icons.graphic_eq_rounded),
              title: const Text(
                'Эквалайзер',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                player.equalizerPreset,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textMuted),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => const EqualizerDialog(),
                );
              },
            ),
          ),

          // Resume playback
          _SettingsCard(
            child: SwitchListTile(
              secondary: _TileIcon(Icons.play_circle_outline_rounded),
              title: const Text(
                'Продолжать воспроизведение',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                'Возобновлять последний трек с места остановки',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              value: player.resumePlayback,
              activeTrackColor: AppTheme.accent,
              onChanged: player.setResumePlayback,
            ),
          ),

          const _SectionHeader('Стриминг'),

          // Play from URL
          _SettingsCard(
            child: ListTile(
              leading: _TileIcon(Icons.link_rounded),
              title: const Text(
                'Воспроизвести по ссылке',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              subtitle: const Text(
                'Вставьте прямую ссылку на аудиофайл',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textMuted),
              onTap: () => _showUrlDialog(context, player),
            ),
          ),

          const _SectionHeader('Библиотека'),

          // Default sort order
          _SettingsCard(
            child: ListTile(
              leading: _TileIcon(Icons.sort_rounded),
              title: const Text(
                'Сортировка по умолчанию',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                _sortLabel(player.sortOrder),
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textMuted),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: AppTheme.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: SortOrder.values.map((order) {
                        final selected = player.sortOrder == order;
                        return ListTile(
                          leading: Icon(
                            selected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color: selected
                                ? AppTheme.accent
                                : AppTheme.textMuted,
                          ),
                          title: Text(
                            _sortLabel(order),
                            style: TextStyle(
                              color: selected
                                  ? AppTheme.accentLight
                                  : AppTheme.textPrimary,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            player.sortOrder = order;
                            Navigator.pop(ctx);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),

          // Hide unknown artist
          _SettingsCard(
            child: SwitchListTile(
              secondary: _TileIcon(Icons.person_off_rounded),
              title: const Text(
                'Скрывать "Unknown Artist"',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                'Не показывать треки без исполнителя',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              value: player.hideUnknownArtist,
              activeTrackColor: AppTheme.accent,
              onChanged: player.setHideUnknownArtist,
            ),
          ),

          const _SectionHeader('Диагностика (v41)'),

          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _TileTitle(
                      icon: Icons.bug_report_rounded,
                      title: 'PlaybackState',
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        final text = '${player.mediaDiagnostics}\n'
                            '\nЖурнал:\n'
                            '${player.mediaDebugLog.take(15).join('\n')}';
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Диагностика скопирована'),
                          ),
                        );
                      },
                      icon: Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Копировать'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.accent,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    player.mediaDiagnostics,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Журнал публикации состояния (последние записи сверху):',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 4),
                ...player.mediaDebugLog.take(15).map(
                      (line) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 1),
                        child: Text(
                          line,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          const _SectionHeader('О приложении'),

          const _SettingsCard(
            child: Column(
              children: [
                ListTile(
                  leading: _TileIcon(Icons.apps_rounded),
                  title: Text(
                    'NeonWave',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    'Локальный музыкальный плеер\nВерсия 1.0.0',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                ListTile(
                  leading: _TileIcon(Icons.favorite_rounded),
                  title: Text(
                    'Работает офлайн, вся музыка — только на вашем устройстве',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUrlDialog(BuildContext context, PlayerProvider player) {
    final urlController = TextEditingController();
    final titleController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Воспроизвести по ссылке',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Ссылка на аудио (mp3/m4a/ogg...)',
                labelStyle: TextStyle(color: AppTheme.textMuted),
                hintText: 'https://...',
                hintStyle: TextStyle(color: AppTheme.textMuted),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.cardBorder),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.accent),
                ),
              ),
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Название (необязательно)',
                labelStyle: TextStyle(color: AppTheme.textMuted),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.cardBorder),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.accent),
                ),
              ),
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isEmpty) return;
              final title = titleController.text.trim();
              player.playUrl(url, title: title);
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Воспроизведение по ссылке...'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.black,
            ),
            child: const Text('Играть',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ).then((_) {
      urlController.dispose();
      titleController.dispose();
    });
  }

  void _showCustomPalette(BuildContext context, PaletteController palette) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final active = palette.active;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Своя палитра',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Нажмите на цвет, чтобы изменить его',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    _ColorSlot(
                      label: 'Основной',
                      color: active.accent,
                      onTap: () => _pickColor(ctx, active.accent, (c) {
                        palette.editSlot(accent: c);
                        setState(() {});
                      }),
                    ),
                    _ColorSlot(
                      label: 'Бирюзовый',
                      color: active.accentCyan,
                      onTap: () => _pickColor(ctx, active.accentCyan, (c) {
                        palette.editSlot(accentCyan: c);
                        setState(() {});
                      }),
                    ),
                    _ColorSlot(
                      label: 'Розовый',
                      color: active.accentPink,
                      onTap: () => _pickColor(ctx, active.accentPink, (c) {
                        palette.editSlot(accentPink: c);
                        setState(() {});
                      }),
                    ),
                    _ColorSlot(
                      label: 'Зелёный',
                      color: active.accentGreen,
                      onTap: () => _pickColor(ctx, active.accentGreen, (c) {
                        palette.editSlot(accentGreen: c);
                        setState(() {});
                      }),
                    ),
                    _ColorSlot(
                      label: 'Янтарный',
                      color: active.accentAmber,
                      onTap: () => _pickColor(ctx, active.accentAmber, (c) {
                        palette.editSlot(accentAmber: c);
                        setState(() {});
                      }),
                    ),
                    _ColorSlot(
                      label: 'Фон',
                      color: active.background,
                      onTap: () => _pickColor(ctx, active.background, (c) {
                        palette.editSlot(background: c);
                        setState(() {});
                      }),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        palette.resetCustom();
                        Navigator.of(ctx).pop();
                      },
                      icon: const Icon(Icons.restart_alt_rounded,
                          color: AppTheme.textMuted, size: 18),
                      label: const Text(
                        'Сбросить к Neon',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _pickColor(BuildContext sheetCtx, Color initial,
      ValueChanged<Color> onPick) {
    showDialog<Color>(
      context: sheetCtx,
      builder: (_) => ColorPickerDialog(initial: initial),
    ).then((c) {
      if (c != null) onPick(c);
    });
  }

  String _sortLabel(SortOrder order) {
    switch (order) {
      case SortOrder.title:
        return 'По названию';
      case SortOrder.artist:
        return 'По исполнителю';
      case SortOrder.dateAddedNew:
        return 'По дате добавления (новые)';
      case SortOrder.dateAddedOld:
        return 'По дате добавления (старые)';
      case SortOrder.duration:
        return 'По длительности';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppTheme.accentCyan,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: child,
    );
  }
}

class _TileIcon extends StatelessWidget {
  final IconData icon;

  const _TileIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

class _TileTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _TileTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TileIcon(icon),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _PaletteCard extends StatelessWidget {
  final List<Color> gradientColors;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteCard({
    required this.gradientColors,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppTheme.accentLight : AppTheme.cardBorder,
                width: selected ? 2.5 : 1,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 24)
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(
              color: selected ? AppTheme.textPrimary : AppTheme.textMuted,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorSlot extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ColorSlot({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.cardBorder),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}