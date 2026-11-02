import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme.dart';

class _PointerState {
  final Offset touch;
  final double rotateX;
  final double rotateY;
  final bool active;

  const _PointerState({
    required this.touch,
    required this.rotateX,
    required this.rotateY,
    required this.active,
  });

  const _PointerState.rest()
      : touch = const Offset(0.5, 0.35),
        rotateX = 0,
        rotateY = 0,
        active = false;
}

class HoloCard3D extends StatefulWidget {
  final Widget child;
  final Color accent;
  final bool enabled;
  final double intensity;
  final double maxTiltDegrees;
  final bool sparkles;
  final double borderRadius;

  const HoloCard3D({
    super.key,
    required this.child,
    this.accent = cGold,
    this.enabled = true,
    this.intensity = 0.7,
    this.maxTiltDegrees = 12,
    this.sparkles = true,
    this.borderRadius = 4,
  });

  @override
  State<HoloCard3D> createState() => _HoloCard3DState();
}

class _HoloCard3DState extends State<HoloCard3D>
    with TickerProviderStateMixin {
  final _listenerKey = GlobalKey();
  final _pointer = ValueNotifier<_PointerState>(const _PointerState.rest());

  late final AnimationController _rainbowCtrl;
  late final AnimationController _sparkleCtrl;

  final List<_Sparkle> _sparkles = List.generate(20, (i) {
    final rnd = Random(i);
    return _Sparkle(
      x: rnd.nextDouble(),
      y: rnd.nextDouble(),
      size: 1.0 + rnd.nextDouble() * 2.2,
      delay: rnd.nextDouble(),
      colorIndex: i % 3,
    );
  });

  @override
  void initState() {
    super.initState();
    _rainbowCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 6));
    _sparkleCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _pointer.addListener(_syncAnimations);
  }

  @override
  void dispose() {
    _pointer.removeListener(_syncAnimations);
    _pointer.dispose();
    _rainbowCtrl.dispose();
    _sparkleCtrl.dispose();
    super.dispose();
  }

  void _syncAnimations() {
    if (_pointer.value.active) {
      if (!_rainbowCtrl.isAnimating) _rainbowCtrl.repeat();
      if (!_sparkleCtrl.isAnimating) _sparkleCtrl.repeat();
    } else {
      _rainbowCtrl.stop();
      _sparkleCtrl.stop();
    }
  }

  void _handlePointer(PointerEvent e) {
    final box =
        _listenerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) return;

    final local = e.localPosition;
    final nx = (local.dx / box.size.width).clamp(0.0, 1.0);
    final ny = (local.dy / box.size.height).clamp(0.0, 1.0);
    final maxRad = widget.maxTiltDegrees * pi / 180.0;

    _pointer.value = _PointerState(
      touch: Offset(nx, ny),
      rotateX: -(ny - 0.5) * 2 * maxRad,
      rotateY: (nx - 0.5) * 2 * maxRad,
      active: true,
    );
  }

  void _release() {
    if (!_pointer.value.active) return;
    _pointer.value = const _PointerState.rest();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return MouseRegion(
      onHover: _handlePointer,
      onExit: (_) => _release(),
      child: Listener(
        key: _listenerKey,
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handlePointer,
        onPointerMove: _handlePointer,
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -24, top: -24, right: -24, bottom: -24,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _AmbientGlowPainter(
                    pointer: _pointer,
                    accent: widget.accent,
                  ),
                ),
              ),
            ),
            ValueListenableBuilder<_PointerState>(
              valueListenable: _pointer,
              child: RepaintBoundary(child: widget.child),
              builder: (_, p, cachedCard) {
                return AnimatedContainer(
                  duration: p.active
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0015)
                    ..rotateX(p.rotateX)
                    ..rotateY(p.rotateY),
                  transformAlignment: Alignment.center,
                  child: Stack(
                    children: [
                      cachedCard!,
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(widget.borderRadius),
                            child: Stack(children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _RainbowHoloPainter(
                                    animation: _rainbowCtrl,
                                    active: p.active,
                                    intensity: widget.intensity,
                                  ),
                                ),
                              ),
                              if (p.active)
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _GlarePainter(
                                      pointer: _pointer,
                                      intensity: widget.intensity,
                                    ),
                                  ),
                                ),
                              if (p.active && widget.sparkles)
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _SparklePainter(
                                      sparkles: _sparkles,
                                      animation: _sparkleCtrl,
                                    ),
                                  ),
                                ),
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _VignettePainter(pointer: _pointer),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Sparkle {
  final double x, y, size, delay;
  final int colorIndex;
  const _Sparkle({
    required this.x,
    required this.y,
    required this.size,
    required this.delay,
    required this.colorIndex,
  });
}

// ─────────────────────────────────────────────────────────────
// Painters
// ─────────────────────────────────────────────────────────────

class _RainbowHoloPainter extends CustomPainter {
  final Animation<double> animation;
  final bool active;
  final double intensity;

  _RainbowHoloPainter({
    required this.animation,
    required this.active,
    required this.intensity,
  }) : super(repaint: animation);

