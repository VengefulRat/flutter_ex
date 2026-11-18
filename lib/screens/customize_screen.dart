
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
                              onPicked: (c) => appSettings.setFloatingMenuColor(c),
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
                      ..._blockIds().map((e) {
                        final hidden = appSettings.isBlockHidden(e.key);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _onOffRow(
                            label: e.value,
                            value: !hidden,
                            onLabel: 'SHOW',
                            offLabel: 'HIDE',
                            onChanged: (v) => appSettings.setBlockHidden(e.key, !v),
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

  static List<MapEntry<String, String>> _blockIds() {
    return [
      MapEntry(AppSettings.blockNotifications, 'Notifications'),
      MapEntry(AppSettings.blockRoleplays, 'Roleplays'),
      MapEntry(AppSettings.blockBrainstorms, 'Preludes'),
      MapEntry(AppSettings.blockRequestCard, 'Request Card'),
      MapEntry(AppSettings.blockSettings, 'Settings'),
    ];
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
        chip(text: onLabel, active: value, onTap: () => onChanged(true)),
        const SizedBox(width: 6),
        chip(text: offLabel, active: !value, onTap: () => onChanged(false)),
      ],
    );
  }
}
