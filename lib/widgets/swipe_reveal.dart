import 'package:flutter/material.dart';

class SwipeAction {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const SwipeAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
}

class SwipeReveal extends StatefulWidget {
  final Widget child;
  final List<SwipeAction> actions;
  final double actionWidth;
  final BorderRadius borderRadius;

  const SwipeReveal({
    super.key,
    required this.child,
    required this.actions,
    this.actionWidth = 54,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<SwipeReveal> createState() => _SwipeRevealState();
}

class _SwipeRevealState extends State<SwipeReveal> {
  double _dx = 0;
  double get _openWidth => widget.actionWidth * widget.actions.length;

  void _close() {
    if (_dx == 0) return;
    setState(() => _dx = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: widget.borderRadius,
            child: Row(
              children: [
                const Spacer(),
                for (var i = 0; i < widget.actions.length; i++)
                  GestureDetector(
                    onTap: () {
                      _close();
                      widget.actions[i].onTap();
                    },
                    child: Container(
                      width: widget.actionWidth,
                      color: widget.actions[i].color,
                      child: Tooltip(
                        message: widget.actions[i].tooltip,
                        child: Icon(
                          widget.actions[i].icon,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(_dx, 0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) {
              setState(() {
                _dx = (_dx + d.delta.dx).clamp(-_openWidth, 0).toDouble();
              });
            },
            onHorizontalDragEnd: (d) {
              final velocity = d.primaryVelocity ?? 0;
              if (velocity < -300 || _dx < -_openWidth / 2) {
                setState(() => _dx = -_openWidth);
              } else {
                setState(() => _dx = 0);
              }
            },
            onTap: _close,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}