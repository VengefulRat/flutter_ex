import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/auth_service.dart';

/// Change this to your actual support inbox before shipping.
const String kSupportEmail = 'lore.the.rp.app@gmail.com';
const String kCommunityUrl = 'https://www.reddit.com/r/LoreTheRpApp/';

/// A small tappable link that opens a support dialog. The user reviews
/// the message, optionally describes what happened, and copies it into
/// their email app.
///
/// The dialog never asks for the PIN — emails are not a secure channel,
/// and a working PIN is already the recovery mechanism.
class SupportLink extends StatelessWidget {
  final String? knownCode;
  final String? contextNote;
  final String label;

  const SupportLink({
    super.key,
    this.knownCode,
    this.contextNote,
    this.label = 'Need help? Contact support',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cSmoke,
            letterSpacing: 1,
            decoration: TextDecoration.underline,
            decorationColor: cAsh,
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    final auth = AuthService();
    final code = (knownCode ?? auth.currentCode ?? '').trim();
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cInk,
        shape: const RoundedRectangleBorder(),
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ACCOUNT SUPPORT',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: cGold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'If you can\'t sign in — for example if your device was '
                  'stolen or your PIN stopped working — send the message '
                  'below to the address shown.',
                  style: TextStyle(
                    fontSize: 13,
                    color: cMist,
                    fontStyle: FontStyle.italic,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'YOUR UNIQUE CODE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: cSmoke,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cVoid,
                    border: Border.all(color: cAsh),
                  ),
                  child: Text(
                    code.isEmpty ? '(I don\'t have my code)' : code,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      color: code.isEmpty ? cSmoke : cGold,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'WHAT HAPPENED?',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: cSmoke,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  maxLines: 5,
                  style: const TextStyle(
                    fontSize: 13,
                    color: cParchment,
                    fontStyle: FontStyle.italic,
                    height: 1.6,
                  ),
                  decoration: const InputDecoration(
                    hintText:
                        'My phone was stolen on... / my PIN stopped working...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: cSmoke,
                      fontStyle: FontStyle.italic,
                    ),
                    filled: true,
                    fillColor: cVoid,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: cAsh),
                      borderRadius: BorderRadius.zero,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: cGold),
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  cursorColor: cGold,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: cEmber.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_outlined,
                        color: cEmber,
                        size: 16,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Send this to $kSupportEmail. '
                          'Never send your PIN by email — we will never ask for it.',
                          style: TextStyle(
                            fontSize: 11,
                            color: cEmber,
                            fontStyle: FontStyle.italic,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'COMMUNITY',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: cSmoke,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: kCommunityUrl),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: cInk,
                          content: Text(
                            'Reddit link copied',
                            style: TextStyle(color: cParchment),
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cVoid,
                      border: Border.all(color: cAsh),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Text(
                            kCommunityUrl,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: cGold,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.copy, size: 14, color: cSmoke),
                      ],
                    ),
                  ),
                ),
                const Text(
                  'Tap to copy — bug reports, ideas, and finding RP partners.',
                  style: TextStyle(
                    fontSize: 11,
                    color: cSmoke,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: cAsh),
                          ),
                          child: const Center(
                            child: Text(
                              'Close',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                color: cSmoke,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final note = ctrl.text.trim();
                          final buf = StringBuffer()
                            ..writeln('Hi Lore support,')
                            ..writeln()
                            ..writeln('I need help with my account.')
                            ..writeln()
                            ..writeln(
                              'Unique code: ${code.isEmpty ? "(not known)" : code}',
                            )
                            ..writeln(
                              'What happened: ${note.isEmpty ? "(not described)" : note}',
                            )
                            ..writeln();
                          if (contextNote != null) {
                            buf.writeln('($contextNote)');
                            buf.writeln();
                          }
                          buf.writeln('— sent from the Lore app');
                          await Clipboard.setData(
                            ClipboardData(text: buf.toString()),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: cInk,
                                content: Text(
                                  'Paste this into an email to $kSupportEmail',
                                  style: const TextStyle(color: cParchment),
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          color: cParchment,
                          child: const Center(
                            child: Text(
                              'Copy message',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                color: cVoid,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
