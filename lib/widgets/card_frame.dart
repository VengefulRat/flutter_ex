import 'package:flutter/material.dart';

/// A compact, procedural spec for a TCG card frame.
///
/// Everything the frame draws is derived from [seed] plus a handful
/// of on/off flags, so an entire card style costs a few bytes on disk
/// while still allowing tens of thousands of unique combinations.
class CardFrameSpec {
  final int seed;
  final Color accent;
  final bool glow;    // soft outer glow on the corners
  final bool ornate;  // small diamonds inside each corner
  final bool dense;   // more tick marks / rails

  const CardFrameSpec({
    required this.seed,
    required this.accent,
    this.glow = false,
    this.ornate = false,
    this.dense = false,
  });

  CardFrameSpec copyWith({
    int? seed,
    Color? accent,
    bool? glow,
    bool? ornate,
    bool? dense,
  }) =>
      CardFrameSpec(
        seed: seed ?? this.seed,
        accent: accent ?? this.accent,
        glow: glow ?? this.glow,
        ornate: ornate ?? this.ornate,
        dense: dense ?? this.dense,
      );
}

/// Wraps [child] in a procedurally-drawn frame. Use on the card face;
/// the painter draws to the same bounds as the child, so it will sit
/// exactly around whatever you pass in.
class CardFrame extends StatelessWidget {
  final CardFrameSpec spec;
  final Widget child;
  /// 0..1 for animated glow. Leave 0 for static cards.
  final double pulse;

  const CardFrame({
    super.key,
    required this.spec,
    required this.child,
    this.pulse = 0,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _CardFramePainter(spec: spec, pulse: pulse),
        child: child,
      );
}

class _CardFramePainter extends CustomPainter {
  final CardFrameSpec spec;
  final double pulse;
  _CardFramePainter({required this.spec, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    // EDIT 8: Old procedural border retired.
    // This painter used to draw the whole basic border system:
    // outer hairlines, seed-randomized corner brackets (long / short /
    // thick), mid-rails, tick marks, inner guide line, and the glow
    // halo under the brackets. The AnimatedBorder frame is the border
    // now, so all of that is intentionally drawn as nothing.
    //
    // CardFrame / CardFrameSpec are kept as a no-op wrapper so
    // LoreCardFace (and anything else using CardFrame) needs no changes.
    // `canvas` / `size` are intentionally unused here.
  }

  @override
  bool shouldRepaint(covariant _CardFramePainter old) =>
      old.pulse != pulse ||
      old.spec.seed != spec.seed ||
      old.spec.accent != spec.accent ||
      old.spec.glow != spec.glow ||
      old.spec.ornate != spec.ornate ||
      old.spec.dense != spec.dense;
}