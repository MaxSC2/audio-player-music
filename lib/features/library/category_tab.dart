import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/audio_track.dart';
import '../../providers/player_provider.dart';
import '../../ui/theme.dart';
import '../../widgets/track_tile.dart';

class CategoryTab extends StatefulWidget {
  const CategoryTab({super.key});

  @override
  State<CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<CategoryTab> {
  ListeningContext _selected = ListeningContext.balanced;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PlayerProvider>().fetchGenresForVisible();
    });
  }

  String _ctxLabel(ListeningContext c) {
    switch (c) {
      case ListeningContext.balanced:
        return 'Сбаланс';
      case ListeningContext.energy:
        return 'Энергия';
      case ListeningContext.calm:
        return 'Спокойствие';
      case ListeningContext.focus:
        return 'Фокус';
      case ListeningContext.party:
        return 'Вечеринка';
    }
  }

  IconData _ctxIcon(ListeningContext c) {
    switch (c) {
      case ListeningContext.balanced:
        return Icons.balance_rounded;
      case ListeningContext.energy:
        return Icons.bolt_rounded;
      case ListeningContext.calm:
        return Icons.self_improvement_rounded;
      case ListeningContext.focus:
        return Icons.center_focus_strong_rounded;
      case ListeningContext.party:
        return Icons.celebration_rounded;
    }
  }

  LinearGradient _ctxGradient(ListeningContext c) {
    switch (c) {
      case ListeningContext.balanced:
        return AppTheme.primaryGradient;
      case ListeningContext.energy:
        return const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEF4444)]);
      case ListeningContext.calm:
        return const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF10B981)]);
      case ListeningContext.focus:
        return const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF06B6D4)]);
      case ListeningContext.party:
        return const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFA855F7)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final tracks = player.tracksForCategory(_selected);
    final total = player.visibleTracks.length;

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        // Info header
        Container(
          margin: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppTheme.cardGradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.category_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text('Категории алгоритма', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Автоматическое распределение по ключевым словам в названии/исполнителе и длительности. Ручная разметка имеет приоритет. Веса влияют на рекомендации.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.35),
              ),
              const SizedBox(height: 4),
              Text(
                'Интернет-парсер (поиск жанра/настроения трека онлайн) — в планах для точного определения без ключевых слов.',
                style: TextStyle(color: AppTheme.textMuted.withOpacity(0.8), fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),

        // Weights
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('Веса контекстов (влияют на рекомендации)', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        const SizedBox(height: 8),
        ...ListeningContext.values.map((ctx) {
          final w = player.categoryWeight(ctx);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: _ctxGradient(ctx)),
                  child: Icon(_ctxIcon(ctx), color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(_ctxLabel(ctx), style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                          const Spacer(),
                          Text('${w.toStringAsFixed(2)}x', style: TextStyle(color: AppTheme.accentLight, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppTheme.accent,
                          inactiveTrackColor: AppTheme.surfaceLight,
                          thumbColor: AppTheme.accentLight,
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        ),
                        child: Slider(
                          min: 0.5,
                          max: 2.5,
                          divisions: 20,
                          value: w.clamp(0.5, 2.5),
                          onChanged: (v) => player.setCategoryWeight(ctx, v),
                        ),
                      ),
                      Text(player.categoryCriteria(ctx), style: TextStyle(color: AppTheme.textMuted, fontSize: 10, height: 1.2)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Builder(builder: (context) {
            final player = context.watch<PlayerProvider>();
            final cached = player.visibleTracks.where((t) => player.genreForTrack(t.id) != null).length;
            final total = player.visibleTracks.length;
            final pct = total == 0 ? 0 : (cached * 100 ~/ total);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.cardBorder)),
              child: Row(
                children: [
                  Icon(Icons.cloud_download_rounded, size: 16, color: AppTheme.accentCyan),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Жанры: $cached/$total ($pct%) в кэше • фоновая догрузка по названию', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11))),
                  TextButton(
                    onPressed: () => player.fetchGenresForVisible(batchSize: 20),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 32)),
                    child: const Text('Догрузить', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('Категории: тап — фильтр, долгое нажатие на треке — ручная разметка', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ),
        const SizedBox(height: 8),
        // Category chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: ListeningContext.values.map((ctx) {
              final count = player.tracksForCategory(ctx).length;
              final selected = _selected == ctx;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('${_ctxLabel(ctx)} • $count'),
                  avatar: Icon(_ctxIcon(ctx), size: 16, color: selected ? Colors.white : AppTheme.textSecondary),
                  selected: selected,
                  onSelected: (_) => setState(() => _selected = ctx),
                  selectedColor: AppTheme.accent,
                  backgroundColor: AppTheme.surfaceLight,
                  labelStyle: TextStyle(color: selected ? Colors.white : AppTheme.textSecondary, fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 12),
                  side: BorderSide(color: selected ? AppTheme.accent : Colors.transparent),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('$_selected: ${tracks.length} из $total треков', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const Spacer(),
              Text('фильтр: ${_ctxLabel(_selected)}', style: TextStyle(color: AppTheme.accentLight, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Track list for selected category
        ...tracks.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(_ctxIcon(_selected), size: 48, color: AppTheme.textMuted.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text('Нет треков в категории "${_ctxLabel(_selected)}"', style: TextStyle(color: AppTheme.textMuted)),
                        const SizedBox(height: 6),
                        Text('Попробуйте изменить ключевые слова или добавить вручную', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted.withOpacity(0.7), fontSize: 12)),
                      ],
                    ),
                  ),
                )
              ]
            : tracks.map((track) {
                final isCurrent = player.currentTrack?.id == track.id;
                final manual = player.isManualCategory(track.id);
                return GestureDetector(
                  onLongPress: () => _showManualEditor(context, player, track),
                  child: Stack(
                    children: [
                      TrackTile(
                        track: track,
                        isPlaying: isCurrent && player.isPlaying,
                        isCurrent: isCurrent,
                        onTap: () {
                          final idx = tracks.indexWhere((t) => t.id == track.id);
                          player.playFromPlaylist(tracks, idx >= 0 ? idx : 0);
                        },
                      ),
                      if (manual)
                        Positioned(
                          right: 22,
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                            child: const Text('ручная', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      Builder(builder: (context) {
                        final g = player.genreForTrack(track.id);
                        if (g == null) return const SizedBox.shrink();
                        return Positioned(
                          right: 22,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.surfaceLight.withOpacity(0.85), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.cardBorder)),
                            child: Text(g, style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
      ],
    );
  }

  void _showManualEditor(BuildContext context, PlayerProvider player, AudioTrack track) {
    final current = player.categoriesForTrack(track);
    final isManual = player.isManualCategory(track.id);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        final live = player.categoriesForTrack(track);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.cardBorder, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 12),
                Text('Ручная разметка — ${track.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(isManual ? 'Ручной приоритет • авто-определение отключено' : 'Авто: ${current.map(_ctxLabel).join(", ")} — тапните чтобы переопределить',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ListeningContext.values.map((ctx) {
                    final sel = live.contains(ctx);
                    return FilterChip(
                      label: Text(_ctxLabel(ctx)),
                      avatar: Icon(_ctxIcon(ctx), size: 16, color: sel ? Colors.white : AppTheme.textSecondary),
                      selected: sel,
                      onSelected: (_) {
                        player.toggleManualCategory(track.id, ctx);
                        setSheetState(() {});
                      },
                      selectedColor: AppTheme.accent,
                      backgroundColor: AppTheme.surfaceLight,
                      labelStyle: TextStyle(color: sel ? Colors.white : AppTheme.textSecondary, fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 12),
                      side: BorderSide(color: sel ? AppTheme.accent : Colors.transparent),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                if (isManual)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        player.clearManualCategory(track.id);
                        setSheetState(() {});
                      },
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      label: const Text('Сбросить к авто'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textSecondary, side: BorderSide(color: AppTheme.cardBorder)),
                    ),
                  ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Готово'),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
