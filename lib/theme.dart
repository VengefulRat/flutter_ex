import 'package:flutter/material.dart';

const cVoid = Color(0xFF080808);
const cInk = Color(0xFF0E0E0E);
const cAsh = Color(0xFF2a2a2a);
const cSmoke = Color(0xFF7a7a7a);
const cMist = Color(0xFF9a9a9a);
const cParchment = Color(0xFFE8E2D4);
const cGold = Color(0xFFC9A96E);
const cEmber = Color(0xFFD4614A);
const cIce = Color(0xFF7AB8D4);
const cVine = Color(0xFF4a7a3a);
const cMagic = Color(0xFF9b6fd4);

PageRouteBuilder fadeRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_, _, _) => page,
  transitionDuration: const Duration(milliseconds: 700),
  transitionsBuilder: (_, anim, _, child) =>
      FadeTransition(opacity: anim, child: child),
);

class NoGlowBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
