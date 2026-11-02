import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../settings.dart';
import 'shared.dart';

/// A single stat to display on the profile card.
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

/// The big card at the top of the home screen.
///
/// Pure display + one interaction: tapping anywhere (except the code
/// reveal) opens the full profile editor. The card itself doesn't load
/// anything; main.dart computes the stats and passes them in.
class HomeProfileCard extends StatefulWidget {
  final String name;
  final String code;
  final String bio;
  final List<ProfileStat> stats;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const HomeProfileCard({
    super.key,
    required this.name,
    required this.code,
    required this.bio,
    required this.stats,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<HomeProfileCard> createState() => _HomeProfileCardState();
}

class _HomeProfileCardState extends State<HomeProfileCard> {
  bool _codeRevealed = false;

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
            style: TextStyle(color: cParchment, fontSize: 13,
                fontStyle: FontStyle.italic)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appSettings,
      builder: (_, _) {
        return LoreTap(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: _cardDecoration(),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildBio(),
                  if (widget.stats.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildStats(),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: cAsh),
            color: cVoid.withValues(alpha: 0.4),
          ),
          child: const Icon(Icons.person, color: cSmoke, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.name, style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic, color: cParchment)),
              const SizedBox(height: 4),
              _codeRevealed ? _revealedCodeRow() : _hiddenCodeRow(),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, size: 18, color: cSmoke),
      ],
    );
  }

  Widget _hiddenCodeRow() {
    return GestureDetector(
      onTap: _revealCode,
      behavior: HitTestBehavior.opaque,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline, size: 11, color: cSmoke),
          SizedBox(width: 5),
          Text('UNIQUE CODE — tap to reveal',
              style: TextStyle(fontFamily: 'monospace', fontSize: 10,
                  color: cSmoke, letterSpacing: 1)),
        ]),
      ),
    );
  }

  Widget _revealedCodeRow() {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(widget.code, style: const TextStyle(
          fontFamily: 'monospace', fontSize: 12,
          color: cGold, letterSpacing: 2)),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: _copyCode,
        behavior: HitTestBehavior.opaque,
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.copy, size: 13, color: cSmoke),
        ),
      ),
      const SizedBox(width: 4),
      GestureDetector(
        onTap: () => setState(() => _codeRevealed = false),
        behavior: HitTestBehavior.opaque,
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.visibility_off, size: 13, color: cSmoke),
        ),
      ),
    ]);
  }

  Widget _buildBio() {
    final text = widget.bio.isEmpty ? 'Tap to add a bio...' : widget.bio;
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        color: widget.bio.isEmpty ? cSmoke : cMist,
        fontStyle: FontStyle.italic,
        height: 1.6,
      ),
    );
  }

  Widget _buildStats() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: widget.stats.map((s) => _statChip(s)).toList(),
    );
  }

  Widget _statChip(ProfileStat s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cVoid.withValues(alpha: 0.5),
        border: Border.all(color: cAsh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.value, style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w300,
              color: cParchment, height: 1.1)),
          const SizedBox(height: 2),
          Text(s.label.toUpperCase(), style: const TextStyle(
              fontFamily: 'monospace', fontSize: 8,
              color: cSmoke, letterSpacing: 1.5)),
        ],
      ),
    );
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
        border = Border.all(color: borderColor.withValues(alpha: 0.7), width: 1);
        shadows = [BoxShadow(
            color: borderColor.withValues(alpha: 0.35),
            blurRadius: 16, spreadRadius: 2)];
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
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(
              fontFamily: 'monospace', fontSize: 9,
              color: actionColor, letterSpacing: 4)),
          const SizedBox(height: 12),
          Text(body, style: const TextStyle(
              fontSize: 13, color: cMist, height: 1.7,
              fontStyle: FontStyle.italic)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.of(context).pop(false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    border: Border.all(color: cAsh)),
                child: const Center(child: Text('Cancel',
                    style: TextStyle(fontFamily: 'monospace',
                        fontSize: 9, color: cSmoke, letterSpacing: 2))),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(
              onTap: () => Navigator.of(context).pop(true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: actionColor.withValues(alpha: 0.8),
                child: Center(child: Text(actionLabel,
                    style: const TextStyle(fontFamily: 'monospace',
                        fontSize: 9, color: cParchment, letterSpacing: 2))),
              ),
            )),
          ]),
        ]),
      ),
    );
  }
}