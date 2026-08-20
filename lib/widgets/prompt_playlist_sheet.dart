import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/audio_track.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';

class PromptPlaylistSheet extends StatefulWidget {
  const PromptPlaylistSheet({super.key});

  @override
  State<PromptPlaylistSheet> createState() => _PromptPlaylistSheetState();
}

class _PromptPlaylistSheetState extends State<PromptPlaylistSheet> {
  final TextEditingController _controller = TextEditingController();
  List<AudioTrack>? _result;
  String _prompt = '';
  bool _saved = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _generate(PlayerProvider player) {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;
    final result = player.buildPlaylistFromPrompt(prompt);
    setState(() {
      _result = result;
      _prompt = prompt;
      _saved = false;
    });
  }

  void _setHint(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
  }

  Future<void> _save(PlayerProvider player) async {
    final result = _result;
    if (result == null || result.isEmpty) return;
    final name = '«$_prompt»';
    final id = await player.createPlaylist(name);
    if (id == null) return;
    for (final t in result) {
      await player.addToPlaylist(id, t);
    }
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Сборник сохранён: $name'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final result = _result;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Сборник по описанию',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Опиши настроение словами — DJ соберёт плейлист',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _generate(player),
                decoration: InputDecoration(
                  hintText: 'Например: энергичная музыка для пробежки',
                  hintStyle:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: AppTheme.surfaceLight,
                  prefixIcon: const Icon(Icons.auto_awesome_rounded,
                      color: AppTheme.accentLight, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 14),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              children: [
                _HintChip('спокойная ночь', () => _setHint('спокойная ночь')),
                _HintChip('энергия для спорта',
                    () => _setHint('энергия для спорта')),
                _HintChip('фокус для работы',
                    () => _setHint('фокус для работы')),
                _HintChip('что-то новое', () => _setHint('что-то новое')),
                _HintChip('редкие треки', () => _setHint('редкие треки')),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _generate(player),
              icon: const Icon(Icons.psychology_rounded, size: 18),
              label: const Text('Собрать',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black,
              ),
            ),
            if (result != null) ...[
              const SizedBox(height: 6),
              const Divider(color: AppTheme.cardBorder),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    result.isEmpty
                        ? 'Ничего не нашлось'
                        : 'Собрано треков: ${result.length}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
              ),
              if (result.isNotEmpty) ...[
                const SizedBox(height: 4),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: result.length,
                    itemBuilder: (context, index) {
                      final t = result[index];
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.textPrimary, fontSize: 13),
                        ),
                        subtitle: Text(
                          t.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 11),
                        ),
                        onTap: () => player.playTrack(t),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _saved ? null : () => _save(player),
                      icon: Icon(
                        _saved ? Icons.check_rounded : Icons.playlist_add_rounded,
                        size: 18,
                      ),
                      label: Text(_saved ? 'Сохранено' : 'Сохранить в плейлисты'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentLight,
                        side: const BorderSide(color: AppTheme.cardBorder),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        player.playFromPlaylist(result, 0);
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Играть'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _HintChip(this.text, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Text(
          text,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
      ),
    );
  }
}