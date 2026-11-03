import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../settings.dart';
import 'shared.dart';
import 'holo_card_v2.dart';
import 'card_frame.dart';

class ProfileStat {
  final String key;
  final String label;
  final String value;
  const ProfileStat({
    required this.key,
    required this.label,
    required this.value,
  });
}

class HomeProfileCard extends StatefulWidget {
  final String name;
  final String code;
  final String bio;
  final String subtitle;
  final List<ProfileStat> stats;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool fillHeight;

  const HomeProfileCard({
    super.key,
    required this.name,
    required this.code,
    required this.bio,
    required this.stats,
    required this.onTap,
    this.subtitle = '',
    this.onLongPress,
    this.fillHeight = false,
  });

  @override
  State<HomeProfileCard> createState() => _HomeProfileCardState();
}

class _HomeProfileCardState extends State<HomeProfileCard> {
  bool _codeRevealed = false;

  static int _stableSeed(String s) {
    int h = 17;
    for (int i = 0; i < s.length; i++) {
      h = h * 31 + s.codeUnitAt(i);
      h &= 0x7fffffff;
    }
    return h;
  }

  Future<void> _revealCode() async {
    if (_codeRevealed) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CodeDialog(
        title: 'UNIQUE CODE',
        body:
            'This is your permanent identity on Lore. It cannot be changed '
            'or recovered.\n\nNever share it with anyone. It is only needed '
            'if you transfer to a new device.',
        actionLabel: 'Reveal',
        actionColor: cGold,
      ),
    );
    if (confirm == true && mounted) {
      setState(() => _codeRevealed = true);
    }
  }

  Future<void> _copyCode() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CodeDialog(
        title: 'COPY UNIQUE CODE',
        body:
            'Only do this if you are transferring to a new device.\n\n'
            'Never give your unique code to anyone else — it is your '
            'permanent identity and cannot be changed.',
        actionLabel: 'Copy anyway',
        actionColor: cEmber,
      ),
    );
    if (confirm == true && mounted) {
      await Clipboard.setData(ClipboardData(text: widget.code));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: cInk,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(),
        content: Text('Unique code copied. Guard it carefully.',
            style: TextStyle(
                color: cParchment,
                fontSize: 13,
                fontStyle: FontStyle.italic)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final seed = _stableSeed(widget.code);

    return AnimatedBuilder(
      animation: appSettings,
      builder: (_, _) {
        final accent = appSettings.profileBorderColor;
        final spec = CardFrameSpec(
          seed: seed,
          accent: accent,
          glow: false,   // shader provides the glow already
          ornate: true,  // corner diamonds
          dense: false,  // not too many tick marks
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: HoloCardV2(
            accent: accent,
            intensity: 0.55,
            seed: seed,
            child: LoreTap(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              child: Container(
                decoration: _cardDecoration(),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: CardFrame(
                    spec: spec,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: _buildCardLayout(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────
  // CARD LAYOUT
  // ─────────────────────────────────────────

  Widget _buildCardLayout() {
    final accent = appSettings.profileBorderColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSetBar(accent),
        const SizedBox(height: 10),
        _buildRule(accent),
        const SizedBox(height: 2),
        _buildNameBanner(),
        const SizedBox(height: 2),
        _buildRule(accent),
        if (widget.subtitle.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildSubtitleLine(accent),
        ],
        const SizedBox(height: 12),
        if (widget.fillHeight)
          Expanded(child: _buildArtZone(accent))
        else
          SizedBox(height: 130, child: _buildArtZone(accent)),
        const SizedBox(height: 14),
        if (widget.stats.isNotEmpty) ...[
          _buildRule(accent),
          _buildStatsStrip(accent),
          _buildRule(accent),
          const SizedBox(height: 10),
        ],
        _buildFooter(accent),
      ],
    );
  }

  Widget _buildRule(Color accent) => Container(
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

  // ─────────────────────────────────────────
  // SET BAR (top strip)
  // ─────────────────────────────────────────

  Widget _buildSetBar(Color accent) {
    final clean = widget.code.replaceAll('-', '');
    final serial = clean.length >= 4
        ? clean.substring(clean.length - 4)
        : clean.padLeft(4, '0');

    return Row(
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
        Text(
          'LORE',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            letterSpacing: 4,
            color: accent,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '· RP',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            letterSpacing: 2,
            color: accent.withValues(alpha: 0.5),
          ),
        ),
        const Spacer(),
        Text(
          '#$serial',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: accent.withValues(alpha: 0.7),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // NAME BANNER
  // ─────────────────────────────────────────

  Widget _buildNameBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        widget.name,
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
  }

  Widget _buildSubtitleLine(Color accent) {
    return Text(
      widget.subtitle.toUpperCase(),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 9,
        letterSpacing: 2,
        color: accent.withValues(alpha: 0.75),
      ),
    );
  }

  // ─────────────────────────────────────────
  // ART ZONE (bio as flavor text)
  // ─────────────────────────────────────────

  Widget _buildArtZone(Color accent) {
    final hasBio = widget.bio.isNotEmpty;
    return Container(
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
          // Corner emblem
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
              child: Text(
                hasBio ? widget.bio : 'Tap to add a bio...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: hasBio ? cMist : cSmoke,
                  fontStyle: FontStyle.italic,
                  height: 1.9,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // STATS STRIP
  // ─────────────────────────────────────────

  Widget _buildStatsStrip(Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          for (var i = 0; i < widget.stats.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 34,
                color: accent.withValues(alpha: 0.25),
              ),
            Expanded(child: _statCell(widget.stats[i], accent)),
          ],
        ],
      ),
    );
  }

  Widget _statCell(ProfileStat s, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          s.value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w300,
            color: cParchment,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          s.label.toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 7.5,
            letterSpacing: 1.5,
            color: accent.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // FOOTER
  // ─────────────────────────────────────────

  Widget _buildFooter(Color accent) {
    return Row(
      children: [
        Expanded(
          child: _codeRevealed ? _revealedCodeRow() : _hiddenCodeRow(),
        ),
        const SizedBox(width: 8),
        Text(
          '✦ LORE ✦',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 8,
            color: accent.withValues(alpha: 0.35),
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }

  Widget _hiddenCodeRow() {
    return GestureDetector(
      onTap: _revealCode,
      behavior: HitTestBehavior.opaque,
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.lock_outline, size: 10, color: cSmoke),
        SizedBox(width: 5),
        Flexible(
          child: Text(
            'UNIQUE CODE — tap to reveal',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              color: cSmoke,
              letterSpacing: 1,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _revealedCodeRow() {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
        child: Text(
          widget.code,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: cGold,
            letterSpacing: 2,
          ),
        ),
      ),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: _copyCode,
        behavior: HitTestBehavior.opaque,
        child: const Padding(
          padding: EdgeInsets.all(3),
          child: Icon(Icons.copy, size: 11, color: cSmoke),
        ),
      ),
      const SizedBox(width: 2),
      GestureDetector(
        onTap: () => setState(() => _codeRevealed = false),
        behavior: HitTestBehavior.opaque,
        child: const Padding(
          padding: EdgeInsets.all(3),
          child: Icon(Icons.visibility_off, size: 11, color: cSmoke),
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────
  // DECORATION (unchanged — user customization)
  // ─────────────────────────────────────────

  BoxDecoration _cardDecoration() {
    final gradient = appSettings.profileGradient;
    final borderColor = appSettings.profileBorderColor;
    final style = appSettings.profileBorderStyle;

    Border border;
    List<BoxShadow>? shadows;

    switch (style) {
      case 'double':
        border = Border.all(color: borderColor, width: 3);
        break;
      case 'glow':
        border = Border.all(color: borderColor.withValues(alpha: 0.7), width: 1);
        shadows = [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 2,
          )
        ];
        break;
      case 'none':
        border = Border.all(color: Colors.transparent, width: 1);
        break;
      default:
        border = Border.all(color: borderColor, width: 1.5);
    }

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradient,
      ),
      border: border,
      boxShadow: shadows,
      borderRadius: BorderRadius.circular(4),
    );
  }
}

class _CodeDialog extends StatelessWidget {
  final String title;
  final String body;
  final String actionLabel;
  final Color actionColor;
  const _CodeDialog({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.actionColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: cInk,
      shape: const RoundedRectangleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      color: actionColor,
                      letterSpacing: 4)),
              const SizedBox(height: 12),
              Text(body,
                  style: const TextStyle(
                      fontSize: 13,
                      color: cMist,
                      height: 1.7,
                      fontStyle: FontStyle.italic)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                    child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration:
                        BoxDecoration(border: Border.all(color: cAsh)),
                    child: const Center(
                        child: Text('Cancel',
                            style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                color: cSmoke,
                                letterSpacing: 2))),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: actionColor.withValues(alpha: 0.8),
                    child: Center(
                        child: Text(actionLabel,
                            style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                color: cParchment,
                                letterSpacing: 2))),
                  ),
                )),
              ]),
            ]),
      ),
    );
  }
}