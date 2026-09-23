part of 'playlist_picker_sheet.dart';

/// Выбор треков для нового плейлиста (вариант A): поиск, «выбрать
/// показанные/очистить», счётчик. Начальный трек уже отмечен.
class TrackPickSheet extends StatefulWidget {
  final List<AudioTrack> initial;

  const TrackPickSheet({super.key, this.initial = const []});

  static Future<List<int>?> show(
    BuildContext context, {
    List<AudioTrack> initial = const [],
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
        child: TrackPickSheet(initial: initial),
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
    _picked = widget.initial.map((t) => t.id).toSet();
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
    // Выбранные — вверх, затем по названию: видно, что уже отмечено.
    list.sort((a, b) {
      final pa = _picked.contains(a.id) ? 0 : 1;
      final pb = _picked.contains(b.id) ? 0 : 1;
      if (pa != pb) return pa.compareTo(pb);
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
            'Треки для плейлиста',
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
    return Row(
      children: [
        TextButton(
          onPressed: () => setState(
            () => _picked = tracks.map((t) => t.id).toSet(),
          ),
          child: Text(
            'Выбрать показанные',
            style: TextStyle(color: AppTheme.accentLight),
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
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: on
                ? AppTheme.accent.withValues(
                    alpha: AppTheme.accent.a * 0.16,
                  )
                : AppTheme.surfaceLight,
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
            onChanged: (_) => setState(() {
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
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              t.artist,
              style: TextStyle(
                color: AppTheme.textMuted,
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
