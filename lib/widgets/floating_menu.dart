import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import '../settings.dart';
import 'holo_card_v2.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FloatingMenuItem {
  final String blockKey;
  final String label;
  final IconData icon;
  final Color accent;
  final int? badge;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const FloatingMenuItem({
    required this.blockKey,
    required this.label,
    required this.icon,
    required this.accent,
    this.badge,
    required this.onTap,
    this.onLongPress,
  });
}

class FloatingMenuButton extends StatefulWidget {
  final List<FloatingMenuItem> items;
  final IconData menuIcon;
  final double buttonSize;

  const FloatingMenuButton({
    super.key,
    required this.items,
    this.menuIcon = Icons.apps,
    this.buttonSize = 58,
  });

  @override
  State<FloatingMenuButton> createState() => _FloatingMenuButtonState();
}

class _FloatingMenuButtonState extends State<FloatingMenuButton>
    with SingleTickerProviderStateMixin {
  Offset? _position;
  Offset _dragStartPos = Offset.zero;
  Offset _dragStartTouch = Offset.zero;
  bool _menuOpen = false;
  SharedPreferences? _prefs;

  late final AnimationController _menuCtrl;

  static const double _cardSize = 82;
  static const double _radius = 210; // was 170
  static const double _spread = 1.42; // was 1.15
  static const double _pad = 10;
  static const double _tuck = 0.55;

  @override
  void initState() {
    super.initState();
    _menuCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    // When the close animation finishes, rebuild once so the
    // (now invisible) items are actually removed from the tree.
    _menuCtrl.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) {
        setState(() {});
      }
    });
    _loadPosition();
  }

  @override
  void dispose() {
    _menuCtrl.dispose();
    super.dispose();
  }

  // ── Default position: higher up so the fan has room to swing ──
  Offset _defaultPosition(Size screen) => Offset(
    screen.width - widget.buttonSize - 24,
    screen.height - widget.buttonSize - 200, // was -130
  );

  Offset _currentPos(Size screen) {
    final pos = _position ?? _defaultPosition(screen);
    // Clamp to screen bounds in case window resized
    final safeX = pos.dx.clamp(
      -widget.buttonSize * 0.5,
      screen.width - widget.buttonSize * 0.5,
    );
    final safeY = pos.dy.clamp(0.0, screen.height - widget.buttonSize);
    return Offset(safeX, safeY);
  }

  Future<void> _loadPosition() async {
    _prefs = await SharedPreferences.getInstance();
    final dx = _prefs?.getDouble('float_menu_dx');
    final dy = _prefs?.getDouble('float_menu_dy');
    if (dx != null && dy != null && mounted) {
      setState(() => _position = Offset(dx, dy));
    }
  }

  // ── Safe radius for a given spread: shrink the arc if cards would
  // clip off-screen. Spread is a parameter now, because when the
  // radius shrinks we widen the spread to keep tile spacing.
  double _getRadius(
    Offset origin,
    Size screen,
    double baseAngle,
    double spread,
  ) {
    final n = widget.items.length;
    if (n < 2) return _radius;
    final half = _cardSize / 2;
    final maxX = screen.width - _pad - half;
    final maxY = screen.height - _pad - half;
    final minX = _pad + half;
    final minY = _pad + half;

    double safe = _radius;
    for (int i = 0; i < n; i++) {
      final t = (i / (n - 1)) - 0.5;
      final a = baseAngle + t * spread;
      final c = math.cos(a);
      final s = math.sin(a);
      if (c > 0.01) safe = math.min(safe, (maxX - origin.dx) / c);
      if (c < -0.01) safe = math.min(safe, (minX - origin.dx) / c);
      if (s > 0.01) safe = math.min(safe, (maxY - origin.dy) / s);
      if (s < -0.01) safe = math.min(safe, (minY - origin.dy) / s);
    }
    return safe.clamp(_radius * 0.55, _radius);
  }

  // ── Drag ──
  void _onPanStart(DragStartDetails d, Size screen) {
    _dragStartPos = _currentPos(screen);
    _dragStartTouch = d.globalPosition;
  }

  void _onPanUpdate(DragUpdateDetails d, Size screen) {
    final delta = d.globalPosition - _dragStartTouch;
    final newPos = _dragStartPos + delta;
    setState(() {
      _position = Offset(
        newPos.dx.clamp(
          -widget.buttonSize * 0.5,
          screen.width - widget.buttonSize * 0.5,
        ),
        newPos.dy.clamp(0, screen.height - widget.buttonSize),
      );
    });
  }

  void _onPanEnd(Size screen) {
    final pos = _currentPos(screen);
    final center = pos + Offset(widget.buttonSize / 2, widget.buttonSize / 2);
    final distances = {
      'left': center.dx,
      'right': screen.width - center.dx,
      'top': center.dy,
      'bottom': screen.height - center.dy,
    };
    final minDist = distances.values.reduce(math.min);
    final edge = distances.entries.firstWhere((e) => e.value == minDist).key;

    if (minDist < 70) {
      final sz = widget.buttonSize;
      switch (edge) {
        case 'left':
          _position = Offset(-sz * _tuck, pos.dy);
          break;
        case 'right':
          _position = Offset(screen.width - sz * (1 - _tuck), pos.dy);
          break;
        case 'top':
          _position = Offset(pos.dx, -sz * _tuck);
          break;
        case 'bottom':
          _position = Offset(pos.dx, screen.height - sz * (1 - _tuck));
          break;
      }
    }
    setState(() {});

    // SAVE TO MEMORY
    if (_position != null) {
      _prefs?.setDouble('float_menu_dx', _position!.dx);
      _prefs?.setDouble('float_menu_dy', _position!.dy);
    }
  }

  // ── Menu ──
  void _toggleMenu() {
    if (_menuOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    _menuCtrl.forward();
    setState(() => _menuOpen = true);
  }

  void _closeMenu() {
    _menuCtrl.reverse();
    setState(() => _menuOpen = false);
  }

  void _onItemTap(FloatingMenuItem item) {
    _closeMenu();
    Future.delayed(const Duration(milliseconds: 220), item.onTap);
  }

  void _onItemLongPress(FloatingMenuItem item) {
    if (item.onLongPress == null) return;
    _closeMenu();
    Future.delayed(const Duration(milliseconds: 220), item.onLongPress);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = Size(constraints.maxWidth, constraints.maxHeight);
        final pos = _currentPos(screen);
        final buttonCenter =
            pos + Offset(widget.buttonSize / 2, widget.buttonSize / 2);

        return Stack(
          children: [
            if (_menuOpen || _menuCtrl.status != AnimationStatus.dismissed)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _closeMenu,
                  child: Container(color: Colors.black.withValues(alpha: 0.6)),
                ),
              ),

            if (_menuOpen || _menuCtrl.status != AnimationStatus.dismissed)
              ..._buildRadialItems(buttonCenter, screen),

            Positioned(
              left: pos.dx,
              top: pos.dy,
              child: GestureDetector(
                onTap: _toggleMenu,
                onPanStart: (d) => _onPanStart(d, screen),
                onPanUpdate: (d) => _onPanUpdate(d, screen),
                onPanEnd: (_) => _onPanEnd(screen),
                child: Container(
                  width: widget.buttonSize,
                  height: widget.buttonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cInk,
                    border: Border.all(
                      color: cGold.withValues(alpha: 0.7),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cGold.withValues(alpha: 0.3),
                        blurRadius: 22,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedRotation(
                      turns: _menuOpen ? 0.125 : 0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        _menuOpen ? Icons.close : widget.menuIcon,
                        color: cGold,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildRadialItems(Offset origin, Size screen) {
    final n = widget.items.length;
    if (n == 0) return [];

    final screenCenter = Offset(screen.width / 2, screen.height / 2);
    final toCenter = screenCenter - origin;
    final baseAngle = math.atan2(toCenter.dy, toCenter.dx);
    final half = _cardSize / 2;

    // EDIT 11: Keep neighbour spacing constant. When the corner
    // forces a smaller radius, widen the spread so tiles don't
    // crush together. Chord between neighbours =
    // 2 * radius * sin(delta / 2), delta = spread / (n - 1).
    // We want that chord >= card + 10 gap.
    double spread = _spread;
    double radius = _radius;
    if (n > 1) {
      for (int attempt = 0; attempt < 12; attempt++) {
        radius = _getRadius(origin, screen, baseAngle, spread);
        final delta = spread / (n - 1);
        final chord = 2 * radius * math.sin(delta / 2);
        if (chord >= _cardSize + 10 || spread >= 2.9) break;
        spread += 0.18;
      }
    } else {
      radius = _getRadius(origin, screen, baseAngle, spread);
    }

    // Raw fan positions, no per-tile clamping.
    final raw = List.generate(n, (i) {
      final t = n == 1 ? 0.0 : (i / (n - 1)) - 0.5;
      final angle = baseAngle + t * spread;
      return Offset(
        origin.dx + radius * math.cos(angle),
        origin.dy + radius * math.sin(angle),
      );
    });

    // EDIT 11: Shift the WHOLE fan back on-screen as one piece.
    // Per-tile clamp() was collapsing two tiles onto the same
    // x/y in corners — that's the hovering-over-each-other bug.
    // A single shared shift keeps every tile's spacing intact.
    double shiftX = 0;
    double shiftY = 0;
    if (raw.isNotEmpty) {
      final minX = raw.map((p) => p.dx).reduce(math.min) - half;
      final maxX = raw.map((p) => p.dx).reduce(math.max) + half;
      final minY = raw.map((p) => p.dy).reduce(math.min) - half;
      final maxY = raw.map((p) => p.dy).reduce(math.max) + half;
      if (minX < _pad) shiftX = _pad - minX;
      if (maxX + shiftX > screen.width - _pad) {
        shiftX = screen.width - _pad - maxX;
      }
      if (minY < _pad) shiftY = _pad - minY;
      if (maxY + shiftY > screen.height - _pad) {
        shiftY = screen.height - _pad - maxY;
      }
    }

    return List.generate(n, (i) {
      final x = raw[i].dx + shiftX;
      final y = raw[i].dy + shiftY;

      final item = widget.items[i];
      final startFrac = i * 0.08;

      final anim = CurvedAnimation(
        parent: _menuCtrl,
        curve: Interval(
          startFrac.clamp(0.0, 1.0),
          (0.65 + startFrac).clamp(0.0, 1.0),
          curve: Curves.easeOutBack,
        ),
      );

      return AnimatedBuilder(
        animation: anim,
        builder: (_, child) {
          final v = anim.value;
          return Positioned(
            left: x - half,
            top: y - half,
            child: Transform.scale(
              scale: v.clamp(0.0, 1.5),
              child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
            ),
          );
        },
        child: _buildMenuCard(item),
      );
    });
  }

  Widget _buildMenuCard(FloatingMenuItem item) {
    final style = appSettings.styleForBlock(item.blockKey);
    final bg = style.background ?? cInk;
    final accent = style.accent ?? item.accent;
    // EDIT 10b: No static tile border anymore. borderStyle / shape were
    // never read here — Border.all(1.5) + radius 10 were hardcoded.
    // Tile now has only: background, accent, and its own glow
    // (on/off + colour, same model as the profile card).
    final glowColor = style.glowColor ?? accent;

    Widget tile = Container(
      width: _cardSize,
      height: _cardSize,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
          if (style.glowEnabled)
            BoxShadow(
              color: glowColor.withValues(alpha: 0.35),
              blurRadius: 22,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, size: 22, color: accent),
          const SizedBox(height: 7),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 8.5,
                letterSpacing: 0.5,
                color: cParchment,
                height: 1.2,
              ),
            ),
          ),
          if (item.badge != null && item.badge! > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                '${item.badge}',
                style: const TextStyle(
                  fontSize: 8,
                  color: cVoid,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    tile = HoloCardV2(
      accent: accent,
      intensity: 0.35,
      seed: item.label.hashCode,
      maxTiltDegrees: 6,
      parallaxStrength: 4,
      bgColor: bg,
      child: tile,
    );

    return GestureDetector(
      onTap: () => _onItemTap(item),
      onLongPress: item.onLongPress != null
          ? () => _onItemLongPress(item)
          : null,
      child: tile,
    );
  }
}
