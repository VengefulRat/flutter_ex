import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../settings.dart';

enum AnimatedBorderPattern {
  waves,
  spikes,
  gears,
  dice,
  swords,
  leaves,
  shields,
  flames,
  stars,
  runes,
  thorns,
  feathers,
  claws,
}

class AnimatedBorder extends StatefulWidget {
  final Widget child;
  final Color color;
  final AnimatedBorderPattern? pattern;
  final double? borderWidth;
  final double? waviness;
  final double? opacity;
  final double? speed;

  /// How far the frame floats outside the card.
  /// 0 = frame sits exactly on the card edge.
  /// Positive = frame floats outside the card, card size unchanged.
  /// Negative = frame tucks inside the card, card size unchanged.
  /// This never changes the card's size — only where the frame is painted.
  final double? frameOutset;

  const AnimatedBorder({
    super.key,
    required this.child,
    required this.color,
    this.pattern,
    this.borderWidth,
    this.waviness,
    this.opacity,
    this.speed,
    this.frameOutset,
  });

  @override
  State<AnimatedBorder> createState() => _AnimatedBorderState();
}

/// Per-pattern breathing room, added on top of the user's Frame outset
/// slider. The slider is still the master control — this just means
/// Stars/Runes always float a touch prouder than Waves, without the
/// user having to re-drag the slider on every pattern switch.
///
/// An explicit widget.frameOutset still wins outright (see build):
/// this bonus only applies to the settings-driven outset.
const Map<AnimatedBorderPattern, double> _patternOutsetBonus = {
  AnimatedBorderPattern.waves: 0,
  AnimatedBorderPattern.spikes: 0,
  AnimatedBorderPattern.gears: 0,
  AnimatedBorderPattern.dice: 2,
  AnimatedBorderPattern.swords: 1,
  AnimatedBorderPattern.leaves: 1,
  AnimatedBorderPattern.shields: 1,
  AnimatedBorderPattern.flames: 2,
  AnimatedBorderPattern.stars: 4,
  AnimatedBorderPattern.runes: 4,
  AnimatedBorderPattern.thorns: 2,
  AnimatedBorderPattern.feathers: 3,
  AnimatedBorderPattern.claws: 1,
};

/// Per-pattern thickness feel, multiplied on top of the user's
/// Thickness slider. Slider is still the master control — this just
/// keeps each pattern reading correctly at any slider value.
const Map<AnimatedBorderPattern, double> _patternThicknessScale = {
  AnimatedBorderPattern.waves: 1.0,
  AnimatedBorderPattern.spikes: 1.0,
  AnimatedBorderPattern.gears: 1.0,
  AnimatedBorderPattern.dice: 1.0,
  AnimatedBorderPattern.swords: 1.15,
  AnimatedBorderPattern.leaves: 1.0,
  AnimatedBorderPattern.shields: 1.2,
  AnimatedBorderPattern.flames: 0.9,
  AnimatedBorderPattern.stars: 0.95,
  AnimatedBorderPattern.runes: 0.9,
  AnimatedBorderPattern.thorns: 1.1,
  AnimatedBorderPattern.feathers: 0.85,
  AnimatedBorderPattern.claws: 1.1,
};

/// Per-pattern waviness feel, multiplied on top of the user's
/// Waviness slider. High = wilder / looser, low = crisper / tighter.
/// Gears and Runes stay low on purpose: gears need to mesh cleanly,
/// runes need to stay readable.
const Map<AnimatedBorderPattern, double> _patternWavinessScale = {
  AnimatedBorderPattern.waves: 1.2,
  AnimatedBorderPattern.spikes: 0.9,
  AnimatedBorderPattern.gears: 0.7,
  AnimatedBorderPattern.dice: 0.8,
  AnimatedBorderPattern.swords: 0.9,
  AnimatedBorderPattern.leaves: 1.2,
  AnimatedBorderPattern.shields: 0.8,
  AnimatedBorderPattern.flames: 1.4,
  AnimatedBorderPattern.stars: 0.85,
  AnimatedBorderPattern.runes: 0.7,
  AnimatedBorderPattern.thorns: 1.3,
  AnimatedBorderPattern.feathers: 1.25,
  AnimatedBorderPattern.claws: 1.1,
};

