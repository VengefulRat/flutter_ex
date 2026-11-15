
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

/// WebHoloCard — final. Desktop only, mouse-driven, NOT gyro.
///
/// All layers on:
///   tilt + foil + glare + shine sweep + sparkles (with gentle twinkle)
///   + content parallax lift + corners + vignette
///
/// Flicker fix, for reference:
///   - No Opacity widgets (alpha lives in the colours themselves)
///   - Twinkle animation rebuilds ONLY the sparkle dots, not the whole card
///   - RepaintBoundary caches the card as one bitmap
///   - Hit-box is flat + 48px bigger than the card, card tilts inside it
///   - Mouse position in ValueNotifiers, not setState
class WebHoloCard extends StatefulWidget {
  final Widget child;
  final double width;
  final double height;
  final Color accent;
  final double maxTiltDegrees;

  const WebHoloCard({
    super.key,
    required this.child,
    this.width = 340,
    this.height = 480,
    this.accent = cGold,
    this.maxTiltDegrees = 12,
  });

  @override
  State<WebHoloCard> createState() => _WebHoloCardState();
}

class _Sparkle {
  final double left;
  final double top;
  final double size;
  final double depth;
  final Color color;
  const _Sparkle(this.left, this.top, this.size, this.depth, this.color);
}

class _WebHoloCardState extends State<WebHoloCard>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<Offset> _mouse = ValueNotifier(const Offset(0.5, 0.5));
  final ValueNotifier<bool> _hovering = ValueNotifier(false);

  // Twinkle controller — ONLY the sparkles listen to this.
  // The card itself does NOT rebuild on every twinkle frame.
  late final AnimationController _twinkle;

  static const _sparkles = <_Sparkle>[
    _Sparkle(0.12, 0.18, 3, 28, cGold),
    _Sparkle(0.82, 0.12, 2, 36, cIce),
    _Sparkle(0.68, 0.32, 4, 24, cMagic),
    _Sparkle(0.22, 0.52, 2, 40, cIce),
    _Sparkle(0.88, 0.58, 3, 28, cGold),
    _Sparkle(0.42, 0.22, 2, 32, cMagic),
    _Sparkle(0.55, 0.72, 3, 44, cGold),
    _Sparkle(0.30, 0.82, 2, 28, cIce),
    _Sparkle(0.75, 0.85, 4, 36, cMagic),
    _Sparkle(0.08, 0.68, 2, 32, cGold),
  ];

  @override
  void initState() {
    super.initState();
    _twinkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _mouse.dispose();
    _hovering.dispose();
    _twinkle.dispose();
    super.dispose();
  }

  void _onHover(PointerEvent e) {
    const pad = 24.0;
    final x = ((e.localPosition.dx - pad) / widget.width).clamp(0.0, 1.0);
    final y = ((e.localPosition.dy - pad) / widget.height).clamp(0.0, 1.0);
    if ((_mouse.value.dx - x).abs() < 0.01 &&
        (_mouse.value.dy - y).abs() < 0.01) return;
    _mouse.value = Offset(x, y);
    if (!_hovering.value) _hovering.value = true;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: _onHover,
      onEnter: (_) => _hovering.value = true,
      onExit: (_) {
        _hovering.value = false;
        _mouse.value = const Offset(0.5, 0.5);
      },
      opaque: true,
      child: SizedBox(
        width: widget.width + 48,
        height: widget.height + 48,
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_mouse, _hovering]),
            builder: (context, _) {
              final mouse = _mouse.value;
              final hovering = _hovering.value;
              final dx = mouse.dx - 0.5;
              final dy = mouse.dy - 0.5;
              final tiltX = -dy * widget.maxTiltDegrees * math.pi / 180;
              final tiltY = dx * widget.maxTiltDegrees * math.pi / 180;
              final press = hovering ? 1.0 : 0.0;

              return RepaintBoundary(
                child: SizedBox(
                  width: widget.width,
                  height: widget.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateX(tiltX)
                          ..rotateY(tiltY),
                        child: Container(
                          width: widget.width,
                          height: widget.height,
                          decoration: BoxDecoration(
                            color: cInk,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: widget.accent.withValues(alpha: 0.4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 30,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Stack(
                              children: [
                                // ── Foil ──
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment(
                                          mouse.dx * 2 - 1,
                                          mouse.dy * 2 - 1,
                                        ),
                                        end: Alignment(
                                          1 - mouse.dx * 2,
                                          1 - mouse.dy * 2,
                                        ),
                                        colors: [
                                          const Color(0xFFC9A96E).withValues(
                                            alpha: 0.35 * press + 0.1,
                                          ),
                                          const Color(0xFF7AB8D4).withValues(
                                            alpha: 0.35 * press + 0.1,
                                          ),
                                          const Color(0xFFD4617A).withValues(
                                            alpha: 0.35 * press + 0.1,
                                          ),
                                          const Color(0xFF9B6FD4).withValues(
                                            alpha: 0.35 * press + 0.1,
                                          ),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // ── Glare ──
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        center: Alignment(
                                          mouse.dx * 2 - 1,
                                          mouse.dy * 2 - 1,
                                        ),
                                        radius: 0.9,
                                        colors: [
                                          Colors.white.withValues(
                                            alpha: 0.25 * press + 0.05,
                                          ),
                                          Colors.white
                                              .withValues(alpha: 0.06),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 0.18, 0.48],
                                      ),
                                    ),
                                  ),
                                ),
                                // ── Shine sweep ──
                                Positioned(
                                  top: 0,
                                  bottom: 0,
                                  left: mouse.dx * widget.width - 100,
                                  width: 180,
                                  child: Transform(
                                    transform: Matrix4.skewX(-0.32),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Colors.white.withValues(
                                              alpha: 0.22 * press,
                                            ),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // ── Content — parallax lift ──
                                Transform(
                                  transform: Matrix4.identity()
                                    ..translate(dx * 18, dy * 18),
                                  child: widget.child,
                                ),
                                // ── Sparkles — own tiny AnimatedBuilder each.
                                // This rebuilds ONLY the dot, not the card.
                                ..._sparkles.map((s) {
                                  return Positioned(
                                    left: s.left * widget.width + dx * s.depth,
                                    top: s.top * widget.height + dy * s.depth,
                                    child: AnimatedBuilder(
                                      animation: _twinkle,
                                      builder: (_, __) {
                                        final tw = 0.5 +
                                            0.5 *
                                                math.sin(
                                                  _twinkle.value *
                                                          math.pi *
                                                          2 +
                                                      s.left * 10,
                                                );
                                        return Container(
                                          width: s.size,
                                          height: s.size,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.9 * press * tw,
                                            ),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: s.color,
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(top: 8, left: 8, child: _bracket(true, true)),
                      Positioned(top: 8, right: 8, child: _bracket(false, true)),
                      Positioned(bottom: 8, left: 8, child: _bracket(true, false)),
                      Positioned(bottom: 8, right: 8, child: _bracket(false, false)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _bracket(bool isLeft, bool isTop) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? const BorderSide(color: cGold, width: 2)
              : BorderSide.none,
          bottom: !isTop
              ? const BorderSide(color: cGold, width: 2)
              : BorderSide.none,
          left: isLeft
              ? const BorderSide(color: cGold, width: 2)
              : BorderSide.none,
          right: !isLeft
              ? const BorderSide(color: cGold, width: 2)
              : BorderSide.none,
        ),
      ),
    );
  }
}
