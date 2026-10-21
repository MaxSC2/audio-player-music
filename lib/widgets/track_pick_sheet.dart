part of 'playlist_picker_sheet.dart';

/// Выбор треков для нового плейлиста (вариант A): поиск, «выбрать
/// показанные/очистить», счётчик. Начальный трек уже отмечен.
///
/// В режиме добавления в существующий плейлист [disabledIds] показывает
/// уже добавленные треки неактивными, чтобы не искать их вручную.
class TrackPickSheet extends StatefulWidget {
  final List<AudioTrack> initial;
  final Set<int> disabledIds;
  final String title;

  const TrackPickSheet({
    super.key,
    this.initial = const [],
    this.disabledIds = const {},
    this.title = 'Треки для плейлиста',
  });

  static Future<List<int>?> show(
    BuildContext context, {
    List<AudioTrack> initial = const [],
    Set<int> disabledIds = const {},
    String title = 'Треки для плейлиста',
  }) {
    return showModalBottomSheet<List<int>>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: TrackPickSheet(
          initial: initial,
          disabledIds: disabledIds,
          title: title,
        ),
      ),
    );
  }

  @override
  State<TrackPickSheet> createState() => _TrackPickSheetState();
}

class _TrackPickSheetState extends State<TrackPickSheet> {
  final _search = TextEditingController();
  String _query = '';
  late Set<int> _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial
        .where((t) => !widget.disabledIds.contains(t.id))
        .map((t) => t.id)
        .toSet();
    _search.addListener(() => setState(() => _query = _search.text.trim()));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AudioTrack> _filtered(PlayerProvider player) {
    var list = List<AudioTrack>.of(player.visibleTracks);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where(
            (t) =>
                t.title.toLowerCase().contains(q) ||
                t.artist.toLowerCase().contains(q),
          )
          .toList();
    }
    // Выбранные — вверх, уже добавленные — вниз, остальные по названию.
    int rank(AudioTrack t) {
      if (_picked.contains(t.id)) return 0;
      if (widget.disabledIds.contains(t.id)) return 2;
      return 1;
    }

    list.sort((a, b) {
      final ra = rank(a);
      final rb = rank(b);
      if (ra != rb) return ra.compareTo(rb);
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final tracks = _filtered(player);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const SizedBox(height: 8),
            _searchField(),
            _bulkRow(tracks),
            Expanded(child: _list(tracks)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, _picked.toList()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.done_all_rounded),
              label: Text('Готово • ${_picked.length}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.checklist_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.title,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '${_picked.length}',
          style: TextStyle(
            color: AppTheme.accentLight,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: AppTheme.textSecondary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _search,
      style: TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: 'Поиск треков…',
        hintStyle: TextStyle(color: AppTheme.textMuted),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: AppTheme.textMuted,
        ),
        filled: true,
        fillColor: AppTheme.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _bulkRow(List<AudioTrack> tracks) {
    final available =
        tracks.where((t) => !widget.disabledIds.contains(t.id)).toList();
    return Row(
      children: [
        TextButton(
          onPressed: available.isEmpty
              ? null
              : () => setState(
                    () => _picked = available.map((t) => t.id).toSet(),
                  ),
          child: Text(
            'Выбрать показанные',
            style: TextStyle(
              color: available.isEmpty
                  ? AppTheme.textMuted
                  : AppTheme.accentLight,
            ),
          ),
        ),
        TextButton(
          onPressed: () => setState(_picked.clear),
          child: Text(
            'Очистить',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _list(List<AudioTrack> tracks) {
    if (tracks.isEmpty) {
      return Center(
        child: Text(
          'Ничего не найдено',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }
    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final t = tracks[index];
        final on = _picked.contains(t.id);
        final disabled = widget.disabledIds.contains(t.id);
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: on
                ? AppTheme.accent.withValues(
                    alpha: AppTheme.accent.a * 0.16,
                  )
                : AppTheme.surfaceLight.withValues(
                    alpha: disabled ? 0.5 : 1,
                  ),
            borderRadius: BorderRadius.circular(12),
            border: on
                ? Border.all(
                    color: AppTheme.accent.withValues(
                      alpha: AppTheme.accent.a * 0.5,
                    ),
                  )
                : null,
          ),
          child: CheckboxListTile(
            value: on,
            onChanged: disabled
                ? null
                : (_) => setState(() {
                      if (on) {
                        _picked.remove(t.id);
                      } else {
                        _picked.add(t.id);
                      }
                    }),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppTheme.accent,
            title: Text(
              t.title,
              style: TextStyle(
                color: disabled ? AppTheme.textMuted : AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              disabled ? '${t.artist} · уже в плейлисте' : t.artist,
              style: TextStyle(
                color: disabled
                    ? AppTheme.accentGreen.withValues(alpha: 0.7)
                    : AppTheme.textMuted,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}
