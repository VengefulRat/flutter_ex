import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../settings.dart';
import '../widgets/shared.dart';
import '../widgets/colour_picker.dart';
import 'customize_screen.dart';
import 'gestures_screen.dart';
import 'lock_screen.dart';
import 'qr_scanner_screen.dart';
import 'rp_room.dart';
import 'brainstorm_room.dart';
import '../services/auth_service.dart';
import '../services/dev_tools.dart';
import '../services/sound_service.dart';

// ════════════════════════════════════════
// SETTINGS CONTENT
// ════════════════════════════════════════
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = AuthService();
  Future<void> _confirmSignOutOthers() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cInk,
        shape: const RoundedRectangleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SIGN OUT OTHER DEVICES',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: cGold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This ends every other session on your account. The device '
                'you\'re on now stays signed in.\n\n'
                'Use this if you signed in on a phone you no longer have, '
                'or if your phone was stolen.',
                style: TextStyle(
                  fontSize: 13,
                  color: cMist,
                  fontStyle: FontStyle.italic,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: LoreTap(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: cAsh),
                        ),
                        child: const Center(
                          child: Text(
                            'Cancel',
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
                    child: LoreTap(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: cGold.withValues(alpha: 0.85),
                        child: const Center(
                          child: Text(
                            'Sign out others',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              color: cVoid,
                              letterSpacing: 1,
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
    );
    if (confirm != true) return;
    await _auth.signOutOtherDevices();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: cInk,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(),
        content: Text(
          'All other sessions ended.',
          style: TextStyle(color: cParchment),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appSettings.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _launchDonationPage() async {
    final Uri url = Uri.parse('https://ko-fi.com/loretherpapp');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: cInk,
          content: Text(
            'Could not open the donation page.',
            style: TextStyle(color: cParchment),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Home screen glow ──
        // Long-press the header to toggle developer tools. Nothing else
        // in the UI reveals the gesture — the dev section appears above
        // the fold once you know it's there.
        GestureDetector(
          onLongPress: () async {
            await appSettings.setDevModeUnlocked(!appSettings.devModeUnlocked);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: cInk,
                behavior: SnackBarBehavior.floating,
                shape: const RoundedRectangleBorder(),
                content: Text(
                  appSettings.devModeUnlocked
                      ? 'Developer tools unlocked'
                      : 'Developer tools hidden',
                  style: const TextStyle(color: cParchment),
                ),
              ),
            );
          },
          child: const Text(
            'HOME GLOW',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              color: cGold,
              letterSpacing: 3,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'The soft light in the corner of your home screen.',
          style: TextStyle(
            fontSize: 12,
            color: cSmoke,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            LoreTap(
              onTap: () => LoreColourPicker.show(
                context,
                current: appSettings.bgGlowColor,
                onPicked: (c) async => appSettings.setBgGlowColor(c),
              ),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: appSettings.bgGlowColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(1.0, -1.0),
                    radius: 1.4,
                    colors: [
                      Color.lerp(
                        appSettings.bgColor,
                        appSettings.bgGlowColor,
                        0.5,
                      )!,
                      appSettings.bgColor,
                    ],
                  ),
                  border: Border.all(color: cAsh),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(color: cAsh),
        const SizedBox(height: 16),

        // ── Customize ──
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

        // ── Reference ──
        const Text(
          'REFERENCE',
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
              Navigator.of(context).push(fadeRoute(const GesturesScreen())),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              color: cInk,
              border: Border.all(color: cAsh),
            ),
            child: Row(
              children: const [
                Icon(Icons.touch_app_outlined, size: 16, color: cSmoke),
                SizedBox(width: 12),
                Text(
                  'Gestures & Shortcuts',
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

        // ── Security ──
        const Text(
          'SECURITY',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cGold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        LoreTap(
          onTap: () => Navigator.of(
            context,
          ).push(fadeRoute(LockSetupScreen(isFirstTime: false))),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              color: cInk,
              border: Border.all(color: cAsh),
            ),
            child: Row(
              children: const [
                Icon(Icons.lock_outline, size: 16, color: cSmoke),
                SizedBox(width: 12),
                Text(
                  'PIN & Lock screen',
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
        const SizedBox(height: 10),
        LoreTap(
          onTap: () =>
              Navigator.of(context).push(fadeRoute(const QRScannerScreen())),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              color: cInk,
              border: Border.all(color: cAsh),
            ),
            child: Row(
              children: const [
                Icon(Icons.qr_code_scanner, size: 16, color: cSmoke),
                SizedBox(width: 12),
                Text(
                  'Link Desktop (Web)',
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
        const SizedBox(height: 10),
        LoreTap(
          onTap: _confirmSignOutOthers,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              color: cInk,
              border: Border.all(color: cAsh),
            ),
            child: Row(
              children: const [
                Icon(Icons.logout, size: 16, color: cSmoke),
                SizedBox(width: 12),
                Text(
                  'Sign out other devices',
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

        // ── Appearance ──

        // ── Appearance ──
        const Text(
          'APPEARANCE',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cGold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        _settingsToggle(
          'Card border effects',
          'Animated glows on discovery cards',
          appSettings.cardBorderEffects,
          (v) => appSettings.setCardBorderEffects(v),
        ),
        const SizedBox(height: 14),
        _settingsSegment(
          'Text size',
          ['Small', 'Medium', 'Large'],
          appSettings.textSize,
          (v) => appSettings.setTextSize(v),
        ),
        const SizedBox(height: 14),
        _settingsSegment(
          'Orientation',
          ['Portrait', 'Landscape', 'Both'],
          appSettings.orientation,
          (v) => appSettings.setOrientation(v),
        ),

        const SizedBox(height: 24),
        const Divider(color: cAsh),
        const SizedBox(height: 16),

        // ── Ambience ──
        const Text(
          'AMBIENCE',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cGold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Lore reads the mood of your story and shifts the scene around it.',
          style: TextStyle(
            fontSize: 12,
            color: cSmoke,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        _settingsToggle(
          'Mood generator',
          'Shifts the background based on what you write',
          appSettings.aiMood,
          (v) => appSettings.setAiMood(v),
        ),

        const SizedBox(height: 24),
        const Divider(color: cAsh),
        const SizedBox(height: 16),

        // ── Notifications ──
        const Text(
          'NOTIFICATIONS',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cGold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        _settingsToggle(
          'New post from partner',
          '',
          appSettings.notifNewPost,
          (v) => appSettings.setNotifNewPost(v),
        ),
        const SizedBox(height: 12),
        _settingsToggle(
          'New interest received',
          '',
          appSettings.notifInterest,
          (v) => appSettings.setNotifInterest(v),
        ),

        _settingsToggle(
          'Roleplay replies',
          'When your partner posts in an RP',
          appSettings.notifRpPost,
          (v) => appSettings.setNotifRpPost(v),
        ),
        const SizedBox(height: 12),
        _settingsToggle(
          'OOC messages',
          'Chat messages and media',
          appSettings.notifOoc,
          (v) => appSettings.setNotifOoc(v),
        ),
        const SizedBox(height: 12),
        _settingsToggle(
          'Prelude messages',
          'When your partner messages in a prelude',
          appSettings.notifBrainstorm,
          (v) => appSettings.setNotifBrainstorm(v),
        ),

        const SizedBox(height: 24),
        const Divider(color: cAsh),
        const SizedBox(height: 16),

        // ── RP Room ──
        const Text(
          'RP ROOM',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cGold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        _settingsToggle(
          'Auto-scroll to latest post',
          'On opening a room',
          appSettings.autoScroll,
          (v) => appSettings.setAutoScroll(v),
        ),
        const SizedBox(height: 14),
        _settingsSegment(
          'OOC bubble side',
          ['Left', 'Right'],
          appSettings.oocSide,
          (v) => appSettings.setOocSide(v),
        ),
        const SizedBox(height: 12),
        _settingsToggle(
          'Enter key behaviour',
          appSettings.enterToSend
              ? 'Press Enter to send, Shift+Enter for new line'
              : 'Press Shift+Enter to send, Enter for new line',
          appSettings.enterToSend,
          (v) => appSettings.setEnterToSend(v),
        ),

        const SizedBox(height: 24),
        const Divider(color: cAsh),
        const SizedBox(height: 16),

        // ── Sounds ──
        const Text(
          'SOUNDS',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cGold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        _settingsToggle(
          'App sounds',
          '',
          appSettings.soundEnabled,
          (v) => appSettings.setSoundEnabled(v),
        ),
        const SizedBox(height: 12),
        const _SoundSettings(),

        if (appSettings.devModeUnlocked) ...[
          const SizedBox(height: 24),
          const Divider(color: cAsh),
          const SizedBox(height: 16),
          const Text(
            'DEVELOPER',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              color: cEmber,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tools for testing Lore alone.',
            style: TextStyle(
              fontSize: 12,
              color: cSmoke,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 10),
          LoreTap(
            onTap: () async {
              // Capture the navigator BEFORE the await so we don't have to 
              // pass the context across an async gap.
              final nav = Navigator.of(context);
              final rpDemo = await DevTools.ensureDemoSession(status: 'active');
              final preludeDemo = await DevTools.ensureDemoSession(
                status: 'brainstorm',
              );
              if (rpDemo == null || preludeDemo == null) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: cInk,
                    content: Text(
                      'Could not create demo session. Have you set a PIN yet?',
                      style: TextStyle(color: cParchment),
                    ),
                  ),
                );
                return;
              }
              // Make sure the screen is still open after our await calls
              if (!mounted) return;

              // Push RP first, then prelude on top of it —
              // so both rooms are open. Back from prelude lands in RP.
              nav.push(
                fadeRoute(
                  RPRoomScreen(
                    partnerName: rpDemo.partnerName,
                    partnerCode: rpDemo.partnerCode,
                    genre: rpDemo.genre,
                    sessionId: rpDemo.sessionId,
                  ),
                ),
              );
              nav.push(
                fadeRoute(
                  BrainstormRoomScreen(
                    partnerName: preludeDemo.partnerName,
                    partnerCode: preludeDemo.partnerCode,
                    genre: preludeDemo.genre,
                    sessionId: preludeDemo.sessionId,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              decoration: BoxDecoration(
                color: cInk,
                border: Border.all(color: cAsh),
              ),
              child: const Row(
                children: [
                  Icon(Icons.developer_mode, size: 16, color: cEmber),
                  SizedBox(width: 12),
                  Text(
                    'Open demo rooms',
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

          const SizedBox(height: 10),
          LoreTap(
            onTap: () async {
              await DevTools.clearDemoData();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: cInk,
                  content: Text(
                    'Demo data cleared',
                    style: TextStyle(color: cParchment),
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              decoration: BoxDecoration(
                color: cInk,
                border: Border.all(color: cAsh),
              ),
              child: const Row(
                children: [
                  Icon(Icons.delete_outline, size: 16, color: cSmoke),
                  SizedBox(width: 12),
                  Text(
                    'Clear demo data',
                    style: TextStyle(
                      fontSize: 14,
                      color: cSmoke,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.chevron_right, size: 16, color: cSmoke),
                ],
              ),
            ),
          ),
        ], // ← This closes the devModeUnlocked if-spread
        // ── Support Section ──
        const SizedBox(height: 24),
        const Divider(color: cAsh),
        const SizedBox(height: 16),

        const Text(
          'SUPPORT',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cGold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Lore is ad-free and always will be. If you love the app and want to help cover the server costs, you can buy me a coffee.',
          style: TextStyle(
            fontSize: 12,
            color: cSmoke,
            fontStyle: FontStyle.italic,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        LoreTap(
          onTap: _launchDonationPage,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              color: cInk,
              border: Border.all(color: cAsh),
            ),
            child: Row(
              children: const [
                Icon(Icons.favorite_outline, size: 16, color: cEmber),
                SizedBox(width: 12),
                Text(
                  'Donate to Lore',
                  style: TextStyle(
                    fontSize: 14,
                    color: cMist,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Spacer(),
                Icon(Icons.open_in_new, size: 14, color: cSmoke),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ─────────────────────
      ],
    ), // ← This correctly closes the Column's children list
  ); // ← This correctly closes the Padding
}

Widget _settingsToggle(
  String label,
  String subtitle,
  bool value,
  ValueChanged<bool> onChanged,
) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: cMist,
              fontWeight: FontWeight.w300,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: cSmoke,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    ),
    const SizedBox(width: 12),
    Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: cGold,
      inactiveTrackColor: cAsh,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  ],
);

Widget _settingsSegment(
  String label,
  List<String> options,
  String current,
  ValueChanged<String> onChanged,
) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        color: cMist,
        fontWeight: FontWeight.w300,
      ),
    ),
    const SizedBox(height: 8),
    Row(
      children: options.map((o) {
        final active = current == o;
        return LoreTap(
          onTap: () => onChanged(o),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: active ? cGold : cAsh),
              color: active ? cGold.withValues(alpha: 0.1) : Colors.transparent,
            ),
            child: Text(
              o,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                letterSpacing: 1,
                color: active ? cGold : cSmoke,
              ),
            ),
          ),
        );
      }).toList(),
    ),
  ],
);

// ════════════════════════════════════════
// SOUND SETTINGS WIDGET
// ════════════════════════════════════════
class _SoundSettings extends StatefulWidget {
  const _SoundSettings();
  @override
  State<_SoundSettings> createState() => _SoundSettingsState();
}

class _SoundSettingsState extends State<_SoundSettings> {
  bool _masterMute = false;
  double _masterVolume = 1.0;
  final Map<String, bool> _enabled = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await sounds.init();
    final master = sounds.masterMute;
    final map = <String, bool>{};
    for (final key in SoundKey.all) {
      map[key] = sounds.isEnabled(key) || master;
    }
    if (mounted) {
      setState(() {
        _masterMute = master;
        _masterVolume = sounds.masterVolume;
        _enabled.addAll(map);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Master mute toggle
        _soundRow(
          label: 'All sounds',
          subtitle: 'Master mute',
          value: !_masterMute,
          onChanged: (v) async {
            await sounds.setMasterMute(!v);
            setState(() => _masterMute = !v);
          },
          icon: _masterMute ? Icons.volume_off : Icons.volume_up,
          color: cGold,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(_masterVolume == 0 ? Icons.volume_off : Icons.volume_up, size: 14, color: cGold),
            const SizedBox(width: 8),
            const Expanded(child: Text('Master volume', style: TextStyle(fontSize: 13, color: cMist, fontWeight: FontWeight.w300))),
            Text('%', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: cSmoke)),
          ],
        ),
        Slider(
          value: _masterVolume,
          min: 0.0,
          max: 1.0,
          divisions: 20,
          activeColor: cGold,
          inactiveColor: cAsh,
          onChanged: _masterMute ? null : (v) async { await sounds.setMasterVolume(v); setState(() => _masterVolume = v); },
        ),
        const SizedBox(height: 12),
        Container(
          height: 1,
          color: cAsh.withValues(alpha: 0.5),
          margin: const EdgeInsets.only(bottom: 12),
        ),
        // Individual sound toggles
        ...SoundKey.all.map((key) {
          final label = SoundKey.labels[key] ?? key;
          final enabled = _enabled[key] ?? true;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _soundRow(
              label: label,
              value: enabled,
              muted: _masterMute,
              onChanged: _masterMute
                  ? null
                  : (v) async {
                      await sounds.setEnabled(key, v);
                      setState(() => _enabled[key] = v);
                    },
            ),
          );
        }),
      ],
    );
  }

  Widget _soundRow({
    required String label,
    String? subtitle,
    required bool value,
    bool muted = false,
    IconData? icon,
    Color? color,
    ValueChanged<bool>? onChanged,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color ?? cSmoke),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: muted && onChanged != null ? cSmoke : cMist,
                  fontWeight: FontWeight.w300,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: cSmoke,
                    letterSpacing: 1,
                  ),
                ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: color ?? cGold,
          inactiveThumbColor: cAsh,
          inactiveTrackColor: cInk,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}