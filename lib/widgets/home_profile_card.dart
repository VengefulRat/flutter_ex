import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../settings.dart';
import 'shared.dart';
import 'holo_card_v2.dart';
import 'lore_card_face.dart';

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
  final String? avatarUrl;

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
    this.avatarUrl,
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
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: HoloCardV2(
            accent: appSettings.profileBorderColor,
            intensity: 0.55,
            seed: seed,
            child: LoreTap(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              child: Container(
                decoration: _cardDecoration(),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: LoreCardFace(
                title: widget.name,
                code: widget.code,
                subtitle: widget.subtitle,
                seed: seed,
                accent: appSettings.profileBorderColor,
                fillHeight: widget.fillHeight,
                backgroundImageUrl: widget.avatarUrl, // <--- Add this
                art: _buildBioText(),
                    statsStrip:
                        widget.stats.isEmpty ? null : _buildStatsRow(),
                    footer: _buildFooterRow(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBioText() => Text(
        widget.bio.isEmpty ? 'Tap to add a bio...' : widget.bio,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          color: widget.bio.isEmpty 
              ? cSmoke 
              : (appSettings.textColourFor('profile_bio') ?? cMist), // <-- Wired up!
          fontStyle: FontStyle.italic,
          height: 1.9,
        ),
      );

  Widget _buildStatsRow() => Row(
        children: [
          for (var i = 0; i < widget.stats.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 34,
                color:
                    appSettings.profileBorderColor.withValues(alpha: 0.25),
              ),
            Expanded(child: _statCell(widget.stats[i])),
          ],
        ],
      );

  Widget _statCell(ProfileStat s) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            s.value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w300,
              color: appSettings.textColourFor('profile_name') ?? cParchment, // <-- Wired up!
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
              color: appSettings.textColourFor('profile_bio') ?? 
                     appSettings.profileBorderColor.withValues(alpha: 0.7), // <-- Wired up!
            ),
          ),
        ],
      );

  Widget _buildFooterRow() => Row(
        children: [
          Expanded(
            child:
                _codeRevealed ? _revealedCodeRow() : _hiddenCodeRow(),
          ),
          const SizedBox(width: 8),
          Text('✦ LORE ✦',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 8,
                color: appSettings.profileBorderColor
                    .withValues(alpha: 0.35),
                letterSpacing: 3,
              )),
        ],
      );

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
        border =
            Border.all(color: borderColor.withValues(alpha: 0.7), width: 1);
        shadows = [
          BoxShadow(
              color: borderColor.withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: 2)
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