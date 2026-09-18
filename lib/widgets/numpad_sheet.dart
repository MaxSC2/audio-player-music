import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../ui/theme.dart';

/// Цифровая клавиатура: быстрый переход к треку по номеру в очереди.
class NumpadSheet extends StatefulWidget {
  const NumpadSheet({super.key});

  @override
  State<NumpadSheet> createState() => _NumpadSheetState();
}

class _NumpadSheetState extends State<NumpadSheet> {
  String _input = '';

  void _add(String d) {
    if (_input.length >= 4) return;
    setState(() => _input += d);
  }

  void _backspace() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _submit(PlayerProvider player) {
    final n = int.tryParse(_input);
    final queueLen = player.playlist.length;
    if (n == null || n < 1) {
      // B11: раньше кнопка молча ничего не делала (пусто/«0»/ведущие нули) —
      // теперь пользователь понимает, почему перехода нет.
      _hint('Введите номер от 1 до $queueLen');
      return;
    }
    if (n > queueLen) {
      _hint('В очереди только $queueLen треков');
      return;
    }
    player.playAt(n - 1);
    // B11: сообщаем выбор наружу (индекс трека) вместо двойного `pop()`
    // вслепую — закрытием очереди занимается вызывающая сторона.
    Navigator.of(context).pop(n - 1);
  }

  void _hint(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final queueLen = player.playlist.length;

    Widget key(String label, {VoidCallback? onTap, IconData? icon}) {
      return Expanded(
        child: AspectRatio(
          aspectRatio: 1.15,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Material(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onTap,
                child: Center(
                  child: icon != null
                      ? Icon(icon, color: AppTheme.accentLight, size: 26)
                      : Text(
                          label,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Перейти к треку',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Введите номер из очереди (1–$queueLen)',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              // Display
              Container(
                height: 52,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _input.isEmpty ? '—' : _input,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Keys grid
              Column(
                children: [
                  Row(
                    children: [
                      key('1', onTap: () => _add('1')),
                      key('2', onTap: () => _add('2')),
                      key('3', onTap: () => _add('3')),
                    ],
                  ),
                  Row(
                    children: [
                      key('4', onTap: () => _add('4')),
                      key('5', onTap: () => _add('5')),
                      key('6', onTap: () => _add('6')),
                    ],
                  ),
                  Row(
                    children: [
                      key('7', onTap: () => _add('7')),
                      key('8', onTap: () => _add('8')),
                      key('9', onTap: () => _add('9')),
                    ],
                  ),
                  Row(
                    children: [
                      key(
                        '',
                        onTap: _backspace,
                        icon: Icons.backspace_outlined,
                      ),
                      key('0', onTap: () => _add('0')),
                      key(
                        '',
                        onTap: () => _submit(player),
                        icon: Icons.check_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
