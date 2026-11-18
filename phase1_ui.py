import pathlib

# --- 1. Create lib/screens/customize_screen.dart ---
screen = r'''
import 'package:flutter/material.dart';
import '../theme.dart';
import '../settings.dart';
import '../widgets/shared.dart';
import '../widgets/colour_picker.dart';

class CustomizeScreen extends StatelessWidget {
  const CustomizeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appSettings,
      builder: (context, _) => Scaffold(
        backgroundColor: appSettings.bgColor,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: cAsh)),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.arrow_back_ios, color: cSmoke, size: 16),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'CUSTOMIZE',
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _section('LOGO'),
                      const SizedBox(height: 12),
                      _onOffRow(
                        label: 'Show LORE logo',
                        value: appSettings.showLogo,
                        onChanged: (v) => appSettings.setShowLogo(v),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Logo text',
                        style: TextStyle(fontSize: 13, color: cMist, fontWeight: FontWeight.w300),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: TextEditingController(text: appSettings.logoText),
                        onSubmitted: (v) {
                          final t = v.trim();
                          if (t.isNotEmpty) appSettings.setLogoText(t);
                        },
                        style: const TextStyle(color: cParchment, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: appSettings.logoText,
                          hintStyle: const TextStyle(color: cSmoke),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: cAsh),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: cGold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Rename LORE to anything. Empty keeps the last name. Turn Show off to hide it completely.',
                        style: TextStyle(fontSize: 11, color: cSmoke, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: cAsh),
                      const SizedBox(height: 16),
                      _section('FLOATING BUTTON'),
                      const SizedBox(height: 12),
                      _onOffRow(
                        label: 'Show floating button',
                        value: appSettings.showFloatingButton,
                        onChanged: (v) => appSettings.setShowFloatingButton(v),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text(
                            'Floating menu colour',
                            style: TextStyle(fontSize: 13, color: cMist, fontWeight: FontWeight.w300),
                          ),
                          const Spacer(),
                          LoreTap(
                            onTap: () => LoreColourPicker.show(
                              context,
                              current: appSettings.floatingMenuColor,
                              onPicked: (c) {
                                if (c != null) appSettings.setFloatingMenuColor(c);
                              },
                            ),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: appSettings.floatingMenuColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: cAsh),
                      const SizedBox(height: 16),
                      _section('MOTION'),
                      const SizedBox(height: 12),
                      _onOffRow(
                        label: 'Gyro / tilt effect',
                        value: appSettings.gyroEnabled,
                        onChanged: (v) => appSettings.setGyroEnabled(v),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Off = no tilt, no parallax. Good for motion sickness and battery.',
                        style: TextStyle(fontSize: 11, color: cSmoke, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: cAsh),
                      const SizedBox(height: 16),
                      _section('HOME BLOCKS'),
                      const SizedBox(height: 6),
                      const Text(
                        'Hide blocks you don\'t use. They come back when you turn them on again.',
                        style: TextStyle(fontSize: 11, color: cSmoke, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 12),
                      ..._blockIds().map((id) {
                        final hidden = appSettings.isBlockHidden(id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _onOffRow(
                            label: _blockLabel(id),
                            value: !hidden,
                            onLabel: 'SHOW',
                            offLabel: 'HIDE',
                            onChanged: (v) => appSettings.setBlockHidden(id, !v),
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static List<String> _blockIds() {
    final ids = <String>{};
    try {
      ids.addAll(appSettings.homeOrder);
    } catch (_) {}
    if (ids.isEmpty) {
      ids.addAll(['profile', 'continue', 'worlds', 'characters', 'posts']);
    }
    return ids.toList();
  }

  static String _blockLabel(String id) {
    if (id.isEmpty) return id;
    final s = id.replaceAll('_', ' ');
    return s[0].toUpperCase() + s.substring(1);
  }

  static Widget _section(String text) => Text(
        text,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 9,
          color: cGold,
          letterSpacing: 3,
        ),
      );

  static Widget _onOffRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    String onLabel = 'ON',
    String offLabel = 'OFF',
  }) {
    Widget chip({required String text, required bool active, required VoidCallback onTap}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: active ? cGold : cAsh),
            color: active ? cGold.withValues(alpha: 0.08) : Colors.transparent,
          ),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              letterSpacing: 1,
              color: active ? cGold : cSmoke,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: cMist, fontWeight: FontWeight.w300),
          ),
        ),
        chip(label: onLabel, active: value, onTap: () => onChanged(true)),
        const SizedBox(width: 6),
        chip(label: offLabel, active: !value, onTap: () => onChanged(false)),
      ],
    );
  }
}
'''
pathlib.Path("lib/screens/customize_screen.dart").write_text(screen, encoding="utf-8")
print("customize_screen.dart created")

# --- 2. Add Customize row in Settings, before REFERENCE section ---
p = pathlib.Path("lib/main.dart")
t = p.read_text(encoding="utf-8")

# Import
old_import = "import 'settings.dart';"
assert old_import in t
if "customize_screen.dart" not in t:
    t = t.replace(old_import, old_import + "\nimport 'screens/customize_screen.dart';", 1)

# Row - anchor on REFERENCE section header in _SettingsContent
anchor = """        // ── Reference ──
        const Text(
          'REFERENCE',"""
# Fallback: try without the comment line if encoding differs
if anchor not in t:
    # Find REFERENCE text in Settings
    idx = t.index("'REFERENCE'")
    # back up to start of that section - insert before the preceding SizedBox/Divider block is risky,
    # so insert directly before the Text widget's parent section by searching for the comment-less anchor
    raise SystemExit("REFERENCE anchor not found - paste the 20 lines around 'REFERENCE' in main.dart and I'll fix the anchor")

customize_block = """        // ── Customize ──
        const Text(
          'CUSTOMIZE',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cGold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        LoreTap(
          onTap: () =>
              Navigator.of(context).push(fadeRoute(const CustomizeScreen())),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              color: cInk,
              border: Border.all(color: cAsh),
            ),
            child: Row(
              children: const [
                Icon(Icons.palette_outlined, size: 16, color: cSmoke),
                SizedBox(width: 12),
                Text(
                  'Customize layout',
                  style: TextStyle(
                    fontSize: 14,
                    color: cMist,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Spacer(),
                Icon(Icons.chevron_right, size: 16, color: cSmoke),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Divider(color: cAsh),
        const SizedBox(height: 16),

"""
t = t.replace(anchor, customize_block + anchor, 1)
p.write_text(t, encoding="utf-8")
print("Settings row added")