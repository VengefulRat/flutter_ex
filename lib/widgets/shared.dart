import 'package:flutter/material.dart';
import '../theme.dart';
import '../settings.dart';
import '../services/firestore_service.dart';
import 'package:flutter/services.dart';

class LoreTopBar extends StatelessWidget {
  final VoidCallback onLogoTap;
  final Widget? trailing;
  const LoreTopBar({super.key, required this.onLogoTap, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: cAsh))),
    child: Row(children: [
      GestureDetector(
        onTap: onLogoTap,
        child: appSettings.showLogo
            ? Text(
                appSettings.logoText.split('').join(' '),
                style: const TextStyle(
                  fontSize: 13,
                  color: cGold,
                  letterSpacing: 6,
                  fontWeight: FontWeight.w300,
                ),
              )
            : const SizedBox.shrink(),
      ),
      const Spacer(),
      ?trailing,
    ]),
  );
}

class LoreButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const LoreButton({super.key, required this.label,
      required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      color: filled ? cParchment : Colors.transparent,
      decoration: filled ? null : BoxDecoration(border: Border.all(color: cAsh)),
      child: Center(child: Text(label, style: TextStyle(
          fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w400,
          color: filled ? cVoid : cSmoke, letterSpacing: 3))),
    ),
  );
}

class LoreField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType keyboardType;
  const LoreField({super.key, required this.controller, required this.hint,
      this.obscure = false, this.keyboardType = TextInputType.text});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller, obscureText: obscure, keyboardType: keyboardType,
    style: const TextStyle(fontSize: 15, color: cParchment,
        fontStyle: FontStyle.italic),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: cSmoke,
          fontStyle: FontStyle.italic),
      enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: cAsh)),
      focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: cSmoke)),
      filled: false,
    ),
    cursorColor: cGold,
  );
}

Widget goldLabel(String text) => Text(text.toUpperCase(),
    style: const TextStyle(fontFamily: 'monospace', fontSize: 10,
        letterSpacing: 4, color: cGold));

Widget swipeHint({String label = 'Swipe to continue'}) =>
    Row(children: [
      const Text('→ ', style: TextStyle(fontSize: 14, color: cAsh)),
      Text(label, style: const TextStyle(fontFamily: 'monospace',
          fontSize: 10, letterSpacing: 3, color: cAsh)),
    ]);

// ── Block Dialog ──
Future<void> showBlockDialog({
  required BuildContext context,
  required String partnerName,
  required String myCode,
  required String partnerCode,
  required FirestoreService fs,
}) async {
  bool archiveSessions = true;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Dialog(
        backgroundColor: cInk,
        shape: const RoundedRectangleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('BLOCK USER', style: TextStyle(
                  fontFamily: 'monospace', fontSize: 9,
                  color: cEmber, letterSpacing: 4)),
              const SizedBox(height: 12),
              Text('Block $partnerName?',
                  style: const TextStyle(fontSize: 18,
                      fontWeight: FontWeight.w300,
                      color: cParchment)),
              const SizedBox(height: 8),
              const Text(
                'They will not be able to send you interests, messages, or find your card.',
                style: TextStyle(fontSize: 12, color: cSmoke,
                    fontStyle: FontStyle.italic, height: 1.6)),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => setState(() => archiveSessions = !archiveSessions),
                child: Row(children: [
                  Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      border: Border.all(color: archiveSessions ? cEmber : cAsh),
                      color: archiveSessions ? cEmber.withValues(alpha: 0.2) : Colors.transparent,
                    ),
                    child: archiveSessions
                      ? const Icon(Icons.check, size: 12, color: cEmber)
                      : null,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Archive all sessions with this user',
                      style: TextStyle(fontSize: 12, color: cMist))),
                ]),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(border: Border.all(color: cAsh)),
                    child: const Center(child: Text('Cancel',
                        style: TextStyle(fontFamily: 'monospace',
                            fontSize: 9, color: cSmoke, letterSpacing: 2))),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(child: GestureDetector(
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await fs.blockUser(
                      myCode: myCode,
                      blockedCode: partnerCode,
                      archiveSessions: archiveSessions,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        backgroundColor: cInk,
                        behavior: SnackBarBehavior.floating,
                        shape: const RoundedRectangleBorder(),
                        content: Text('$partnerName has been blocked.',
                            style: const TextStyle(color: cParchment,
                                fontSize: 13, fontStyle: FontStyle.italic)),
                      ));
                      // Pop back to home
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: cEmber.withValues(alpha: 0.8),
                    child: const Center(child: Text('Block',
                        style: TextStyle(fontFamily: 'monospace',
                            fontSize: 9, color: cParchment, letterSpacing: 2))),
                  ),
                )),
              ]),
            ],
          ),
        ),
      ),
    ),
  );
}
class LoreTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final HitTestBehavior behavior;

  const LoreTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<LoreTap> createState() => _LoreTapState();
}

class _LoreTapState extends State<LoreTap> {
  bool _isTapped = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isClickable = widget.onTap != null || widget.onLongPress != null;

    return MouseRegion(
      opaque: true,
      cursor: isClickable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (isClickable && mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (isClickable && mounted) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        behavior: widget.behavior,
        onTapDown: isClickable ? (_) => setState(() => _isTapped = true) : null,
        onTapUp: isClickable ? (_) => setState(() => _isTapped = false) : null,
        onTapCancel: isClickable ? () => setState(() => _isTapped = false) : null,
        onTap: isClickable
            ? () {
                HapticFeedback.lightImpact();
                widget.onTap?.call();
              }
            : null,
        onLongPress: isClickable
            ? () {
                HapticFeedback.heavyImpact();
                widget.onLongPress?.call();
              }
            : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          // Tapped gets dimmest (0.6), Hovered gets slightly dimmed (0.85), Default is 1.0
          opacity: _isTapped ? 0.6 : (_isHovered ? 0.85 : 1.0),
          child: widget.child,
        ),
      ),
    );
  }
}