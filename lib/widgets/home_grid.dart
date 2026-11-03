import 'package:flutter/material.dart';
import '../theme.dart';
import '../settings.dart';
import 'shared.dart';
import 'holo_card_v2.dart';
import 'package:reorderables/reorderables.dart';

/// A single tile in the home grid.
class HomeGridBlock {
  final IconData icon;
  final String title;
  final String subtitle;
  final int? badge;
  final Color accent;
  final bool fullWidth;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final BlockStyle style;

  const HomeGridBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onLongPress,
    this.style = const BlockStyle(),
    this.badge,
    this.accent = cSmoke,
    this.fullWidth = false,
  });
}

/// Two-column grid of tappable blocks. Tap pushes a full-screen route
/// supplied by the caller. Long-press opens the customization sheet.
class HomeGrid extends StatelessWidget {
  final List<HomeGridBlock> blocks;
  final bool isEditing;

  const HomeGrid({super.key, required this.blocks, this.isEditing = false});

  @override
  Widget build(BuildContext context) {
    final order = appSettings.homeOrder;
    if (order.isNotEmpty) {
      blocks.sort((a, b) {
        int indexA = order.indexOf(a.title);
        int indexB = order.indexOf(b.title);
        if (indexA == -1) indexA = 999;
        if (indexB == -1) indexB = 999;
        return indexA.compareTo(indexB);
      });
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final containerWidth = screenWidth > 900 ? 900.0 : screenWidth;
    final availableWidth = containerWidth - 32.0;
    final halfWidth = (availableWidth - 10) / 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ReorderableWrap(
        spacing: 10,
        runSpacing: 10,
        onReorder: (oldIndex, newIndex) {
          final currentTitles = blocks.map((b) => b.title).toList();
          final item = currentTitles.removeAt(oldIndex);
          currentTitles.insert(newIndex, item);
          appSettings.setHomeOrder(currentTitles);
        },
        children: blocks.map((b) {
          final width = b.fullWidth ? availableWidth : halfWidth;
          return SizedBox(
            width: width,
            child: _HomeGridTile(
              key: ValueKey(b.title),
              block: b,
              fullWidth: b.fullWidth,
              isEditing: isEditing,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HomeGridTile extends StatelessWidget {
  final HomeGridBlock block;
  final bool fullWidth;
  final bool isEditing;
  const _HomeGridTile({
    super.key,
    required this.block,
    required this.fullWidth,
    this.isEditing = false,
  });

  Color get _bg => block.style.background ?? cInk;
  Color get _borderColor => block.style.borderColor ?? cAsh;
  Color get _accent => block.style.accent ?? block.accent;

  BoxDecoration _tileDecoration() {
  BorderRadius radius;
  switch (block.style.shape) {
    case 'rounded':
      radius = BorderRadius.circular(16);
      break;
    case 'pill':
      radius = BorderRadius.circular(50);
      break;
    default:
      radius = BorderRadius.zero;
  }

  final bgLum = _bg.computeLuminance();
  final isBright = bgLum > 0.35;

  // Top edge catches light, bottom edge falls into shadow. This is the
  // "raised surface" gradient — it's what makes the tile read as sitting
  // on top of the background rather than painted onto it.
  final topHighlight = isBright ? 0.03 : 0.09;
  final bottomShadow = isBright ? 0.12 : 0.24;

  final gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color.lerp(_bg, Colors.white, topHighlight)!,
      _bg,
      Color.lerp(_bg, Colors.black, bottomShadow)!,
    ],
    stops: const [0.0, 0.35, 1.0],
  );

  // Lift shadows — dimmer on bright tiles so they don't add more mud
  final darkShadow = BoxShadow(
    color: Colors.black.withValues(alpha: isBright ? 0.45 : 0.8),
    blurRadius: isBright ? 12 : 18,
    offset: const Offset(0, 8),
    spreadRadius: -6,
  );
  final glowLift = BoxShadow(
    color: _accent.withValues(alpha: isBright ? 0.10 : 0.28),
    blurRadius: isBright ? 22 : 40,
    offset: const Offset(0, 18),
    spreadRadius: -2,
  );
  final baseShadows = <BoxShadow>[darkShadow, glowLift];

  final decoration = BoxDecoration(
    gradient: gradient,
    borderRadius: radius,
  );

  switch (block.style.borderStyle) {
    case 'thick':
      return decoration.copyWith(
        border: Border.all(
          color: isEditing ? cGold : _borderColor,
          width: isEditing ? 2 : 3,
        ),
        boxShadow: baseShadows,
      );
    case 'faded':
      return decoration.copyWith(
        border: Border.all(
          color: isEditing
              ? cGold
              : _borderColor.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: baseShadows,
      );
    case 'glow':
      return decoration.copyWith(
        border: Border.all(
          color: isEditing
              ? cGold
              : _borderColor.withValues(alpha: 0.7),
          width: 1,
        ),
        boxShadow: [
          ...baseShadows,
          BoxShadow(
            color: _borderColor.withValues(alpha: 0.35),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      );
    default:
      return decoration.copyWith(
        border: Border.all(
          color: isEditing ? cGold : _borderColor,
          width: isEditing ? 2 : 1.5,
        ),
        boxShadow: baseShadows,
      );
  }
}

  @override
  Widget build(BuildContext context) {
    Widget tile = Container(
      height: fullWidth ? 64 : 96,
      decoration: _tileDecoration(),
      padding: EdgeInsets.symmetric(
        horizontal: fullWidth ? 16 : 14,
        vertical: fullWidth ? 12 : 14,
      ),
      child: fullWidth ? _fullWidthLayout() : _stackedLayout(),
    );

    // Shader + tilt wrapper. Disabled during edit mode so reorder drags
    // don't fight the pointer listener inside HoloCardV2.
    tile = HoloCardV2(
      accent: _accent,
      intensity: 0.38,
      seed: block.title.hashCode,
      maxTiltDegrees: 8,
      parallaxStrength: 6,
      enabled: !isEditing,
      gyroEnabled: !isEditing,
      bgColor: _bg,
      child: tile,
    );

    // Hexagon clip wraps the shader too, so foil respects the shape.
    // PhysicalShape gives a hexagon-shaped shadow (not a rectangle).
    if (block.style.shape == 'hexagon') {
      tile = PhysicalShape(
        clipper: HexagonClipper(),
        color: _bg,
        elevation: 10,
        shadowColor: _accent.withValues(alpha: 0.5),
        child: tile,
      );
    }

    return LoreTap(
      onTap: isEditing ? block.onLongPress : block.onTap,
      onLongPress: isEditing ? null : block.onLongPress,
      child: Stack(
        children: [
          tile,
          if (isEditing)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: cGold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.drag_indicator, size: 14, color: cVoid),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stackedLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(block.icon, size: 18, color: _accent),
            const Spacer(),
            if (block.badge != null && block.badge! > 0 && !isEditing)
              _badge()
            else if (!isEditing)
              const Icon(Icons.chevron_right, size: 16, color: cSmoke),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              block.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: cMist,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              block.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                color: cSmoke,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _fullWidthLayout() {
    return Row(
      children: [
        Icon(block.icon, size: 18, color: _accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                block.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: cMist,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.3,
                ),
              ),
              if (block.subtitle.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  block.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: cSmoke,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (block.badge != null && block.badge! > 0 && !isEditing) _badge(),
        if (!isEditing) const SizedBox(width: 4),
        if (!isEditing)
          const Icon(Icons.chevron_right, size: 16, color: cSmoke),
      ],
    );
  }

  Widget _badge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _accent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${block.badge}',
        style: const TextStyle(
          fontSize: 10,
          color: cVoid,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final double w = size.width;
    final double h = size.height;
    final double radius = h * 0.25; // Adjust for pointiness

    path.moveTo(w / 2, 0);
    path.lineTo(w, radius);
    path.lineTo(w, h - radius);
    path.lineTo(w / 2, h);
    path.lineTo(0, h - radius);
    path.lineTo(0, radius);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