class _AnimatedBorderState extends State<AnimatedBorder>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _diceController;
  final _random = math.Random();
  List<int> _diceValues = [3, 5, 2, 6];
  bool _isRolling = false;

  double get _speed => widget.speed ?? appSettings.animatedBorderSpeed;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (3000 / _speed).round()),
    )..repeat();
    _diceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _diceController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isRolling = false;
          _diceValues = List.generate(4, (_) => _random.nextInt(6) + 1);
        });
      }
    });
  }

  void _rollDice() {
    if (_isRolling) return;
    setState(() => _isRolling = true);
    _diceController.forward(from: 0);
  }

  @override
  void didUpdateWidget(AnimatedBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newSpeed = widget.speed ?? appSettings.animatedBorderSpeed;
    if (newSpeed != _speed) {
      _controller.duration = Duration(milliseconds: (3000 / newSpeed).round());
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _diceController.dispose();
    super.dispose();
  }

  AnimatedBorderPattern _parse(String s) {
    switch (s) {
      case 'spikes':
        return AnimatedBorderPattern.spikes;
      case 'gears':
        return AnimatedBorderPattern.gears;
      case 'dice':
        return AnimatedBorderPattern.dice;
      case 'swords':
        return AnimatedBorderPattern.swords;
      case 'leaves':
        return AnimatedBorderPattern.leaves;
      case 'shields':
        return AnimatedBorderPattern.shields;
      case 'flames':
        return AnimatedBorderPattern.flames;
      case 'stars':
        return AnimatedBorderPattern.stars;
      case 'runes':
        return AnimatedBorderPattern.runes;
      case 'thorns':
        return AnimatedBorderPattern.thorns;
      case 'feathers':
        return AnimatedBorderPattern.feathers;
      case 'claws':
        return AnimatedBorderPattern.claws;
      default:
        return AnimatedBorderPattern.waves;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _diceController, appSettings]),
      builder: (_, _) {
                // pattern first, so thickness can use it for the per-pattern scale.
        // No new variables here — same 4 declarations, just reordered.
        final pattern = widget.pattern ?? _parse(appSettings.animatedBorderPattern);
        final thickness =
            (widget.borderWidth ?? appSettings.animatedBorderThickness) *
                (_patternThicknessScale[pattern] ?? 1.0);
        final waviness =
            (widget.waviness ?? appSettings.animatedBorderWaviness) *
                (_patternWavinessScale[pattern] ?? 1.0);
        final opacity = widget.opacity ?? appSettings.animatedBorderOpacity;
        final col = widget.color.withValues(alpha: opacity);

        CustomPainter painter;
        switch (pattern) {
          case AnimatedBorderPattern.spikes:
            painter = _SpikesPainter(
              progress: _controller.value,
              color: col,
              borderWidth: thickness,
              waviness: waviness,
            );
            break;
          case AnimatedBorderPattern.gears:
            painter = _GearsPainter(
              progress: _controller.value,
              color: col,
              borderWidth: thickness,
              waviness: waviness,
            );
            break;
          case AnimatedBorderPattern.dice:
            painter = _DicePainter(
              progress: _isRolling ? _diceController.value : 0,
              isRolling: _isRolling,
              diceValues: _diceValues,
              color: col,
              borderWidth: thickness,
              waviness: waviness,
            );
            break;
          case AnimatedBorderPattern.swords:
            painter = _SwordsPainter(
              progress: _controller.value,
              color: col,
              borderWidth: thickness,
              waviness: waviness,
            );
            break;
          case AnimatedBorderPattern.leaves:
            painter = _LeavesPainter(
              progress: _controller.value,
              color: col,
              borderWidth: thickness,
              waviness: waviness,
            );
            break;
          case AnimatedBorderPattern.shields:
            painter = _ShieldsPainter(
              progress: _controller.value,
              color: col,
              borderWidth: thickness,
              waviness: waviness,
            );
            break;
          case AnimatedBorderPattern.flames:
            painter = _FlamesPainter(
              progress: _controller.value,
              color: col,
              borderWidth: thickness,
              waviness: waviness,
            );
            break;
          case AnimatedBorderPattern.stars:
            painter = _StarsPainter(
              progress: _controller.value,
              color: col,
              borderWidth: thickness,
              waviness: waviness,
            );
            break;
          case AnimatedBorderPattern.runes:
            painter = _RunesPainter(
              progress: _controller.value,
              color: col,
              borderWidth: thickness,
              waviness: waviness,
            );
            break;
          case AnimatedBorderPattern.thorns:
            painter = _ThornsPainter(
              progress: _controller.value,
              color: col,
              borderWidth: thickness,
              waviness: waviness,
            );
            break;
          case AnimatedBorderPattern.feathers:
            painter = _FeathersPainter(
              progress: _controller.value,
              color: col,
              borderWidth: thickness,
              waviness: waviness,
            );
            break;
          case AnimatedBorderPattern.claws:
            painter = _ClawsPainter(
              progress: _controller.value,
              color: col,
              borderWidth: thickness,
              waviness: waviness,
            );
            break;
          default:
            painter = _WavesPainter(
              progress: _controller.value,
              color: col,
              borderWidth: thickness,
              waviness: waviness,
            );
        }

        // DECOUPLED LAYOUT:
        // - widget.child is laid out at its NATURAL size, with no padding.
        //   Thickness / waviness / pattern can no longer resize the card.
        // - The frame is a separate overlay layer, positioned with a
        //   negative inset so it can float OUTSIDE the card.
        // - Stack clipBehavior is Clip.none so motifs are allowed to
        //   bleed past the card edge instead of being clipped to it.
        // - foregroundPainter is kept: the frame still paints ON TOP,
        //   just on its own layer now, not as part of the card.
        // Effective outset = user slider + per-pattern bonus.
        // Effective outset = user slider + per-pattern bonus.
        // pattern was already resolved above, before the painter switch,
        // so we just re-use it here. An explicit widget.frameOutset
        // bypasses the bonus — explicit wins.
        final outset =
            widget.frameOutset ??
            (appSettings.animatedBorderFrameOutset +
                (_patternOutsetBonus[pattern] ?? 0));
        final content = Stack(
          clipBehavior: Clip.none,
          children: [
            widget.child,
            Positioned(
              left: -outset,
              top: -outset,
              right: -outset,
              bottom: -outset,
              child: CustomPaint(
                foregroundPainter: painter,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        );

        if (pattern == AnimatedBorderPattern.dice) {
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _rollDice,
            onPanUpdate: (_) => _rollDice(),
            child: content,
          );
        }
        return content;
      },
    );
  }
}

