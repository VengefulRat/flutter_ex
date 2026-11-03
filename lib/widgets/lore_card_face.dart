import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import 'card_frame.dart';

/// The shared "Lore card" chrome. Renders the set bar, name banner,
/// art zone, optional stats strip, and optional footer — all wrapped
/// in the procedural [CardFrame] ornaments.
///
/// Callers provide the *content* for the art zone (via [art]), the
/// stats strip (via [statsStrip]), and the footer (via [footer]). The
/// chrome itself (dividers, set bar layout, watermark) stays identical
/// across every Lore card, so the visual family is consistent.
class LoreCardFace extends StatelessWidget {
  final String title;
  final String code;
  final String? subtitle;
  final Widget art;
  final Widget? statsStrip;
  final Widget? footer;
  final int seed;
  final bool fillHeight;
  final Color accent;

  const LoreCardFace({
    super.key,
    required this.title,
    required this.code,
    required this.art,
    required this.seed,
    required this.accent,
    this.subtitle,
    this.statsStrip,
    this.footer,
    this.fillHeight = false,
  });

  String get _serial {
    final clean = code.replaceAll('-', '');
    if (clean.length < 4) return clean.padLeft(4, '0');
    return clean.substring(clean.length - 4);
  }

  TextStyle _mono(double size, Color color, double spacing,
          [FontWeight w = FontWeight.w400]) =>
      TextStyle(
        fontFamily: 'monospace',
        fontSize: size,
        letterSpacing: spacing,
        color: color,
        fontWeight: w,
      );

  @override
  Widget build(BuildContext context) {
    final spec = CardFrameSpec(
      seed: seed,
      accent: accent,
      glow: false,
      ornate: true,
      dense: false,
    );

    return CardFrame(
      spec: spec,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSetBar(),
            const SizedBox(height: 10),
            _rule(),
            const SizedBox(height: 2),
            _buildNameBanner(),
            const SizedBox(height: 2),
            _rule(),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildSubtitleLine(),
            ],
            const SizedBox(height: 12),
            if (fillHeight)
              Expanded(child: _buildArtZone())
            else
              SizedBox(height: 130, child: _buildArtZone()),
            if (statsStrip != null) ...[
              const SizedBox(height: 14),
              _rule(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: statsStrip,
              ),
              _rule(),
            ] else
              const SizedBox(height: 12),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: footer!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _rule() => Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              accent.withValues(alpha: 0.55),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      );

  Widget _buildSetBar() => Row(
        children: [
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('LORE', style: _mono(9, accent, 4, FontWeight.w600)),
          const SizedBox(width: 8),
          Text('· RP', style: _mono(9, accent.withValues(alpha: 0.5), 2)),
          const Spacer(),
          Text('#$_serial', style: _mono(9, accent.withValues(alpha: 0.7), 1)),
        ],
      );

  Widget _buildNameBanner() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w300,
            fontStyle: FontStyle.italic,
            color: cParchment,
            letterSpacing: 0.5,
            height: 1.1,
          ),
        ),
      );

  Widget _buildSubtitleLine() => Text(
        subtitle!.toUpperCase(),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _mono(9, accent.withValues(alpha: 0.75), 2),
      );

  Widget _buildArtZone() => Container(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
        decoration: BoxDecoration(
          border: Border.all(color: accent.withValues(alpha: 0.22), width: 1),
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.6,
            colors: [
              accent.withValues(alpha: 0.09),
              Colors.transparent,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -10,
              right: -6,
              child: Text(
                '✦',
                style: TextStyle(
                  fontSize: 14,
                  color: accent.withValues(alpha: 0.4),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: art,
              ),
            ),
          ],
        ),
      );
}