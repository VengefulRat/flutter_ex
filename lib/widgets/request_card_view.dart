import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';
import 'card_frame.dart';
import 'holo_card_v2.dart';
import 'lore_card_face.dart';

/// TCG-style Request Card — shown in Discover and in the editor preview.
/// Shares the [LoreCardFace] chrome with HomeProfileCard so every Lore
/// card has the same visual family, but with request-card content
/// (genre, tags, writing style) instead of profile stats.
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

  // Kept for API compatibility — the HoloCardV2 wrapper now owns foil.
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

  int get _seed => frame?.seed ?? (foilSeed == 0 ? code.hashCode : foilSeed);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 5 / 7,
      child: GestureDetector(
        // Absorb drags so scrolling parents don't fight the tilt gesture.
        onVerticalDragUpdate: (_) {},
        onHorizontalDragUpdate: (_) {},
        child: Container(
          decoration: _outerDecoration(),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: LoreCardFace(
              title: name,
              code: code,
              subtitle: _buildSubtitle(),
              seed: _seed,
              accent: accent,
              fillHeight: true,
              art: _buildArt(),
              statsStrip: _buildInfoStrip(),
              footer: _buildFooter(),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _outerDecoration() {
    return BoxDecoration(
      border: Border.all(color: accent.withValues(alpha: 0.3), width: 1.5),
      borderRadius: BorderRadius.circular(4),
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
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (genre.isNotEmpty) parts.add(genre);
    parts.add(ageRating);
    return parts.join(' · ');
  }

  Widget _buildArt() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            bio.isEmpty ? '—' : bio,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: bio.isEmpty ? cSmoke : cMist,
              fontStyle: FontStyle.italic,
              height: 1.7,
            ),
          ),
          if (!isOpen) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                  border:
                      Border.all(color: cSmoke.withValues(alpha: 0.5))),
              child: const Text('CLOSED',
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 8,
                      color: cSmoke,
                      letterSpacing: 2)),
            ),
          ],
        ],
      );

  Widget _buildInfoStrip() {
    final rows = <Widget>[];
    if (writingStyle.isNotEmpty) rows.add(_metaLine('STYLE', writingStyle));
    if (frequency.isNotEmpty) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 6));
      rows.add(_metaLine('CADENCE', frequency));
    }
    if (tags.isNotEmpty) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));
      rows.add(_buildTagRow());
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _metaLine(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Text(label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 8,
                  color: accent.withValues(alpha: 0.7),
                  letterSpacing: 2,
                )),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                  fontSize: 12,
                  color: cMist,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                )),
          ),
        ],
      );

  Widget _buildTagRow() => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: tags
            .map((t) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: cSmoke.withValues(alpha: 0.4))),
                  child: Text(t,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 8,
                        color: cSmoke,
                        letterSpacing: 1,
                      )),
                ))
            .toList(),
      );

  Widget _buildFooter() => Row(
        children: [
          Expanded(
            child: Text(
              code,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: accent.withValues(alpha: 0.6),
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('✦ LORE ✦',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 8,
                color: accent.withValues(alpha: 0.35),
                letterSpacing: 3,
              )),
        ],
      );
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
                    color: cAsh, borderRadius: BorderRadius.circular(2)),
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