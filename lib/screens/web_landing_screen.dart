import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/web_holo_card.dart';
import 'login_screen.dart';

/// WebLandingScreen — the desktop website.
///
/// For now this is JUST the hero — the first screen:
///   left: Lore + "Every story begins with you" + Download button
///   right: the WebHoloCard, tilting with your mouse.
///
/// We are NOT wiring this into main yet. This file just sits here
/// so you can preview it on its own. Once it looks right, main gets
/// one line to show it on desktop web.
class WebLandingScreen extends StatelessWidget {
  const WebLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cVoid,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Row(
              children: [
                // ── Left: words ──
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'L o r e',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          color: cGold,
                          letterSpacing: 8,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Every story\nbegins with\nyou.',
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w300,
                          color: cParchment,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Write it with someone. Worlds, characters, '
                        'dice, and cards — all in one place.',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w300,
                          color: cMist,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            color: cParchment,
                            child: const Text(
                              'DOWNLOAD ANDROID APP',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: cVoid,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: cGold),
                              ),
                              child: const Text(
                                'ENTER LORE',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: cGold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Move your mouse over the card →',
                        style: TextStyle(
                          fontSize: 12,
                          color: cSmoke,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
                // ── Right: the holo card ──
                WebHoloCard(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                border: Border.all(color: cGold),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text(
                                  'A',
                                  style: TextStyle(color: cGold, fontSize: 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Aria Thorn',
                                  style: TextStyle(
                                    color: cParchment,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  'Wanderer • Level 5',
                                  style: TextStyle(
                                    color: cSmoke,
                                    fontSize: 11,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Text(
                          '“The map was blank.\nSo she drew her own.”',
                          style: TextStyle(
                            color: cParchment,
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            height: 1.6,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            _stat('HP', '82', cEmber),
                            const SizedBox(width: 16),
                            _stat('MANA', '54', cIce),
                            const SizedBox(width: 16),
                            _stat('LUCK', '7', cGold),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _stat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cSmoke,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            color: color,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}
