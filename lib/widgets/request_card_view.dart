import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';
import 'card_frame.dart';
import 'foil_overlay.dart';
import 'holo_parallax.dart';
import 'holo_card_v2.dart';

/// TCG-style card view. Phase 1 — static layout, no pattern system yet.
/// The outer frame, name banner, bio zone, meta strip, and tag row are
/// all here. Background patterns and shimmer land in later phases.
class RequestCardView extends StatelessWidget {
  final String name;
  final String code;
  final String genre;
  final String bio;
  final String writingStyle;
  final String frequency;
  final String ageRating;
  final bool isOpen;
  final List<String> tags;
  final Color accent;
  final Color bgTint;

  // ── New: frame + foil ──
  final CardFrameSpec? frame;
  final bool foilEnabled;
  final int foilSeed;
  final double foilIntensity;

  const RequestCardView({
    super.key,
    required this.name,
    required this.code,
    required this.genre,
    required this.bio,
    required this.writingStyle,
    required this.frequency,
    required this.ageRating,
    required this.isOpen,
    required this.tags,
    required this.accent,
    this.bgTint = Colors.transparent,
    this.frame,
    this.foilEnabled = true,
    this.foilSeed = 0,
    this.foilIntensity = 0.6,
  });

  /// Last four chars of the code, used as a decorative serial number.
  String get _serial {
    final clean = code.replaceAll('-', '');
    if (clean.length < 4) return '—';
    return clean.substring(clean.length - 4);
  }

  @override
  Widget build(BuildContext context) {
    // Default spec: derived from the user's code so every card is
    // distinct out of the box, before the user customises anything.
    final spec =
        frame ??
        CardFrameSpec(
          seed: code.hashCode,
          accent: accent,
          glow: true,
          ornate: true,
        );

    return AspectRatio(
      aspectRatio: 5 / 7,
      child: GestureDetector(
        // These empty callbacks absorb the drag gesture so the parent
        // ListView/ScrollView doesn't scroll while you play with the shimmer.
        onVerticalDragUpdate: (_) {},
        onHorizontalDragUpdate: (_) {},
        child: CardFrame(
          spec: spec,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: accent.withValues(alpha: 0.3),
                  width: 1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(cVoid, accent, 0.08)!,
                    bgTint == Colors.transparent
                        ? cInk
                        : Color.lerp(cInk, bgTint, 0.15)!,
                    Color.lerp(cVoid, accent, 0.05)!,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              // Foil sits INSIDE the frame so it never obscures the border.
              child: FoilOverlay(
                accent: accent,
                enabled: false, // HoloCard3D owns foil now
                seed: foilSeed == 0 ? spec.seed : foilSeed,
                intensity: foilIntensity,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HoloParallaxLayer(depth: 1.0, child: _header()),
                      const SizedBox(height: 12),
                      HoloParallaxLayer(depth: 0.5, child: _nameBanner()),
                      const SizedBox(height: 14),
                      Expanded(
                        child: HoloParallaxLayer(depth: 0.4, child: _bioZone()),
                      ),
                      const SizedBox(height: 12),
                      HoloParallaxLayer(depth: 1.0, child: _statusStrip()),
                      if (writingStyle.isNotEmpty || frequency.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        HoloParallaxLayer(depth: 0.6, child: _bodyZone()),
                      ],
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        HoloParallaxLayer(depth: 1.0, child: _tagRow()),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (genre.isNotEmpty) ...[
          _chip(genre.toUpperCase(), accent),
          const SizedBox(width: 6),
        ],
        _chip(ageRating.toUpperCase(), cEmber),
        const Spacer(),
        Text(
          '#$_serial',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: accent.withValues(alpha: 0.6),
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 8,
          color: color,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _nameBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(
            color: accent.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Text(
        name,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w300,
          fontStyle: FontStyle.italic,
          color: cParchment,
          letterSpacing: 0.5,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _bioZone() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        color: cVoid.withValues(alpha: 0.35),
      ),
      child: Center(
        child: Text(
          bio.isEmpty ? '—' : bio,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: bio.isEmpty ? cSmoke : cMist,
            fontStyle: FontStyle.italic,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _statusStrip() {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOpen ? cVine : cSmoke,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          isOpen ? 'OPEN' : 'CLOSED',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: isOpen ? cVine : cSmoke,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(height: 1, color: accent.withValues(alpha: 0.2)),
        ),
      ],
    );
  }

  Widget _bodyZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (writingStyle.isNotEmpty) _metaLine('STYLE', writingStyle),
        if (writingStyle.isNotEmpty && frequency.isNotEmpty)
          const SizedBox(height: 6),
        if (frequency.isNotEmpty) _metaLine('CADENCE', frequency),
      ],
    );
  }

  Widget _metaLine(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 62,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 8,
              color: accent.withValues(alpha: 0.7),
              letterSpacing: 2,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: cMist,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tagRow() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags
          .map(
            (t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: cSmoke.withValues(alpha: 0.4)),
              ),
              child: Text(
                t,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 8,
                  color: cSmoke,
                  letterSpacing: 1,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

/// The modal sheet wrapper. Presents the card on a dimmed background
/// with a Send Interest action below.
class RequestCardSheet extends StatelessWidget {
  final RequestCardView card;
  final bool canSendInterest;
  final VoidCallback onSendInterest;

  const RequestCardSheet({
    super.key,
    required this.card,
    required this.canSendInterest,
    required this.onSendInterest,
  });

  static Future<void> show(
    BuildContext context, {
    required RequestCardView card,
    required bool canSendInterest,
    required VoidCallback onSendInterest,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => RequestCardSheet(
        card: card,
        canSendInterest: canSendInterest,
        onSendInterest: onSendInterest,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    // Compute card size so the whole sheet fits in ~85% of screen.
    // Reserve room for: drag handle, gaps, button, bottom padding.
    final reservedHeight = 160.0;
    final availableHeight = mq.size.height * 0.85 - reservedHeight;
    final widthFromHeight = availableHeight * 5 / 7;
    final widthFromScreen = mq.size.width - 48;
    final cardWidth = min(min(widthFromHeight, widthFromScreen), 380.0);

    return Container(
      decoration: const BoxDecoration(
        color: cVoid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: cAsh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: cardWidth,
                child: HoloCardV2(
                  accent: card.accent,
                  intensity: card.foilIntensity,
                  enabled: card.foilEnabled,
                  seed: card.foilSeed,
                  child: card,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: cardWidth,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    onSendInterest();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    color: canSendInterest ? cParchment : cAsh,
                    child: Center(
                      child: Text(
                        canSendInterest
                            ? 'S E N D   I N T E R E S T'
                            : 'N O T   A C C E P T I N G',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: canSendInterest ? cVoid : cSmoke,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
