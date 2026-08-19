import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../ui/theme.dart';

class PersonalDJSheet extends StatelessWidget {
  const PersonalDJSheet({super.key});

  static const _contexts = <ListeningContext, (String, IconData)>{
    ListeningContext.balanced: ('Сбалансированный', Icons.balance_rounded),
    ListeningContext.energy: ('Энергия', Icons.local_fire_department_rounded),
    ListeningContext.calm: ('Спокойствие', Icons.nightlight_round),
    ListeningContext.party: ('Вечеринка', Icons.celebration_rounded),
    ListeningContext.focus: ('Фокус', Icons.headphones_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final ctx = player.listeningContext;
    final notNow = player.notNowTracks;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Personal DJ',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Плеер сам соберёт очередь под настроение',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _contexts.entries.map((e) {
                final (label, icon) = e.value;
                final selected = ctx == e.key;
                return GestureDetector(
                  onTap: () => player.setListeningContext(e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.accent.withOpacity(0.25)
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: selected
                            ? AppTheme.accent
                            : Colors.white10,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon,
                            color: selected
                                ? AppTheme.accentLight
                                : AppTheme.textSecondary,
                            size: 16),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            color: selected
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                player.launchPersonalDJ();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.auto_awesome_rounded, size: 20),
              label: const Text('Запустить DJ',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
            ),
            if (notNow.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Скрытые на неделю',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: notNow.length,
                  itemBuilder: (context, index) {
                    final t = notNow[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.do_not_disturb_on_rounded,
                          color: AppTheme.textMuted, size: 20),
                      title: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 14),
                      ),
                      subtitle: Text(
                        t.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.undo_rounded,
                            color: AppTheme.accentLight, size: 20),
                        onPressed: () => player.toggleNotNow(t),
                        tooltip: 'Вернуть',
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}