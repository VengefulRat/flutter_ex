import 'dart:math';
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
    final rnd = Random(spec.seed);
    final color = spec.accent;

    // ── Derived procedural params ──
    final cornerLen     = 10.0 + rnd.nextDouble() * 18;   // 10–28
    final cornerThick   = 1.2  + rnd.nextDouble() * 2.2;  // 1.2–3.4
    final innerInset    = 5.0  + rnd.nextDouble() * 4.0;  // 5–9
    final hasTopRail    = rnd.nextBool();
    final hasBottomRail = rnd.nextBool();
    final hasLeftRail   = rnd.nextBool();
    final hasRightRail  = rnd.nextBool();
    final tickCount     = spec.dense ? 5 + rnd.nextInt(5) : 2 + rnd.nextInt(3);

    // ── Outer hairlines ──
    final outerPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.square;
    canvas.drawRect(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      outerPaint,
    );

    // ── Corner brackets ──
    final bracketPath = Path()
      ..moveTo(0, cornerLen)
      ..lineTo(0, 0)
      ..lineTo(cornerLen, 0)
      ..moveTo(size.width - cornerLen, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, cornerLen)
      ..moveTo(0, size.height - cornerLen)
      ..lineTo(0, size.height)
      ..lineTo(cornerLen, size.height)
      ..moveTo(size.width - cornerLen, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, size.height - cornerLen);

    // Glow pass first so the crisp bracket sits on top of its own halo.
    if (spec.glow) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.30 + pulse * 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cornerThick * 2.6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(bracketPath, glowPaint);
    }

    final bracketPaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cornerThick
      ..strokeCap = StrokeCap.square;
    canvas.drawPath(bracketPath, bracketPaint);

    // ── Mid-rails (partial lines centred on each edge) ──
    final railPaint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = cornerThick * 0.7
      ..strokeCap = StrokeCap.square;

    if (hasTopRail || hasBottomRail) {
      final railLen = size.width * (0.22 + rnd.nextDouble() * 0.26);
      if (hasTopRail) {
        canvas.drawLine(
          Offset(size.width / 2 - railLen / 2, 0.5),
          Offset(size.width / 2 + railLen / 2, 0.5),
          railPaint,
        );
      }
      if (hasBottomRail) {
        canvas.drawLine(
          Offset(size.width / 2 - railLen / 2, size.height - 0.5),
          Offset(size.width / 2 + railLen / 2, size.height - 0.5),
          railPaint,
        );
      }
    }
    if (hasLeftRail || hasRightRail) {
      final railLen = size.height * (0.22 + rnd.nextDouble() * 0.26);
      if (hasLeftRail) {
        canvas.drawLine(
          Offset(0.5, size.height / 2 - railLen / 2),
          Offset(0.5, size.height / 2 + railLen / 2),
          railPaint,
        );
      }
      if (hasRightRail) {
        canvas.drawLine(
          Offset(size.width - 0.5, size.height / 2 - railLen / 2),
          Offset(size.width - 0.5, size.height / 2 + railLen / 2),
          railPaint,
        );
      }
    }

    // ── Tick marks along top and bottom ──
    final tickPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.square;
    for (int i = 0; i < tickCount; i++) {
      final x = size.width * (i + 1) / (tickCount + 1);
      if (x < cornerLen + 4 || x > size.width - cornerLen - 4) continue;
      canvas.drawLine(Offset(x, 0), Offset(x, 4), tickPaint);
      canvas.drawLine(
          Offset(x, size.height - 4), Offset(x, size.height), tickPaint);
    }

    // ── Inner guide line ──
    canvas.drawRect(
      Rect.fromLTWH(
        innerInset,
        innerInset,
        size.width - innerInset * 2,
        size.height - innerInset * 2,
      ),
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // ── Corner ornaments ──
    if (spec.ornate) {
      final diamondPaint = Paint()..color = color.withValues(alpha: 0.7);
      final d = innerInset + 5;
      void diamond(Offset c, double r) {
        final p = Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r, c.dy)
          ..lineTo(c.dx, c.dy + r)
          ..lineTo(c.dx - r, c.dy)
          ..close();
        canvas.drawPath(p, diamondPaint);
      }
      diamond(Offset(d, d), 2.5);
      diamond(Offset(size.width - d, d), 2.5);
      diamond(Offset(d, size.height - d), 2.5);
      diamond(Offset(size.width - d, size.height - d), 2.5);
    }
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