  static const _hues = [cGold, cIce, Color(0xFFD4617A), cMagic, cVine, cGold];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final phase = active ? animation.value : 0.15;
    final t = phase * 2 * pi;
    final dx = sin(t) * 0.8;
    final dy = cos(t) * 0.5;
    final opacity = (active ? 0.55 : 0.15) * intensity;

    final gradient = LinearGradient(
      begin: Alignment(-1 + dx, -1 + dy),
      end: Alignment(1 + dx, 1 + dy),
      colors: _hues.map((c) => c.withValues(alpha: opacity)).toList(),
      stops: const [0.0, 0.18, 0.34, 0.52, 0.70, 0.88],
    );

    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.colorDodge
        ..shader = gradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _RainbowHoloPainter old) =>
      old.active != active || old.intensity != intensity;
}

class _GlarePainter extends CustomPainter {
  final ValueListenable<_PointerState> pointer;
  final double intensity;

  _GlarePainter({required this.pointer, required this.intensity})
      : super(repaint: pointer);

  @override
  void paint(Canvas canvas, Size size) {
    final p = pointer.value;
    if (!p.active) return;

    final rect = Offset.zero & size;
    final center =
        Offset(p.touch.dx * size.width, p.touch.dy * size.height);
    final radius = size.longestSide * 0.9;

    // Radial specular — overlay blend, direct on paint.
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.overlay
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.85 * intensity),
            Colors.white.withValues(alpha: 0.22 * intensity),
            Colors.white.withValues(alpha: 0.08 * intensity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.08, 0.18, 0.48],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // Light streak — same overlay, no blur.
    canvas.save();
    canvas.clipRect(rect);
    canvas.translate(center.dx - size.width * 0.3, 0);
    canvas.transform(Matrix4.skewX(-0.32).storage);
    final streakRect =
        Rect.fromLTWH(0, -size.height, size.width * 0.6, size.height * 3);
    canvas.drawRect(
      streakRect,
      Paint()
        ..blendMode = BlendMode.overlay
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.30 * intensity),
            Colors.white.withValues(alpha: 0.34 * intensity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 0.65, 1.0],
        ).createShader(streakRect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlarePainter old) =>
      old.intensity != intensity;
}

class _SparklePainter extends CustomPainter {
  final List<_Sparkle> sparkles;
  final Animation<double> animation;

  _SparklePainter({required this.sparkles, required this.animation})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final phase = animation.value;
    for (final s in sparkles) {
      final lp = (phase + s.delay) % 1.0;
      final twinkle = (sin(lp * 2 * pi) + 1) / 2;
      if (twinkle < 0.2) continue;

      final center = Offset(s.x * size.width, s.y * size.height);
      final color =
          s.colorIndex == 0 ? cGold : s.colorIndex == 1 ? cIce : cMagic;
      final r = s.size * 2.5;

      canvas.drawCircle(
        center, r * 2.0,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = color.withValues(alpha: 0.18 * twinkle),
      );
      canvas.drawCircle(
        center, r,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = color.withValues(alpha: 0.35 * twinkle),
      );
      canvas.drawCircle(
        center, s.size * 0.9,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = Colors.white.withValues(alpha: twinkle),
      );

      if (twinkle > 0.65) {
        final crossPaint = Paint()
          ..blendMode = BlendMode.plus
          ..color = Colors.white.withValues(alpha: (twinkle - 0.65) * 1.4)
          ..strokeWidth = 0.8
          ..strokeCap = StrokeCap.round;
        final arm = s.size * 4;
        canvas.drawLine(
            center.translate(-arm, 0), center.translate(arm, 0), crossPaint);
        canvas.drawLine(
            center.translate(0, -arm), center.translate(0, arm), crossPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => false;
}

class _VignettePainter extends CustomPainter {
  final ValueListenable<_PointerState> pointer;
  _VignettePainter({required this.pointer}) : super(repaint: pointer);

  @override
  void paint(Canvas canvas, Size size) {
    final p = pointer.value;
    final rect = Offset.zero & size;
    final center =
        Offset(p.touch.dx * size.width, p.touch.dy * size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.45),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(
            center: center, radius: size.longestSide * 0.85)),
    );
  }

  @override
  bool shouldRepaint(covariant _VignettePainter old) => false;
}

class _AmbientGlowPainter extends CustomPainter {
  final ValueListenable<_PointerState> pointer;
  final Color accent;

  _AmbientGlowPainter({required this.pointer, required this.accent})
      : super(repaint: pointer);

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 24.0;
    final p = pointer.value;
    final cardW = size.width - inset * 2;
    final cardH = size.height - inset * 2;
    final center =
        Offset(inset + p.touch.dx * cardW, inset + p.touch.dy * cardH);
    final radius = size.longestSide * 0.6;
    final opacity = p.active ? 0.40 : 0.14;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: opacity),
            accent.withValues(alpha: opacity * 0.55),
            accent.withValues(alpha: opacity * 0.22),
            Colors.transparent,
          ],
          stops: const [0.0, 0.28, 0.58, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(covariant _AmbientGlowPainter old) =>
      old.accent != accent;
}