import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Provides the current touch position (0..1 UV) from a [HoloCardV2] to
/// any descendant [HoloParallaxLayer] widgets. Layers read this and
/// shift themselves based on their depth.
class HoloCardScope extends InheritedWidget {
  final ValueListenable<Offset> touch;
  final double maxParallaxOffset;

  const HoloCardScope({
    super.key,
    required this.touch,
    required this.maxParallaxOffset,
    required super.child,
  });

  static HoloCardScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HoloCardScope>();

  @override
  bool updateShouldNotify(HoloCardScope old) =>
      touch != old.touch || maxParallaxOffset != old.maxParallaxOffset;
}

/// Wraps a child in a parallax transform driven by the enclosing
/// [HoloCardV2]'s touch position.
///
/// [depth] semantics:
///   0.0  → locked to card surface (no shift)
///   0.4  → printed content (bio, body text)
///   0.7  → meta info (style, cadence)
///   1.0  → floating accents (chips, tags, status dot)
///   1.5  → very foreground (decorative flourishes)
///  negative → sunk into the card (moves opposite)
class HoloParallaxLayer extends StatelessWidget {
  final double depth;
  final Widget child;

  const HoloParallaxLayer({
    super.key,
    required this.depth,
    required this.child,
  });

    @override
  Widget build(BuildContext context) {
    final scope = HoloCardScope.maybeOf(context);
    if (scope == null || depth == 0) return child;

    return ValueListenableBuilder<Offset>(
      valueListenable: scope.touch,
      child: child,
      builder: (_, touch, child) {
        final factor = scope.maxParallaxOffset * depth * 2.0;
        final dx = (touch.dx - 0.5) * factor;
        final dy = (touch.dy - 0.5) * factor;
        
        return RepaintBoundary( // <--- ADD THIS
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: child,
          ),
        );
      },
    );
  }
}