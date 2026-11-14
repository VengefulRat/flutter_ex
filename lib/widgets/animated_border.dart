import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../settings.dart';

enum AnimatedBorderPattern { waves, spikes, gears, dice }

class AnimatedBorder extends StatefulWidget {
  final Widget child;
  final Color color;
  final AnimatedBorderPattern? pattern;
  final double? borderWidth;
  final double? waviness;
  final double? opacity;
  final double? speed;

  const AnimatedBorder({
    super.key,
    required this.child,
    required this.color,
    this.pattern,
    this.borderWidth,
    this.waviness,
    this.opacity,
    this.speed,
  });

  @override
  State<AnimatedBorder> createState() => _AnimatedBorderState();
}

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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _diceController, appSettings]),
      builder: (_, _) {
        final thickness =
            widget.borderWidth ?? appSettings.animatedBorderThickness;
        final waviness = widget.waviness ?? appSettings.animatedBorderWaviness;
        final opacity = widget.opacity ?? appSettings.animatedBorderOpacity;
        final patternString = appSettings.animatedBorderPattern;
        final pattern =
            widget.pattern ??
            (patternString == 'spikes'
                ? AnimatedBorderPattern.spikes
                : patternString == 'gears'
                ? AnimatedBorderPattern.gears
                : patternString == 'dice'
                ? AnimatedBorderPattern.dice
                : AnimatedBorderPattern.waves);

        CustomPainter painter;
        if (pattern == AnimatedBorderPattern.spikes) {
          painter = _SpikesPainter(
            progress: _controller.value,
            color: widget.color.withValues(alpha: opacity),
            borderWidth: thickness,
            waviness: waviness,
          );
        } else if (pattern == AnimatedBorderPattern.gears) {
          painter = _GearsPainter(
            progress: _controller.value,
            color: widget.color.withValues(alpha: opacity),
            borderWidth: thickness,
            waviness: waviness,
          );
        } else if (pattern == AnimatedBorderPattern.dice) {
          painter = _DicePainter(
            progress: _isRolling ? _diceController.value : 0,
            isRolling: _isRolling,
            diceValues: _diceValues,
            color: widget.color.withValues(alpha: opacity),
            borderWidth: thickness,
            waviness: waviness,
          );
        } else {
          painter = _WavesPainter(
            progress: _controller.value,
            color: widget.color.withValues(alpha: opacity),
            borderWidth: thickness,
            waviness: waviness,
          );
        }

        final content = CustomPaint(
          foregroundPainter: painter,
          child: Padding(
            padding: EdgeInsets.all(thickness + 10),
            child: widget.child,
          ),
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

    final inset = 2.0;
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
      for (int i = 0; i <= count; i++) {
        final t = count == 0 ? 0.0 : i / count;
        final pos = Offset.lerp(start, end, t)!;
        drawGear(pos, gearIndex);
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
    // Bounce while rolling — waviness controls bounce height
    final bounce = isRolling
        ? math.sin(progress * math.pi * 3) * (2 + waviness * 0.5)
        : 0.0;
    final rotation = isRolling ? progress * math.pi * 4 : 0.0;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final pipPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Pip layouts for 1-6
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
        case 6:
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
      // Each die rotates slightly offset so they don't all spin in sync
      final rot = rotation + index * 0.4;
      final bounceOffset = bounce * (index.isEven ? 1 : -1);
      canvas.translate(center.dx, center.dy + bounceOffset);
      canvas.rotate(rot);
      // Die body — rounded square, translucent fill + outline
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: dieSize,
        height: dieSize,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        fillPaint..color = color.withValues(alpha: 0.18),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        strokePaint,
      );
      // Pips
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

    // Thin baseline frame so card still feels framed
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
