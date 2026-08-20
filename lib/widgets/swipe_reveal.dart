import 'package:flutter/material.dart';

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
class SwipeReveal extends StatefulWidget {
  final Widget child;
  final List<SwipeAction> actions;
  final double actionWidth;
  final BorderRadius borderRadius;

  const SwipeReveal({
    super.key,
    required this.child,
    required this.actions,
    this.actionWidth = 62,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<SwipeReveal> createState() => _SwipeRevealState();
}

class _SwipeRevealState extends State<SwipeReveal> {
  double _dx = 0;
  bool _open = false;
  double get _openWidth => widget.actionWidth * widget.actions.length;

  void _close() {
    if (!_open) return;
    setState(() {
      _dx = 0;
      _open = false;
    });
  }

  void _toggleClose() {
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
        // Action strip behind the tile
        Positioned.fill(
          child: ClipRRect(
            borderRadius: widget.borderRadius,
            child: AnimatedOpacity(
              opacity: reveal,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: IgnorePointer(
                ignoring: !_open,
                child: Row(
                  children: [
                    const Spacer(),
                    for (var i = 0; i < widget.actions.length; i++)
                      _ActionButton(
                        action: widget.actions[i],
                        width: widget.actionWidth,
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

        // Sliding tile
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
          onTap: _toggleClose,
          child: Transform.translate(
            offset: Offset(_dx, 0),
            child: widget.child,
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

  const _ActionButton({
    required this.action,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        color: action.color,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icon, color: Colors.white, size: 20),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
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