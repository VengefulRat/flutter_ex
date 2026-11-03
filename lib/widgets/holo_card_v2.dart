import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'holo_parallax.dart';
import '../services/gyro_service.dart';

class HoloCardV2 extends StatefulWidget {
  final Widget child;
  final Color accent;
  final bool enabled;
  final double intensity;
  final int seed;
  final double maxTiltDegrees;
  final double parallaxStrength;
  final bool gyroEnabled;
  final double gyroSensitivity;
  final Color bgColor;

  const HoloCardV2({
    super.key,
    required this.child,
    this.accent = const Color(0xFFC9A96E),
    this.enabled = true,
    this.intensity = 0.7,
    this.seed = 0,
    this.maxTiltDegrees = 12,
    this.parallaxStrength = 10.0,
    this.gyroEnabled = true,
    this.gyroSensitivity = 1.0,
    this.bgColor = const Color(0xFF0E0E0E),
  });

  @override
  State<HoloCardV2> createState() => _HoloCardV2State();
}

class _RotState {
  final double rotateX;
  final double rotateY;
  const _RotState({required this.rotateX, required this.rotateY});
  const _RotState.rest() : rotateX = 0, rotateY = 0;
  bool get isRest => rotateX == 0 && rotateY == 0;
}

class _HoloCardV2State extends State<HoloCardV2>
    with TickerProviderStateMixin {
  ui.FragmentShader? _shader;
  final ValueNotifier<_RotState> _rot =
      ValueNotifier(const _RotState.rest());
  final ValueNotifier<Offset> _light =
      ValueNotifier(const Offset(0.5, 0.35));
  late final AnimationController _activeCtrl;
  late final AnimationController _timeCtrl;

  // Touch-driven tilt + state
  double _fingerOffsetX = 0;
  double _fingerOffsetY = 0;
  bool _fingerActive = false;
  bool _isReleasing = false;

  // Gyro-driven tilt
  double _gyroX = 0;
  double _gyroY = 0;

  @override
  void initState() {
    super.initState();
    _activeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _timeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _loadShader();
    if (widget.gyroEnabled) {
      GyroService.instance.acquire();
      GyroService.instance.tilt.addListener(_onGyroUpdate);
    }
  }

  Future<void> _loadShader() async {
    try {
      final program =
          await ui.FragmentProgram.fromAsset('shaders/foil_overlay.frag');
      if (!mounted) return;
      setState(() => _shader = program.fragmentShader());
    } catch (e) {
      debugPrint('[HoloCardV2] shader load failed: $e');
    }
  }

  void _onGyroUpdate() {
    final t = GyroService.instance.tilt.value;
    final maxRad = widget.maxTiltDegrees * 3.14159265 / 180.0;
    _gyroX = -t.dy * maxRad * widget.gyroSensitivity;
    _gyroY = t.dx * maxRad * widget.gyroSensitivity;
    if (!_fingerActive) {
      _light.value = Offset(
        (0.5 - t.dx * 0.5).clamp(0.05, 0.95),
        (0.35 - t.dy * 0.5).clamp(0.05, 0.95),
      );
    }
    _updateRotation();
  }

  void _handlePointer(PointerEvent e) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = e.localPosition;
    final nx = (local.dx / box.size.width).clamp(0.0, 1.0);
    final ny = (local.dy / box.size.height).clamp(0.0, 1.0);
    _light.value = Offset(nx, ny);

    final maxRad = widget.maxTiltDegrees * 3.14159265 / 180.0;
    _fingerOffsetX = -(ny - 0.5) * 2 * maxRad;
    _fingerOffsetY = (nx - 0.5) * 2 * maxRad;
    _fingerActive = true;
    _isReleasing = false;
    _updateRotation();

    _activeCtrl.value = 1.0;
    if (!_timeCtrl.isAnimating) _timeCtrl.repeat();
  }

  void _release() {
    _fingerActive = false;
    _isReleasing = true;
    _updateRotation();

    _activeCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _isReleasing = false);
      if (mounted && _activeCtrl.value == 0 && _timeCtrl.isAnimating) {
        _timeCtrl.stop();
      }
    });
  }

  void _updateRotation() {
    _rot.value = _RotState(
      rotateX: _gyroX + (_fingerActive ? _fingerOffsetX : 0),
      rotateY: _gyroY + (_fingerActive ? _fingerOffsetY : 0),
    );
  }

  @override
  void dispose() {
    if (widget.gyroEnabled) {
      GyroService.instance.tilt.removeListener(_onGyroUpdate);
      GyroService.instance.release();
    }
    _activeCtrl.dispose();
    _timeCtrl.dispose();
    _rot.dispose();
    _light.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _shader == null) return widget.child;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointer,
      onPointerMove: _handlePointer,
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: ValueListenableBuilder<_RotState>(
        valueListenable: _rot,
        builder: (_, r, _) {
          return AnimatedContainer(
            duration: _isReleasing
                ? const Duration(milliseconds: 550)
                : Duration.zero,
            curve: Curves.easeOutBack,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateX(r.rotateX)
              ..rotateY(r.rotateY),
            transformAlignment: Alignment.center,
            child: Stack(
              children: [
                HoloCardScope(
                  touch: _light,
                  maxParallaxOffset: widget.parallaxStrength,
                  child: widget.child,
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: Listenable.merge(
                        [_activeCtrl, _timeCtrl, _light],
                      ),
                      builder: (_, _) {
                        final bgLum = widget.bgColor.computeLuminance();
                        final isBright = bgLum > 0.35;
                        final effectiveIntensity =
                            widget.intensity * (1.0 - bgLum * 0.85);
                        return CustomPaint(
                          painter: _FoilPainter(
                            shader: _shader!,
                            light: _light.value,
                            active: _activeCtrl.value,
                            time: DateTime.now().millisecondsSinceEpoch /
                                1000.0,
                            intensity: effectiveIntensity,
                            accent: widget.accent,
                            seed: widget.seed.toDouble(),
                            blendMode: isBright
                                ? BlendMode.softLight
                                : BlendMode.plus,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FoilPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final Offset light;
  final double active;
  final double time;
  final double intensity;
  final Color accent;
  final double seed;
  final BlendMode blendMode;

  _FoilPainter({
    required this.shader,
    required this.light,
    required this.active,
    required this.time,
    required this.intensity,
    required this.accent,
    required this.seed,
    this.blendMode = BlendMode.plus,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, light.dx);
    shader.setFloat(3, light.dy);
    shader.setFloat(4, active);
    shader.setFloat(5, intensity);
    shader.setFloat(6, time);
    shader.setFloat(7, accent.r);
    shader.setFloat(8, accent.g);
    shader.setFloat(9, accent.b);
    shader.setFloat(10, seed);

    final paint = Paint()
      ..shader = shader
      ..blendMode = blendMode;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _FoilPainter old) =>
      old.light != light ||
      old.active != active ||
      old.time != time ||
      old.intensity != intensity ||
      old.accent != accent ||
      old.seed != seed ||
      old.blendMode != blendMode;
}