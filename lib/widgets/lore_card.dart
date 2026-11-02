import 'package:flutter/material.dart';
import '../theme.dart';

class Lore3DCard extends StatefulWidget {
  final Widget child;
  final Color foilColor;
  const Lore3DCard({
    super.key,
    required this.child,
    this.foilColor = cGold,
  });

  @override
  State<Lore3DCard> createState() => _Lore3DCardState();
}

class _Lore3DCardState extends State<Lore3DCard> {
  double _rotateX = 0;
  double _rotateY = 0;
  Offset _glare = Offset.zero;
  bool _active = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight == double.infinity
          ? 300.0
          : constraints.maxHeight;

      return Listener(
        onPointerDown: (e) => _update(e.localPosition, w, h, true),
        onPointerMove: (e) => _update(e.localPosition, w, h, true),
        onPointerUp: (_) => _reset(),
        onPointerCancel: (_) => _reset(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateX(_rotateX)
            ..rotateY(_rotateY),
          transformAlignment: Alignment.center,
          child: Stack(children: [
            widget.child,
            if (_active)
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRect(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(
                            (_glare.dx / w) * 2 - 1,
                            (_glare.dy / h) * 2 - 1,
                          ),
                          radius: 1.1,
                          colors: [
                            widget.foilColor.withValues(alpha: 0.35),
                            widget.foilColor.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.35, 0.7],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      );
    },
  );

  void _update(Offset local, double w, double h, bool active) {
    setState(() {
      _active = active;
      // Cap tilt at ~8 degrees each direction
      _rotateY = ((local.dx / w) - 0.5) * 0.28;
      _rotateX = (0.5 - (local.dy / h)) * 0.28;
      _glare = local;
    });
  }

  void _reset() {
    setState(() {
      _rotateX = 0;
      _rotateY = 0;
      _active = false;
    });
  }
}