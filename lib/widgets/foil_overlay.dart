import 'dart:math';
import 'package:flutter/material.dart';

/// Paints a subtle static holo pattern across the card face. When the
/// user drags a finger across it, a bright highlight follows the touch
/// and a streak sweeps with it. On release the highlight eases back to
/// a resting position, so cards in a list stay completely still until
/// someone actually touches them.
///
/// Uses a raw [Listener] rather than a [GestureDetector] so it does NOT
/// consume tap events — the parent card remains tappable.
class FoilOverlay extends StatefulWidget {
  final Widget child;
  final Color accent;
  final bool enabled;
  /// 0..1 — overall strength of the foil effect.
  final double intensity;
  /// Seeds the static band pattern, so each card is visibly different.
  final int seed;

  const FoilOverlay({
    super.key,
    required this.child,
    required this.accent,
    this.enabled = true,
    this.intensity = 0.6,
    this.seed = 0,
  });

  @override
  State<FoilOverlay> createState() => _FoilOverlayState();
}

class _FoilOverlayState extends State<FoilOverlay>
    with SingleTickerProviderStateMixin {
  /// Where the highlight rests when nothing is touching the card.
  /// Slightly above centre reads as "lit from above".
  static const Offset _rest = Offset(0.5, 0.35);

  Offset _touch = _rest;
  late final AnimationController _activity;

  @override
  void initState() {
    super.initState();
    _activity = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      value: 0,
    );
  }

  @override
  void dispose() {
    _activity.dispose();
    super.dispose();
  }

  void _onPointer(Offset local, Size size) {
    if (size.isEmpty) return;
    setState(() {
      _touch = Offset(
        (local.dx / size.width).clamp(0.0, 1.0),
        (local.dy / size.height).clamp(0.0, 1.0),
      );
      _activity.value = 1.0;
    });
  }

  void _release() {
    if (_activity.value == 0) return;
    _activity.animateTo(0, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) => _onPointer(e.localPosition, size),
        onPointerMove: (e) => _onPointer(e.localPosition, size),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _activity,
                  builder: (_, _) {
                    final t = _activity.value;
                    final light = Offset.lerp(_touch, _rest, 1 - t)!;
                    return CustomPaint(
                      painter: _FoilPainter(
                        light: light,
                        activity: t,
                        accent: widget.accent,
                        intensity: widget.intensity,
                        seed: widget.seed,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _FoilPainter extends CustomPainter {
  final Offset light;      // normalised 0..1
  final double activity;   // 0..1
  final Color accent;
  final double intensity;
  final int seed;

  _FoilPainter({
    required this.light,
    required this.activity,
    required this.accent,
    required this.intensity,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    _paintBaseBands(canvas, size, rect);
    if (activity > 0.005) _paintHighlight(canvas, size, rect);
  }

  /// Static holo bands — always visible, no animation. Two or three
  /// soft diagonal washes tinted by the accent, offset by [seed] so
  /// every card reads differently at a glance.
  void _paintBaseBands(Canvas canvas, Size size, Rect rect) {
    final rnd = Random(seed);
    final bandCount = 2 + rnd.nextInt(3);
    final lean = (rnd.nextDouble() - 0.5) * 0.7; // -0.35 .. 0.35

    for (int i = 0; i < bandCount; i++) {
      final t = (i + 1) / (bandCount + 1);
      // Rotate through hues anchored on the accent, so cards with
      // different accents look genuinely different, not just recoloured.
      final accentHue = HSLColor.fromColor(accent).hue;
      final hue = (accentHue + (i - bandCount / 2) * 35 + rnd.nextDouble() * 20) % 360;

      final band = HSLColor.fromAHSL(
        0.055 * intensity,
        hue,
        0.65,
        0.60,
      ).toColor();

      final centerX = size.width * (0.5 + lean + (t - 0.5) * 0.6);
      final shaderRect = Rect.fromCenter(
        center: Offset(centerX, size.height * 0.5),
        width: size.longestSide * 0.55,
        height: size.longestSide * 1.6,
      );

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.transparent, band, Colors.transparent],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(shaderRect);
      canvas.drawRect(rect, paint);
    }
  }

  /// The moving light. A soft radial halo (white core → accent ring)
  /// plus a bright streak that sweeps toward the touch point.
  void _paintHighlight(Canvas canvas, Size size, Rect rect) {
    final center = Offset(light.dx * size.width, light.dy * size.height);
    final radius = size.longestSide * 0.75;

    // Halo
    final halo = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.20 * activity * intensity),
          accent.withValues(alpha: 0.12 * activity * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawRect(rect, halo);

    // Streak — reads as the "shine" of moving foil.
    final streak = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          accent.withValues(alpha: 0.16 * activity),
          Colors.white.withValues(alpha: 0.14 * activity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawRect(rect, streak);
  }

  @override
  bool shouldRepaint(covariant _FoilPainter old) =>
      old.light != light ||
      old.activity != activity ||
      old.accent != accent ||
      old.intensity != intensity ||
      old.seed != seed;
}