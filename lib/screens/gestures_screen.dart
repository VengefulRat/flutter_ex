import 'package:flutter/material.dart';
import '../theme.dart';
import '../settings.dart';
import '../main.dart' show HomeScreen;

/// Scales a base font size by the user's Settings text-size preference.
/// Medium (14pt) is the reference, same as the rest of the app.
double _dSize(double base) => base * (appSettings.baseFontSize / 14.0);

class GesturesScreen extends StatelessWidget {
  final bool isFirstTime;
  const GesturesScreen({super.key, this.isFirstTime = false});

  void _goHome(BuildContext context) {
    if (isFirstTime) {
      Navigator.of(context).pushReplacement(
        fadeRoute(const HomeScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appSettings,
      builder: (context, _) => DefaultTabController(
        length: 5,
        child: Scaffold(
          backgroundColor: appSettings.bgColor,
          body: SafeArea(
            child: Column(
              children: [
                // Top Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: cAsh)),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _goHome(context),
                        child: const Icon(
                          Icons.arrow_back_ios,
                          color: cSmoke,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'HOW TO USE LORE',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: cGold,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab Bar
                Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: cAsh)),
                  ),
                  child: const TabBar(
                    isScrollable: true,
                    indicatorColor: cGold,
                    labelColor: cGold,
                    unselectedLabelColor: cSmoke,
                    labelStyle: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                    tabs: [
                      Tab(text: 'BASICS'),
                      Tab(text: 'HOME'),
                      Tab(text: 'PROFILE'),
                      Tab(text: 'WRITING'),
                      Tab(text: 'GESTURES'),
                    ],
                  ),
                ),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    children: [
                      // ── TAB 1: BASICS ──
                      _buildTabScroll([
                        const Text(
                          'Welcome to Lore. A private space for you and your partner to build worlds together.',
                          style: TextStyle(
                            fontSize: 13,
                            color: cMist,
                            fontStyle: FontStyle.italic,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSection('YOUR IDENTITY', [
                          _buildGesture(
                            icon: Icons.key,
                            title: 'Your Unique Code',
                            desc:
                                'You don\'t have an email or password. Your LR-XXXX code is your permanent identity. Keep it safe.\n\nIf you ever lose your phone, you\'ll need this code to log in on a new device.',
                          ),
                          _buildGesture(
                            icon: Icons.fingerprint,
                            title: 'Your PIN',
                            desc:
                                'Your 6-digit PIN is the key that encrypts your stories. We don\'t store it, and if you forget it, we cannot recover it.',
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _buildSection('PRIVACY', [
                          _buildGesture(
                            icon: Icons.security,
                            title: 'End-to-End Encryption',
                            desc:
                                'Everything you write, and every image you upload, is encrypted on your device before it ever touches our servers. Not even Lore can read your stories.',
                          ),
                        ]),
                      ]),

                      // ── TAB 2: HOME ──
                      _buildTabScroll([
                        _buildSection('THE HOME GRID', [
                          _buildGesture(
                            icon: Icons.notifications_none,
                            title: 'Notifications',
                            desc:
                                'Your inbox for new interests, accepted requests, new RP posts, and OOC messages. You can swipe left to delete them, or mark all read.',
                          ),
                          _buildGesture(
                            icon: Icons.auto_stories_outlined,
                            title: 'Roleplays',
                            desc:
                                'All your active stories. Tap to enter the room, or long-press to archive a story.',
                          ),
                          _buildGesture(
                            icon: Icons.lightbulb_outline,
                            title: 'Preludes',
                            desc:
                                'Your brainstorming rooms. Pin messages here to build the rules, world, and characters before you start the RP.',
                          ),
                          _buildGesture(
                            icon: Icons.credit_card_outlined,
                            title: 'Request Card',
                            desc:
                                'Your public profile. Edit your bio, tags, and writing style so others can find you.',
                          ),
                          _buildGesture(
                            icon: Icons.tune,
                            title: 'Settings',
                            desc:
                                'Change your theme, text size, notification alerts, and manage your security settings.',
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _buildSection('CUSTOMIZATION', [
                          _buildGesture(
                            icon: Icons.touch_app_outlined,
                            title: 'Long-Press to Style',
                            desc:
                                'Don\'t like how a block looks? Long-press any block on the Home screen to change its background color, border, and text color.',
                          ),
                        ]),
                      ]),

                      // ── TAB 3: PROFILE ──
                      _buildTabScroll([
                        _buildSection('YOUR PROFILE CARD', [
                          _buildGesture(
                            icon: Icons.edit_outlined,
                            title: 'Edit Bio & Style',
                            desc:
                                'Tap your large profile card at the top of the Home screen to edit your bio, pronouns, and writing style.',
                          ),
                          _buildGesture(
                            icon: Icons.colorize,
                            title: 'Card Appearance',
                            desc:
                                'Long-press your profile card to open the style sheet. You can change the gradient background, border style, and text colors.',
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _buildSection('STATS', [
                          _buildGesture(
                            icon: Icons.bar_chart,
                            title: 'Profile Stats',
                            desc:
                                'You can choose which stats appear on your card (Active RPs, Total Posts, Partners, etc.). Go to Profile > Stats on my card to toggle them.',
                          ),
                        ]),
                      ]),

                      // ── TAB 4: WRITING ──
                      _buildTabScroll([
                        _buildSection('THE RP ROOM', [
                          _buildGesture(
                            icon: Icons.edit_note,
                            title: 'Writing & Formatting',
                            desc:
                                'Tap the bottom bar to open the full editor. You can write long posts, use Bold/Italic, change font size, and pick a color for your text.',
                          ),
                          _buildGesture(
                            icon: Icons.menu_book_outlined,
                            title: 'Session Log',
                            desc:
                                'Tap the book icon in the top bar to open the Session Log. Here you can save rules, locations, and characters. Highlight any text in a post to add it directly to the log.',
                          ),
                          _buildGesture(
                            icon: Icons.construction_outlined,
                            title: 'Tools & Dice',
                            desc:
                                'Tap the wrench icon to open the Tools panel. You can roll dice, manage custom stat blocks (like Health or Mana), and import characters from your Sandbox.',
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _buildSection('OOC CHAT', [
                          _buildGesture(
                            icon: Icons.chat_bubble_outline,
                            title: 'Out of Character',
                            desc:
                                'Tap the chat bubble icon to open the OOC chat. You can send messages, or tap the + button to send an encrypted image or a web link.',
                          ),
                        ]),
                      ]),

                      // ── TAB 5: GESTURES ──
                      _buildTabScroll([
                        _buildSection('HIDDEN SHORTCUTS', [
                          _buildGesture(
                            icon: Icons.format_quote,
                            title: 'Quote & Edit',
                            desc:
                                'In the RP room, long-press any post to quote it, edit it, or delete it.',
                          ),
                          _buildGesture(
                            icon: Icons.push_pin_outlined,
                            title: 'Pin in Preludes',
                            desc:
                                'In a Prelude, long-press any chat message to pin it as a Rule, Character, or Plot point. These carry over to your Session Log.',
                          ),
                          _buildGesture(
                            icon: Icons.inventory_2_outlined,
                            title: 'Archive Stories',
                            desc:
                                'On the Home screen, long-press a Roleplay to archive it and hide it from your active list.',
                          ),
                        ]),
                      ]),
                    ],
                  ),
                ),

                // Let's Get Started Button (Only on first time)
                if (isFirstTime)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GestureDetector(
                      onTap: () => _goHome(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        color: cGold.withValues(alpha: 0.15),
                        child: const Center(
                          child: Text(
                            'Let\'s get started →',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: cGold,
                              letterSpacing: 2,
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
      ),
    );
  }

  // ── HELPERS ──

  Widget _buildTabScroll(List<Widget> children) {
    return ScrollConfiguration(
      behavior: NoGlowBehavior(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cGold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildGesture({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cInk,
        border: Border.all(color: cAsh),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cSmoke),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: cParchment,
                    fontWeight: FontWeight.w300,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: cMist,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
