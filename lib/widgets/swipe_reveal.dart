import 'package:flutter/material.dart';
import '../core/ui_style.dart';

class SwipeAction {
  final IconData icon;
  final Color color;
  final String tooltip;
  final String label;
  final VoidCallback onTap;

  const SwipeAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.label,
    required this.onTap,
  });
}

/// Swipe-to-reveal actions behind a tile.
///
/// The action strip is fully transparent while the tile is closed, so it
/// never bleeds through translucent tile fills or margins.
///
/// Кнопки адаптируются под стиль плеера ([style]):
/// * **simple** — плоские цветные плашки (классика Material);
/// * **coverFlow3D** — объёмные градиентные кнопки с бликом сверху и тенью;
/// * **neon** — тёмные полупрозрачные плашки с цветным свечением действия
///   и тонким акцентным разделителем (в тон мини-плееру/сцене);
/// * **cinematic** — стеклянные плашки (белый 8%) с белой кромкой и мягким
///   акцентным свечением.
///
/// [accent] — оверлейный акцент из обложки/темы (для neon/cinematic), как
/// у мини-плеера и сцены, чтобы кнопки читались единой палитрой.
class SwipeReveal extends StatefulWidget {
  final Widget child;
  final List<SwipeAction> actions;
  final double actionWidth;
  final BorderRadius borderRadius;
  final PlayerUIStyle style;
  final Color? accent;

  const SwipeReveal({
    super.key,
    required this.child,
    required this.actions,
    this.actionWidth = 62,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.style = PlayerUIStyle.simple,
    this.accent,
  });

  @override
  State<SwipeReveal> createState() => _SwipeRevealState();
}

class _SwipeRevealState extends State<SwipeReveal> {
  double _dx = 0;
  bool _open = false;
  double get _openWidth => widget.actionWidth * widget.actions.length;

  /// Закрывает полосу действий: тап по тайлу или по любой кнопке действия.
  void _close() {
    if (!_open) return;
    setState(() {
      _dx = 0;
      _open = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reveal = _open ? 1.0 : 0.0;
    final width = _openWidth;

    return Stack(
      children: [
        // Sliding tile (фронтальный слой, задаёт размер Stack)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) {
            setState(() {
              _dx = (_dx + d.delta.dx).clamp(-width, 0).toDouble();
              _open = _dx < -width / 2;
            });
          },
          onHorizontalDragEnd: (d) {
            final velocity = d.primaryVelocity ?? 0;
            if (velocity < -300 || _dx < -width / 2) {
              setState(() {
                _dx = -width;
                _open = true;
              });
            } else {
              setState(() {
                _dx = 0;
                _open = false;
              });
            }
          },
          onTap: _close,
          child: Transform.translate(
            offset: Offset(_dx, 0),
            child: widget.child,
          ),
        ),

        // Полоса действий — СВЕРХУ тайла, выезжает синхронно с ним (_dx).
        //
        // ФИКС «кнопки свайпа не нажимаются»: раньше полоса лежала ПОД тайлом,
        // а у тайла был GestureDetector с HitTestBehavior.opaque на всю ширину.
        // Stack проверяет попадания сверху вниз (тайл первым), поэтому тап по
        // кнопке доставался тайлу (_toggleClose) — полоса закрывалась, действие
        // не выполнялось. Теперь полоса наверху, а Transform.translate уводит
        // её (вместе с hit-test-областью) за правый край, пока она закрыта.
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: width,
          child: Transform.translate(
            offset: Offset(width + _dx, 0),
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: AnimatedOpacity(
                opacity: reveal,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: Row(
                  children: [
                    for (var i = 0; i < widget.actions.length; i++)
                      _ActionButton(
                        action: widget.actions[i],
                        width: widget.actionWidth,
                        style: widget.style,
                        accent: widget.accent,
                        first: i == 0,
                        last: i == widget.actions.length - 1,
                        onTap: () {
                          _close();
                          widget.actions[i].onTap();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final SwipeAction action;
  final double width;
  final VoidCallback onTap;
  final PlayerUIStyle style;
  final Color? accent;
  final bool first;
  final bool last;

  const _ActionButton({
    required this.action,
    required this.width,
    required this.onTap,
    this.style = PlayerUIStyle.simple,
    this.accent,
    this.first = false,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = action.color;
    const dividerColor = Color(0x2EFFFFFF);

    final BoxDecoration deco;
    Color iconColor;
    Color labelColor;

    switch (style) {
      case PlayerUIStyle.simple:
        // Классические плоские цветные плашки.
        deco = BoxDecoration(color: c);
        iconColor = Colors.white;
        labelColor = Colors.white;
        break;

      case PlayerUIStyle.coverFlow3D:
        // Объёмно: вертикальный градиент (тёмный→цвет), блик сверху,
        // тень-глубина + цветное свечение в тон 3D-тайлам.
        deco = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(c, Colors.black, 0.34)!, c],
          ),
          border: Border(
            top: const BorderSide(color: Color(0x40FFFFFF), width: 0.8),
            left: first
                ? BorderSide.none
                : const BorderSide(color: Color(0x1CFFFFFF), width: 0.7),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.42),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: c.withValues(alpha: 0.38),
              blurRadius: 12,
              spreadRadius: -2,
            ),
          ],
        );
        iconColor = Colors.white;
        labelColor = Colors.white;
        break;

      case PlayerUIStyle.neon:
        // Тёмная полупрозрачная плашка + цветное свечение действия и
        // тонкий белый разделитель — в тон мини-плееру и сцене неона.
        deco = BoxDecoration(
          color: const Color(0x1E0D0D11),
          border: Border(
            left: first
                ? BorderSide.none
                : const BorderSide(color: dividerColor, width: 0.7),
          ),
          boxShadow: [
            BoxShadow(
              color: c.withValues(alpha: 0.42),
              blurRadius: 12,
              spreadRadius: -2,
            ),
          ],
        );
        iconColor = Color.lerp(Colors.white, c, 0.45)!;
        labelColor = Colors.white70;
        break;

      case PlayerUIStyle.cinematic:
        // Стекло: белый 8% + белая кромка и мягкое акцентное свечение,
        // как у кинематографичной сцены.
        deco = BoxDecoration(
          color: const Color(0x14FFFFFF),
          border: Border(
            left: first
                ? BorderSide.none
                : const BorderSide(color: dividerColor, width: 0.7),
          ),
          boxShadow: [
            BoxShadow(
              color: (accent ?? c).withValues(alpha: 0.13),
              blurRadius: 14,
              spreadRadius: -3,
            ),
          ],
        );
        iconColor = Color.lerp(Colors.white, c, 0.55)!;
        labelColor = Colors.white70;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: deco,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // B12: поле `tooltip` раньше нигде не использовалось (в нём лежал
            // текст действия). Теперь это настоящая подсказка по long-press
            // и семантика для accessibility.
            Tooltip(
              message: action.tooltip,
              child: Icon(action.icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