// ---------- WAVES ----------
class _WavesPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double borderWidth;
  final double waviness;
  _WavesPainter({
    required this.progress,
    required this.color,
    required this.borderWidth,
    required this.waviness,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;
    const waveLength = 28.0;
    Path buildEdge(Offset start, Offset end) {
      final path = Path()..moveTo(start.dx, start.dy);
      final total = (end - start).distance;
      final steps = (total / waveLength).ceil();
      for (int i = 0; i <= steps; i++) {
        final t = i / steps;
        final base = Offset.lerp(start, end, t)!;
        final dir = (end - start) / total;
        final perp = Offset(-dir.dy, dir.dx);
        final phase =
            (t * total / waveLength * math.pi * 2) + (progress * math.pi * 2);
        final offset = math.sin(phase) * waviness;
        path.lineTo(base.dx + perp.dx * offset, base.dy + perp.dy * offset);
      }
      return path;
    }

    final inset = borderWidth / 2;
    final tl = Offset(inset, inset);
    final tr = Offset(size.width - inset, inset);
    final br = Offset(size.width - inset, size.height - inset);
    final bl = Offset(inset, size.height - inset);
    canvas.drawPath(buildEdge(tl, tr), paint);
    canvas.drawPath(buildEdge(tr, br), paint);
    canvas.drawPath(buildEdge(br, bl), paint);
    canvas.drawPath(buildEdge(bl, tl), paint);
  }

  @override
  bool shouldRepaint(_WavesPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.borderWidth != borderWidth ||
      old.waviness != waviness;
}

// ---------- SPIKES ----------
class _SpikesPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double borderWidth;
  final double waviness;
  _SpikesPainter({
    required this.progress,
    required this.color,
    required this.borderWidth,
    required this.waviness,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final toothWidth = (14 + waviness * 1.2).clamp(10.0, 32.0);
    final toothHeight = (borderWidth * 1.6).clamp(3.0, 14.0);
    final slide = math.sin(progress * math.pi * 2) * toothWidth * 0.35;
    Path buildEdge(Offset start, Offset end) {
      final path = Path();
      final total = (end - start).distance;
      final dir = (end - start) / total;
      final perp = Offset(-dir.dy, dir.dx);
      final count = (total / toothWidth).ceil();
      for (int i = 0; i < count; i++) {
        final baseT = (i * toothWidth + slide) / total;
        if (baseT < 0 || baseT > 1) continue;
        final base = Offset.lerp(start, end, baseT.clamp(0.0, 1.0))!;
        final nextT = ((i + 1) * toothWidth + slide) / total;
        final next = Offset.lerp(start, end, nextT.clamp(0.0, 1.0))!;
        final mid = Offset.lerp(base, next, 0.5)! + perp * toothHeight;
        path.moveTo(base.dx, base.dy);
        path.lineTo(mid.dx, mid.dy);
        path.lineTo(next.dx, next.dy);
        path.close();
      }
      return path;
    }

    const inset = 2.0;
    final tl = Offset(inset, inset);
    final tr = Offset(size.width - inset, inset);
    final br = Offset(size.width - inset, size.height - inset);
    final bl = Offset(inset, size.height - inset);
    canvas.drawPath(buildEdge(tl, tr), paint);
    canvas.drawPath(buildEdge(tr, br), paint);
    canvas.drawPath(buildEdge(br, bl), paint);
    canvas.drawPath(buildEdge(bl, tl), paint);
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - inset * 2,
        size.height - inset * 2,
      ),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_SpikesPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.borderWidth != borderWidth ||
      old.waviness != waviness;
}

// ---------- GEARS ----------
class _GearsPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double borderWidth;
  final double waviness;
  _GearsPainter({
    required this.progress,
    required this.color,
    required this.borderWidth,
    required this.waviness,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final gearRadius = (6 + borderWidth * 1.8).clamp(8.0, 22.0);
    final spacing = (gearRadius * 2 + 4 + waviness).clamp(20.0, 60.0);
    const toothCount = 8;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    void drawGear(Offset center, int index) {
      final direction = index.isEven ? 1.0 : -1.0;
      final angle = progress * math.pi * 2 * direction;
      for (int i = 0; i < toothCount; i++) {
        final a = angle + (i / toothCount) * math.pi * 2;
        final toothBase =
            center + Offset(math.cos(a), math.sin(a)) * gearRadius;
        final toothTip =
            center + Offset(math.cos(a), math.sin(a)) * (gearRadius + 3.5);
        final perp = Offset(-math.sin(a), math.cos(a));
        const halfWidth = 2.0;
        final path = Path()
          ..moveTo(
            toothBase.dx + perp.dx * halfWidth,
            toothBase.dy + perp.dy * halfWidth,
          )
          ..lineTo(
            toothTip.dx + perp.dx * halfWidth * 0.6,
            toothTip.dy + perp.dy * halfWidth * 0.6,
          )
          ..lineTo(
            toothTip.dx - perp.dx * halfWidth * 0.6,
            toothTip.dy - perp.dy * halfWidth * 0.6,
          )
          ..lineTo(
            toothBase.dx - perp.dx * halfWidth,
            toothBase.dy - perp.dy * halfWidth,
          )
          ..close();
        canvas.drawPath(path, fillPaint);
      }
      canvas.drawCircle(center, gearRadius, strokePaint);
      canvas.drawCircle(center, gearRadius * 0.45, strokePaint);
      canvas.drawCircle(center, 1.5, fillPaint);
      for (int i = 0; i < 4; i++) {
        final a = angle + (i / 4) * math.pi * 2;
        canvas.drawLine(
          center,
          center + Offset(math.cos(a), math.sin(a)) * gearRadius * 0.45,
          strokePaint,
        );
      }
    }

    int gearIndex = 0;
    void drawEdge(Offset start, Offset end) {
      final total = (end - start).distance;
      final count = (total / spacing).floor();
      for (int i = 0; i < count; i++) {
        final t =
            (i + 0.5) /
            count; // half-step offset, never lands exactly on corner
        drawGear(Offset.lerp(start, end, t)!, gearIndex);
        gearIndex++;
      }
    }

    final inset = gearRadius + 4;
    final tl = Offset(inset, inset);
    final tr = Offset(size.width - inset, inset);
    final br = Offset(size.width - inset, size.height - inset);
    final bl = Offset(inset, size.height - inset);
    drawEdge(tl, tr);
    drawEdge(tr, br);
    drawEdge(br, bl);
    drawEdge(bl, tl);
  }

  @override
  bool shouldRepaint(_GearsPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.borderWidth != borderWidth ||
      old.waviness != waviness;
}

// ---------- DICE ----------
class _DicePainter extends CustomPainter {
  final double progress;
  final bool isRolling;
  final List<int> diceValues;
  final Color color;
  final double borderWidth;
  final double waviness;
  _DicePainter({
    required this.progress,
    required this.isRolling,
    required this.diceValues,
    required this.color,
    required this.borderWidth,
    required this.waviness,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final dieSize = (18 + borderWidth * 3).clamp(22.0, 48.0);
    final half = dieSize / 2;
    final bounce = isRolling
        ? math.sin(progress * math.pi * 3) * (2 + waviness * 0.5)
        : 0.0;
    final rotation = isRolling ? progress * math.pi * 4 : 0.0;
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final pipPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    List<Offset> pipsFor(int value, double r) {
      final c = Offset(0, 0);
      final o = r * 0.55;
      switch (value) {
        case 1:
          return [c];
        case 2:
          return [Offset(-o, -o), Offset(o, o)];
        case 3:
          return [Offset(-o, -o), c, Offset(o, o)];
        case 4:
          return [Offset(-o, -o), Offset(o, -o), Offset(-o, o), Offset(o, o)];
        case 5:
          return [
            Offset(-o, -o),
            Offset(o, -o),
            c,
            Offset(-o, o),
            Offset(o, o),
          ];
        default:
          return [
            Offset(-o, -o),
            Offset(o, -o),
            Offset(-o, 0),
            Offset(o, 0),
            Offset(-o, o),
            Offset(o, o),
          ];
      }
    }

    void drawDie(Offset center, int value, int index) {
      canvas.save();
      final rot = rotation + index * 0.4;
      final bounceOffset = bounce * (index.isEven ? 1 : -1);
      canvas.translate(center.dx, center.dy + bounceOffset);
      canvas.rotate(rot);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: dieSize,
        height: dieSize,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        fillPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        strokePaint,
      );
      final pipRadius = (dieSize * 0.09).clamp(1.5, 3.5);
      for (final p in pipsFor(value, half * 0.7)) {
        canvas.drawCircle(p, pipRadius, pipPaint);
      }
      canvas.restore();
    }

    final inset = half + 2;
    drawDie(Offset(inset, inset), diceValues[0], 0);
    drawDie(Offset(size.width - inset, inset), diceValues[1], 1);
    drawDie(Offset(size.width - inset, size.height - inset), diceValues[2], 2);
    drawDie(Offset(inset, size.height - inset), diceValues[3], 3);
    canvas.drawRect(
      Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
      strokePaint..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_DicePainter old) =>
      old.progress != progress ||
      old.isRolling != isRolling ||
      old.diceValues != diceValues ||
      old.color != color ||
      old.borderWidth != borderWidth ||
      old.waviness != waviness;
}

// ---------- HELPER: walk around perimeter - ONE loop, no corner overlap ----------
typedef _ShapeDrawer =
    void Function(
      Canvas canvas,
      Offset pos,
      double edgeAngle,
      int index,
      double progress,
    );

void _walkPerimeter(
  Canvas canvas,
  Size size,
  double spacing,
  double inset,
  _ShapeDrawer draw,
  double progress,
) {
  final w = size.width - inset * 2;
  final h = size.height - inset * 2;
  final perimeter = 2 * (w + h);
  final count = (perimeter / spacing).floor().clamp(4, 200);
  final step = perimeter / count;

  for (int i = 0; i < count; i++) {
    final d =
        i * step +
        step / 2; // offset by half-step so we never land exactly on a corner
    Offset pos;
    double angle;
    if (d < w) {
      // Top edge, left -> right
      pos = Offset(inset + d, inset);
      angle = 0.0;
    } else if (d < w + h) {
      // Right edge, top -> bottom
      pos = Offset(size.width - inset, inset + (d - w));
      angle = math.pi / 2;
    } else if (d < 2 * w + h) {
      // Bottom edge, right -> left
      pos = Offset(size.width - inset - (d - w - h), size.height - inset);
      angle = math.pi;
    } else {
      // Left edge, bottom -> top
      pos = Offset(inset, size.height - inset - (d - 2 * w - h));
      angle = -math.pi / 2;
    }
    draw(canvas, pos, angle, i, progress);
  }
}

// ---------- SWORDS - DETAILED ----------
class _SwordsPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double borderWidth;
  final double waviness;
  _SwordsPainter({
    required this.progress,
    required this.color,
    required this.borderWidth,
    required this.waviness,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final bladeFill = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    final bladeEdge = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final gripPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final len = (20 + borderWidth * 2).clamp(24.0, 44.0);
    final spacing = len + 14 + waviness;
    _walkPerimeter(canvas, size, spacing, 14, (
      canvas,
      pos,
      edgeAngle,
      idx,
      prog,
    ) {
      final sway = math.sin(prog * math.pi * 2 + idx * 0.8) * 0.18;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(edgeAngle - math.pi / 2 + sway);
      // BLADE - long, pointed, with fuller
      final blade = Path()
        ..moveTo(0, -len / 2)
        ..lineTo(3.2, -len / 2 + 7)
        ..lineTo(3.2, 2)
        ..lineTo(0, 4)
        ..lineTo(-3.2, 2)
        ..lineTo(-3.2, -len / 2 + 7)
        ..close();
      canvas.drawPath(blade, bladeFill);
      canvas.drawPath(blade, bladeEdge);
      // Fuller - centre line down blade
      canvas.drawLine(
        Offset(0, -len / 2 + 8),
        Offset(0, 1),
        bladeEdge..strokeWidth = 0.8,
      );
      // CROSSGUARD - curved up at ends
      final guard = Path()
        ..moveTo(-9, 4)
        ..quadraticBezierTo(-6, 1, -9, -1)
        ..lineTo(-2, 3)
        ..lineTo(2, 3)
        ..lineTo(9, -1)
        ..quadraticBezierTo(6, 1, 9, 4)
        ..lineTo(2, 6)
        ..lineTo(-2, 6)
        ..close();
      canvas.drawPath(guard, gripPaint);
      // GRIP - wrapped, 3 lines
      canvas.drawRect(Rect.fromLTWH(-1.8, 6, 3.6, 7), gripPaint);
      for (int i = 0; i < 3; i++) {
        canvas.drawLine(
          Offset(-1.8, 7.5 + i * 2),
          Offset(1.8, 7.5 + i * 2),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.35)
            ..strokeWidth = 0.7,
        );
      }
      // POMMEL - round + gem dot
      canvas.drawCircle(Offset(0, 15), 3.2, gripPaint);
      canvas.drawCircle(
        Offset(0, 15),
        1.2,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..style = PaintingStyle.fill,
      );
      canvas.restore();
    }, progress);
  }

  @override
  bool shouldRepaint(_SwordsPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.borderWidth != borderWidth ||
      old.waviness != waviness;
}

// ---------- LEAVES - DETAILED ----------
class _LeavesPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double borderWidth;
  final double waviness;
  _LeavesPainter({
    required this.progress,
    required this.color,
    required this.borderWidth,
    required this.waviness,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final veinPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    final len = (16 + borderWidth * 1.6).clamp(20.0, 38.0);
    final wid = len * 0.42;
    final spacing = len + 8 + waviness;
    _walkPerimeter(canvas, size, spacing, 14, (
      canvas,
      pos,
      edgeAngle,
      idx,
      prog,
    ) {
      final flutter = math.sin(prog * math.pi * 2 + idx * 1.2) * 0.45;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(edgeAngle + flutter);
      // Leaf body - pointed both ends, slightly bent
      final leaf = Path()
        ..moveTo(0, -len / 2)
        ..quadraticBezierTo(wid, -len * 0.15, wid * 0.7, len * 0.15)
        ..quadraticBezierTo(wid * 0.4, len * 0.35, 0, len / 2)
        ..quadraticBezierTo(-wid * 0.4, len * 0.35, -wid * 0.7, len * 0.15)
        ..quadraticBezierTo(-wid, -len * 0.15, 0, -len / 2)
        ..close();
      canvas.drawPath(leaf, fill);
      canvas.drawPath(leaf, outline);
      // Main vein
      canvas.drawLine(
        Offset(0, -len / 2 + 2),
        Offset(0, len / 2 - 2),
        veinPaint,
      );
      // Side veins - 4 pairs
      for (int i = 0; i < 4; i++) {
        final y = -len * 0.3 + i * len * 0.18;
        canvas.drawLine(Offset(0, y), Offset(wid * 0.6, y + 3), veinPaint);
        canvas.drawLine(Offset(0, y), Offset(-wid * 0.6, y + 3), veinPaint);
      }
      // Stem
      canvas.drawLine(Offset(0, len / 2), Offset(0, len / 2 + 4), outline);
      canvas.restore();
    }, progress);
  }

  @override
  bool shouldRepaint(_LeavesPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.borderWidth != borderWidth ||
      old.waviness != waviness;
}

// ---------- SHIELDS - DETAILED ----------
class _ShieldsPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double borderWidth;
  final double waviness;
  _ShieldsPainter({
    required this.progress,
    required this.color,
    required this.borderWidth,
    required this.waviness,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final innerLine = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    final bossPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final rivetPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = (14 + borderWidth * 1.5).clamp(18.0, 32.0);
    final h = w * 1.35;
    final spacing = w + 10 + waviness;
    _walkPerimeter(canvas, size, spacing, 14, (
      canvas,
      pos,
      edgeAngle,
      idx,
      prog,
    ) {
      final bob = math.sin(prog * math.pi * 2 + idx * 0.9) * 1.5;
      final shine = 0.7 + 0.3 * math.sin(prog * math.pi * 2 + idx * 1.1);
      canvas.save();
      canvas.translate(pos.dx, pos.dy + bob * 0.3);
      canvas.rotate(edgeAngle);
      // OUTER shield shape - heater shield
      final outer = Path()
        ..moveTo(-w / 2, -h / 2)
        ..lineTo(w / 2, -h / 2)
        ..lineTo(w / 2, -h * 0.1)
        ..quadraticBezierTo(w / 2, h * 0.35, 0, h / 2)
        ..quadraticBezierTo(-w / 2, h * 0.35, -w / 2, -h * 0.1)
        ..close();
      canvas.drawPath(outer, fill);
      canvas.drawPath(outer, outline);
      // INNER border - inset shield
      final inset = 3.5;
      final inner = Path()
        ..moveTo(-w / 2 + inset, -h / 2 + inset)
        ..lineTo(w / 2 - inset, -h / 2 + inset)
        ..lineTo(w / 2 - inset, -h * 0.1)
        ..quadraticBezierTo(w / 2 - inset, h * 0.32, 0, h / 2 - inset)
        ..quadraticBezierTo(-w / 2 + inset, h * 0.32, -w / 2 + inset, -h * 0.1)
        ..close();
      canvas.drawPath(inner, innerLine);
      // VERTICAL ridge down centre - gives it depth
      canvas.drawLine(
        Offset(0, -h / 2 + inset),
        Offset(0, h / 2 - inset - 2),
        innerLine..strokeWidth = 0.7,
      );
      // BOSS - centre dome
      canvas.drawCircle(Offset(0, -h * 0.05), w * 0.18 * shine, bossPaint);
      canvas.drawCircle(
        Offset(0, -h * 0.05),
        w * 0.18 * shine,
        outline..strokeWidth = 1.0,
      );
      // Gem dot in boss
      canvas.drawCircle(
        Offset(0, -h * 0.05),
        1.3,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..style = PaintingStyle.fill,
      );
      // RIVETS - 4 corners + top
      final rivets = [
        Offset(-w / 2 + 3, -h / 2 + 3),
        Offset(w / 2 - 3, -h / 2 + 3),
        Offset(-w / 2 + 3, -h * 0.05),
        Offset(w / 2 - 3, -h * 0.05),
        Offset(0, -h / 2 + 3),
      ];
      for (final r in rivets) {
        canvas.drawCircle(r, 1.2, rivetPaint);
      }
      // BOTTOM chevron - little V near point
      final chevron = Path()
        ..moveTo(-w * 0.22, h * 0.18)
        ..lineTo(0, h * 0.28)
        ..lineTo(w * 0.22, h * 0.18);
      canvas.drawPath(chevron, innerLine..strokeWidth = 1.1);
      canvas.restore();
    }, progress);
  }

  @override
  bool shouldRepaint(_ShieldsPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.borderWidth != borderWidth ||
      old.waviness != waviness;
}

// ---------- FLAMES - DETAILED ----------
class _FlamesPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double borderWidth;
  final double waviness;
  _FlamesPainter({
    required this.progress,
    required this.color,
    required this.borderWidth,
    required this.waviness,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final h = (18 + borderWidth * 2).clamp(22.0, 42.0);
    final spacing = 20 + waviness;
    _walkPerimeter(canvas, size, spacing, 14, (
      canvas,
      pos,
      edgeAngle,
      idx,
      prog,
    ) {
      final flick1 = 0.85 + 0.3 * math.sin(prog * math.pi * 2 * 2 + idx * 1.7);
      final flick2 =
          0.8 + 0.35 * math.sin(prog * math.pi * 2 * 3 + idx * 2.3 + 1);
      final lean = math.sin(prog * math.pi * 2 + idx * 0.9) * 0.22;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(edgeAngle - math.pi / 2 + lean);
      // OUTER flame - big, wavy
      final outer = Path()
        ..moveTo(0, -h * flick1)
        ..quadraticBezierTo(9, -h * 0.5, 7, -h * 0.1)
        ..quadraticBezierTo(9, h * 0.25, 4, h / 2)
        ..quadraticBezierTo(0, h * 0.65, -4, h / 2)
        ..quadraticBezierTo(-9, h * 0.25, -7, -h * 0.1)
        ..quadraticBezierTo(-9, -h * 0.5, 0, -h * flick1)
        ..close();
      canvas.drawPath(
        outer,
        Paint()
          ..color = color.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill,
      );
      // MID flame - smaller, offset
      final mid = Path()
        ..moveTo(0, -h * 0.65 * flick2)
        ..quadraticBezierTo(5, -h * 0.3, 4, 0)
        ..quadraticBezierTo(4, h * 0.3, 0, h * 0.45)
        ..quadraticBezierTo(-4, h * 0.3, -4, 0)
        ..quadraticBezierTo(-5, -h * 0.3, 0, -h * 0.65 * flick2)
        ..close();
      canvas.drawPath(
        mid,
        Paint()
          ..color = color.withValues(alpha: 0.6)
          ..style = PaintingStyle.fill,
      );
      // INNER core - hot white-ish centre
      final inner = Path()
        ..moveTo(0, -h * 0.35 * flick1)
        ..quadraticBezierTo(2.5, -h * 0.1, 2, h * 0.2)
        ..quadraticBezierTo(0, h * 0.35, -2, h * 0.2)
        ..quadraticBezierTo(-2.5, -h * 0.1, 0, -h * 0.35 * flick1)
        ..close();
      canvas.drawPath(
        inner,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..style = PaintingStyle.fill,
      );
      // Ember dots
      canvas.drawCircle(
        Offset(3 * math.sin(prog * 5 + idx), -h * 0.7),
        1.1,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      canvas.restore();
    }, progress);
  }

  @override
  bool shouldRepaint(_FlamesPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.borderWidth != borderWidth ||
      old.waviness != waviness;
}

// ---------- STARS ----------
class _StarsPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double borderWidth;
  final double waviness;
  _StarsPainter({
    required this.progress,
    required this.color,
    required this.borderWidth,
    required this.waviness,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final r = (6 + borderWidth).clamp(7.0, 16.0);
    final spacing = r * 2 + 14 + waviness;
    _walkPerimeter(canvas, size, spacing, 12, (
      canvas,
      pos,
      edgeAngle,
      idx,
      prog,
    ) {
      final twinkle = 0.6 + 0.4 * math.sin(prog * math.pi * 2 + idx * 1.3);
      final rot = prog * math.pi * 2 * (idx.isEven ? 1 : -1) * 0.3;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(rot);
      canvas.scale(twinkle);
      final path = Path();
      for (int i = 0; i < 5; i++) {
        final a1 = -math.pi / 2 + i * math.pi * 2 / 5;
        final a2 = a1 + math.pi / 5;
        final outer = Offset(math.cos(a1) * r, math.sin(a1) * r);
        final inner = Offset(math.cos(a2) * r * 0.45, math.sin(a2) * r * 0.45);
        if (i == 0)
          path.moveTo(outer.dx, outer.dy);
        else
          path.lineTo(outer.dx, outer.dy);
        path.lineTo(inner.dx, inner.dy);
      }
      path.close();
      canvas.drawPath(path, fill);
      canvas.restore();
    }, progress);
  }

  @override
  bool shouldRepaint(_StarsPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.borderWidth != borderWidth ||
      old.waviness != waviness;
}

// ---------- RUNES ----------
class _RunesPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double borderWidth;
  final double waviness;
  _RunesPainter({
    required this.progress,
    required this.color,
    required this.borderWidth,
    required this.waviness,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.2 + borderWidth * 0.3).clamp(1.2, 3.0)
      ..strokeCap = StrokeCap.round;
    final glow = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final h = (12 + borderWidth * 1.2).clamp(14.0, 26.0);
    final spacing = 22 + waviness;
    // Rune shapes: simple angular glyphs
    List<List<Offset>> runes = [
      [Offset(0, -0.5), Offset(0, 0.5), Offset(0.4, 0.1)], // like ᚱ
      [
        Offset(-0.4, -0.5),
        Offset(-0.4, 0.5),
        Offset(0.4, -0.1),
        Offset(-0.4, 0.1),
      ], // like ᚼ
      [
        Offset(0, -0.5),
        Offset(0, 0.5),
        Offset(0.4, -0.3),
        Offset(0, 0),
      ], // like ᚠ
      [Offset(-0.4, -0.5), Offset(0.4, -0.5), Offset(0, 0.5)], // like ᚨ
      [
        Offset(0, -0.5),
        Offset(-0.4, 0.5),
        Offset(0.4, 0.5),
        Offset(0, -0.5),
      ], // diamond
    ];
    _walkPerimeter(canvas, size, spacing, 12, (
      canvas,
      pos,
      edgeAngle,
      idx,
      prog,
    ) {
      final pulse = 0.7 + 0.3 * math.sin(prog * math.pi * 2 + idx * 0.9);
      final glyph = runes[idx % runes.length];
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(edgeAngle);
      canvas.scale(pulse);
      for (int i = 0; i < glyph.length - 1; i++) {
        final a = Offset(glyph[i].dx * h, glyph[i].dy * h);
        final b = Offset(glyph[i + 1].dx * h, glyph[i + 1].dy * h);
        canvas.drawLine(a, b, glow);
        canvas.drawLine(a, b, stroke);
      }
      // vertical spine
      canvas.drawLine(Offset(0, -h / 2), Offset(0, h / 2), glow);
      canvas.drawLine(Offset(0, -h / 2), Offset(0, h / 2), stroke);
      canvas.restore();
    }, progress);
  }

  @override
  bool shouldRepaint(_RunesPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.borderWidth != borderWidth ||
      old.waviness != waviness;
}

// ---------- THORNS - DETAILED ----------
class _ThornsPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double borderWidth;
  final double waviness;
  _ThornsPainter({
    required this.progress,
    required this.color,
    required this.borderWidth,
    required this.waviness,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final vinePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final thornPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final leafPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    final len = (12 + borderWidth * 1.5).clamp(16.0, 32.0);
    final spacing = 18 + waviness;
    _walkPerimeter(canvas, size, spacing, 10, (
      canvas,
      pos,
      edgeAngle,
      idx,
      prog,
    ) {
      final sway = math.sin(prog * math.pi * 2 + idx * 0.7) * 0.25;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(edgeAngle - math.pi / 2 + sway);
      // Vine - wavy horizontal
      final vine = Path()
        ..moveTo(-spacing / 2, 0)
        ..quadraticBezierTo(-spacing / 4, -3, 0, 0)
        ..quadraticBezierTo(spacing / 4, 3, spacing / 2, 0);
      canvas.drawPath(vine, vinePaint);
      // Main thorn - big, curved, sharp
      final thorn = Path()
        ..moveTo(-2, 0)
        ..quadraticBezierTo(1, -len * 0.4, 5, -len)
        ..quadraticBezierTo(2, -len * 0.5, 0, -len * 0.3)
        ..quadraticBezierTo(-1, -len * 0.1, -2, 0)
        ..close();
      canvas.drawPath(thorn, thornPaint);
      // Second smaller thorn opposite
      final thorn2 = Path()
        ..moveTo(2, 0)
        ..quadraticBezierTo(0, len * 0.3, -4, len * 0.7)
        ..quadraticBezierTo(-1, len * 0.4, 0, len * 0.2)
        ..close();
      canvas.drawPath(thorn2, thornPaint);
      // Tiny leaf on vine
      final leaf = Path()
        ..moveTo(-6, 0)
        ..quadraticBezierTo(-10, -4, -13, 0)
        ..quadraticBezierTo(-10, 2, -6, 0)
        ..close();
      canvas.drawPath(leaf, leafPaint);
      canvas.restore();
    }, progress);
  }

  @override
  bool shouldRepaint(_ThornsPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.borderWidth != borderWidth ||
      old.waviness != waviness;
}

// ---------- FEATHERS - DETAILED ----------
class _FeathersPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double borderWidth;
  final double waviness;
  _FeathersPainter({
    required this.progress,
    required this.color,
    required this.borderWidth,
    required this.waviness,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final vaneFill = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final barbPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    final len = (18 + borderWidth * 1.5).clamp(22.0, 40.0);
    final wid = len * 0.35;
    final spacing = len + 8 + waviness;
    _walkPerimeter(canvas, size, spacing, 14, (
      canvas,
      pos,
      edgeAngle,
      idx,
      prog,
    ) {
      final drift = math.sin(prog * math.pi * 2 + idx) * 3;
      final tilt = math.sin(prog * math.pi * 2 + idx * 0.8) * 0.35;
      canvas.save();
      canvas.translate(pos.dx + drift * 0.3, pos.dy + drift);
      canvas.rotate(edgeAngle + tilt);
      // Vane - soft, rounded, with split at top
      final vane = Path()
        ..moveTo(0, -len / 2)
        ..quadraticBezierTo(wid, -len * 0.2, wid * 0.8, len * 0.2)
        ..quadraticBezierTo(wid * 0.5, len * 0.45, 0, len / 2)
        ..quadraticBezierTo(-wid * 0.5, len * 0.45, -wid * 0.8, len * 0.2)
        ..quadraticBezierTo(-wid, -len * 0.2, 0, -len / 2)
        ..close();
      canvas.drawPath(vane, vaneFill);
      canvas.drawPath(vane, outline);
      // Rachis - centre shaft, extends past vane
      canvas.drawLine(
        Offset(0, -len / 2 - 2),
        Offset(0, len / 2 + 5),
        outline..strokeWidth = 1.4,
      );
      // Barbs - diagonal lines off rachis
      for (int i = 0; i < 7; i++) {
        final y = -len * 0.35 + i * len * 0.11;
        final spread = wid * (0.9 - (i / 7) * 0.3);
        canvas.drawLine(Offset(0, y), Offset(spread, y + 3), barbPaint);
        canvas.drawLine(Offset(0, y), Offset(-spread, y + 3), barbPaint);
      }
      // Fluffy tip - little notch
      canvas.drawLine(Offset(0, -len / 2), Offset(2, -len / 2 - 3), outline);
      canvas.restore();
    }, progress);
  }

  @override
  bool shouldRepaint(_FeathersPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.borderWidth != borderWidth ||
      old.waviness != waviness;
}

// ---------- CLAWS ----------
class _ClawsPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double borderWidth;
  final double waviness;
  _ClawsPainter({
    required this.progress,
    required this.color,
    required this.borderWidth,
    required this.waviness,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final clawPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final len = (12 + borderWidth * 2).clamp(14.0, 32.0);
    final spacing = 22 + waviness;
    _walkPerimeter(canvas, size, spacing, 12, (
      canvas,
      pos,
      edgeAngle,
      idx,
      prog,
    ) {
      // 3 claw slashes per spot, staggered
      for (int c = 0; c < 3; c++) {
        final slashProg = ((prog + c * 0.15 + idx * 0.05) % 1.0);
        final alpha = slashProg < 0.5 ? slashProg * 2 : (1 - slashProg) * 2;
        final slashLen =
            len *
            (0.5 + c * 0.25) *
            (0.8 + 0.2 * math.sin(prog * math.pi * 2 + idx + c));
        canvas.save();
        canvas.translate(pos.dx + (c - 1) * 4, pos.dy);
        canvas.rotate(edgeAngle - math.pi / 2 + (c - 1) * 0.2);
        final path = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(3, -slashLen * 0.5, 0, -slashLen)
          ..quadraticBezierTo(-2, -slashLen * 0.5, 0, 0)
          ..close();
        canvas.drawPath(
          path,
          clawPaint
            ..color = color.withValues(alpha: (alpha * 0.9).clamp(0.0, 1.0)),
        );
        canvas.restore();
      }
    }, progress);
  }

  @override
  bool shouldRepaint(_ClawsPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.borderWidth != borderWidth ||
      old.waviness != waviness;
}
