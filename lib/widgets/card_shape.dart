import 'dart:math' as math;
import 'package:flutter/material.dart';

enum CardShape { square, bevelled, octagon, jagged, crystal }

extension CardShapeClipper on CardShape {
  /// null = no clip, plain square. Everything else gets a clipper.
  CustomClipper<Path>? get clipper {
    switch (this) {
      case CardShape.square:
        return null;
      case CardShape.bevelled:
        return const BevelledClipper();
      case CardShape.octagon:
        return const OctagonClipper();
      case CardShape.jagged:
        return const JaggedClipper();
      case CardShape.crystal:
        return const CrystalClipper();
    }
  }
}

// ── Rare: corners cut off at 45° ──
class BevelledClipper extends CustomClipper<Path> {
  const BevelledClipper();

  @override
  Path getClip(Size size) {
    final cut = math.min(18.0, size.shortestSide * 0.25);
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(cut, 0);
    path.lineTo(w - cut, 0);
    path.lineTo(w, cut);
    path.lineTo(w, h - cut);
    path.lineTo(w - cut, h);
    path.lineTo(cut, h);
    path.lineTo(0, h - cut);
    path.lineTo(0, cut);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) =>
      oldClipper.runtimeType != runtimeType;
}

// ── Epic: 8 sides ──
class OctagonClipper extends CustomClipper<Path> {
  const OctagonClipper();

  @override
  Path getClip(Size size) {
    final cut = size.shortestSide * 0.18;
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(cut, 0);
    path.lineTo(w - cut, 0);
    path.lineTo(w, cut);
    path.lineTo(w, h - cut);
    path.lineTo(w - cut, h);
    path.lineTo(cut, h);
    path.lineTo(0, h - cut);
    path.lineTo(0, cut);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) =>
      oldClipper.runtimeType != runtimeType;
}

// ── Legendary: jagged / crown edge ──
class JaggedClipper extends CustomClipper<Path> {
  const JaggedClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    const tooth = 10.0;
    const depth = 6.0;
    final path = Path();

    // Top edge: left -> right, teeth pointing up/out
    path.moveTo(0, depth);
    for (double x = 0; x < w; x += tooth * 2) {
      path.lineTo(x + tooth, 0);
      path.lineTo(x + tooth * 2, depth);
    }
    // Right edge: top -> bottom
    for (double y = depth; y < h; y += tooth * 2) {
      path.lineTo(w, y + tooth);
      path.lineTo(w - depth, y + tooth * 2);
    }
    // Bottom edge: right -> left
    for (double x = w - depth; x > 0; x -= tooth * 2) {
      path.lineTo(x - tooth, h);
      path.lineTo(x - tooth * 2, h - depth);
    }
    // Left edge: bottom -> top
    for (double y = h - depth; y > 0; y -= tooth * 2) {
      path.lineTo(0, y - tooth);
      path.lineTo(depth, y - tooth * 2);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) =>
      oldClipper.runtimeType != runtimeType;
}

// ── Mythic: irregular crystal / torn edge ──
class CrystalClipper extends CustomClipper<Path> {
  const CrystalClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(w * 0.08, 0);
    path.lineTo(w * 0.45, h * 0.02);
    path.lineTo(w * 0.85, 0);
    path.lineTo(w, h * 0.15);
    path.lineTo(w * 0.95, h * 0.55);
    path.lineTo(w, h * 0.90);
    path.lineTo(w * 0.75, h);
    path.lineTo(w * 0.30, h * 0.98);
    path.lineTo(0, h * 0.85);
    path.lineTo(w * 0.03, h * 0.35);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) =>
      oldClipper.runtimeType != runtimeType;
}