import 'package:flutter/material.dart';
import '../theme.dart';
import '../settings.dart';
import 'colour_picker.dart';

/// Colour palette shown for every colour row.
const List<Color> _palette = [
  cVoid,
  cInk,
  cAsh,
  cSmoke,
  cMist,
  cParchment,
  cGold,
  cIce,
  cEmber,
  cMagic,
  cVine,
  Colors.white,
];

/// Long-press customization sheet for a single home grid block.
class BlockStyleSheet extends StatefulWidget {
  final String blockKey;
  const BlockStyleSheet({super.key, required this.blockKey});

  static Future<void> show(BuildContext context, String blockKey) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: cInk,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(),
      builder: (_) => BlockStyleSheet(blockKey: blockKey),
    );
  }

  @override
  State<BlockStyleSheet> createState() => _BlockStyleSheetState();
}

class _BlockStyleSheetState extends State<BlockStyleSheet> {
  BlockStyle get _style => appSettings.styleForBlock(widget.blockKey);
  List<String> get _textKeys => appSettings.textKeysForBlock(widget.blockKey);
  String get _blockLabel =>
      AppSettings.blockLabels[widget.blockKey] ?? widget.blockKey;

  String _selectedTarget = 'background';

  String _selectedTargetLabel() {
    if (_selectedTarget == 'background') return 'Background';
    if (_selectedTarget == 'accent') return 'Accent (icon & badge)';
    if (_selectedTarget == 'glow') return 'Glow colour';
    if (_selectedTarget.startsWith('text:')) {
      final key = _selectedTarget.substring(5);
      return AppSettings.textKeyLabels[key] ?? key;
    }
    return 'Colour';
  }

  Color? _currentForSelected() {
    final s = _style;
    if (_selectedTarget == 'background') return s.background;
    if (_selectedTarget == 'accent') return s.accent;
    if (_selectedTarget == 'glow') return s.glowColor;
    if (_selectedTarget.startsWith('text:')) {
      return appSettings.textColourFor(_selectedTarget.substring(5));
    }
    return null;
  }

  Future<void> _applyToSelected(Color? c) async {
    final s = _style;
    if (_selectedTarget == 'background') {
      await _updateTile(s.copyWith(background: c, clearBackground: c == null));
    } else if (_selectedTarget == 'accent') {
      await _updateTile(s.copyWith(accent: c, clearAccent: c == null));
    } else if (_selectedTarget == 'glow') {
      await _updateTile(s.copyWith(glowColor: c, clearGlowColor: c == null));
    } else if (_selectedTarget.startsWith('text:')) {
      await _updateText(_selectedTarget.substring(5), c);
    }
  }

  Widget _sizeChip(String label, String value) {
    final active = _style.size == value;
    return GestureDetector(
      onTap: () => _updateTile(_style.copyWith(size: value)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: active ? cGold : cAsh),
          color: active ? cGold.withValues(alpha: 0.08) : Colors.transparent,
        ),
        child: Text(
          label,
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

  Widget _targetChip(String label, String target) {
    final active = _selectedTarget == target;
    return GestureDetector(
      onTap: () => setState(() => _selectedTarget = target),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: active ? cGold : cAsh),
          color: active ? cGold.withValues(alpha: 0.08) : Colors.transparent,
        ),
        child: Text(
          label,
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

  Future<void> _updateTile(BlockStyle newStyle) async {
    await appSettings.setBlockStyle(widget.blockKey, newStyle);
    if (mounted) setState(() {});
  }

  Future<void> _updateText(String key, Color? colour) async {
    await appSettings.setTextColour(key, colour);
    if (mounted) setState(() {});
  }

  Future<void> _reset() async {
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
                'RESET BLOCK',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: cEmber,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Reset $_blockLabel to the default appearance? '
                'This clears the tile style and all text colours in this block.',
                style: const TextStyle(
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
                    child: GestureDetector(
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
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: cEmber.withValues(alpha: 0.8),
                        child: const Center(
                          child: Text(
                            'Reset',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              color: cParchment,
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
    );
    if (confirm == true) {
      await appSettings.resetBlock(widget.blockKey);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    final mq = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.85),
      decoration: const BoxDecoration(
        color: cInk,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: cAsh,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                const Text(
                  'CUSTOMIZE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: cGold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _blockLabel,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      color: cParchment,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 18, color: cSmoke),
                ),
              ],
            ),
          ),
          const Divider(color: cAsh, height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('COLOUR'),
                  const SizedBox(height: 12),
                  const Text(
                    'What do you want to change?',
                    style: TextStyle(
                      fontSize: 11,
                      color: cSmoke,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _targetChip('Background', 'background'),
                      _targetChip('Accent (icon & badge)', 'accent'),
                      if (s.glowEnabled) _targetChip('Glow colour', 'glow'),
                      ..._textKeys.map(
                        (key) => _targetChip(
                          AppSettings.textKeyLabels[key] ?? key,
                          'text:$key',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _colourRow(
                    label: _selectedTargetLabel(),
                    current: _currentForSelected(),
                    onPicked: (c) => _applyToSelected(c),
                  ),
                  const SizedBox(height: 18),
                  _glowRow(s),
                  const SizedBox(height: 18),
                  _sectionLabel('SIZE'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _sizeChip('Small', 'small'),
                      _sizeChip('Normal', 'normal'),
                      _sizeChip('Large', 'large'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(height: 1, color: cAsh),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _reset,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: cEmber.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'Reset block',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  color: cEmber,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            color: cParchment,
                            child: const Center(
                              child: Text(
                                'Done',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
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
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontFamily: 'monospace',
      fontSize: 9,
      color: cGold,
      letterSpacing: 3,
    ),
  );

  Widget _colourRow({
    required String label,
    required Color? current,
    required ValueChanged<Color?> onPicked,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: cMist,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(width: 8),
            if (current != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(border: Border.all(color: cAsh)),
                child: const Text(
                  'set',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 8,
                    color: cSmoke,
                    letterSpacing: 1,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _defaultChip(
                active: current == null,
                onTap: () => onPicked(null),
              ),
              const SizedBox(width: 10),
              ..._palette.map(
                (c) => _swatch(
                  c,
                  selected: current == c,
                  onTap: () => onPicked(c),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => LoreColourPicker.show(
                  context,
                  current: current ?? cGold,
                  onPicked: onPicked,
                ),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    border: Border.all(color: cGold),
                    color: cGold.withValues(alpha: 0.1),
                  ),
                  child: const Center(
                    child: Icon(Icons.colorize, size: 16, color: cGold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _glowRow(BlockStyle s) {
    // EDIT 10c: Replaces Border style + Shape rows.
    // Both were dead — the tile renderer never read borderStyle or
    // shape. Tile now has only Glow on/off + its own Glow colour,
    // same model as the profile card.
    Widget chip({required String label, required bool active, required VoidCallback onTap}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: active ? cGold : cAsh),
            color: active ? cGold.withValues(alpha: 0.08) : Colors.transparent,
          ),
          child: Text(
            label,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Glow',
          style: TextStyle(
            fontSize: 13,
            color: cMist,
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            chip(
              label: 'ON',
              active: s.glowEnabled,
              onTap: () => _updateTile(s.copyWith(glowEnabled: true)),
            ),
            chip(
              label: 'OFF',
              active: !s.glowEnabled,
              onTap: () => _updateTile(s.copyWith(glowEnabled: false)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _defaultChip({required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          border: Border.all(color: active ? cGold : cAsh),
          color: active ? cGold.withValues(alpha: 0.08) : Colors.transparent,
        ),
        child: Center(
          child: Icon(
            Icons.format_color_reset_outlined,
            size: 16,
            color: active ? cGold : cSmoke,
          ),
        ),
      ),
    );
  }

  Widget _swatch(
    Color c, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? cGold : Colors.white24,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}

/// Long-press customization sheet for the profile card.
class ProfileStyleSheet extends StatefulWidget {
  const ProfileStyleSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: cInk,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(),
      builder: (_) => const ProfileStyleSheet(),
    );
  }

  @override
  State<ProfileStyleSheet> createState() => _ProfileStyleSheetState();
}

class _ProfileStyleSheetState extends State<ProfileStyleSheet> {
  List<Color> get _gradient => appSettings.profileGradient;
  Color get _borderColor => appSettings.profileBorderColor;
  bool get _glowEnabled => appSettings.profileGlowEnabled;
  Color get _glowColor => appSettings.profileGlowColor;
  List<String> get _textKeys => appSettings.textKeysForBlock('profile');

  String _selectedTarget = 'gradientStart';

  String _selectedTargetLabel() {
    if (_selectedTarget == 'gradientStart') return 'Gradient Start';
    if (_selectedTarget == 'gradientEnd') return 'Gradient End';
    if (_selectedTarget == 'frame') return 'Frame colour';
    if (_selectedTarget == 'glow') return 'Glow colour';
    if (_selectedTarget.startsWith('text:')) {
      final key = _selectedTarget.substring(5);
      return AppSettings.textKeyLabels[key] ?? key;
    }
    return 'Colour';
  }

  Color? _currentForSelected() {
    if (_selectedTarget == 'gradientStart') {
      return _gradient.isNotEmpty ? _gradient[0] : null;
    }
    if (_selectedTarget == 'gradientEnd') {
      return _gradient.length > 1 ? _gradient[1] : null;
    }
    if (_selectedTarget == 'frame') return _borderColor;
    if (_selectedTarget == 'glow') return _glowColor;
    if (_selectedTarget.startsWith('text:')) {
      return appSettings.textColourFor(_selectedTarget.substring(5));
    }
    return null;
  }

  Future<void> _applyToSelected(Color? c) async {
    if (_selectedTarget == 'gradientStart') {
      if (c == null) return;
      await _setGradient([c, _gradient.length > 1 ? _gradient[1] : c]);
    } else if (_selectedTarget == 'gradientEnd') {
      if (c == null) return;
      await _setGradient([_gradient.isNotEmpty ? _gradient[0] : c, c]);
    } else if (_selectedTarget == 'frame') {
      if (c != null) await _setBorderColor(c);
    } else if (_selectedTarget == 'glow') {
      if (c != null) await _setGlowColor(c);
    } else if (_selectedTarget.startsWith('text:')) {
      await _setText(_selectedTarget.substring(5), c);
    }
  }

  Widget _targetChip(String label, String target) {
    final active = _selectedTarget == target;
    return GestureDetector(
      onTap: () => setState(() => _selectedTarget = target),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: active ? cGold : cAsh),
          color: active ? cGold.withValues(alpha: 0.08) : Colors.transparent,
        ),
        child: Text(
          label,
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


  Future<void> _setGradient(List<Color> g) async {
    await appSettings.setProfileGradient(g);
    if (mounted) setState(() {});
  }

  Future<void> _setBorderColor(Color c) async {
    await appSettings.setProfileBorderColor(c);
    if (mounted) setState(() {});
  }

  Future<void> _setGlowEnabled(bool v) async {
    await appSettings.setProfileGlowEnabled(v);
    if (mounted) setState(() {});
  }

  Future<void> _setGlowColor(Color c) async {
    await appSettings.setProfileGlowColor(c);
    if (mounted) setState(() {});
  }

  Future<void> _setText(String key, Color? c) async {
    await appSettings.setTextColour(key, c);
    if (mounted) setState(() {});
  }

  Future<void> _reset() async {
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
                'RESET PROFILE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: cEmber,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Reset the profile card to its default appearance? '
                'This clears the gradient, frame colour, glow, and profile text colours.',
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
                    child: GestureDetector(
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
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: cEmber.withValues(alpha: 0.8),
                        child: const Center(
                          child: Text(
                            'Reset',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              color: cParchment,
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
    );
    if (confirm != true) return;
    await appSettings.setProfileGradient([
      const Color(0xFF080808),
      const Color(0xFF0E0E0E),
    ]);
    await appSettings.setProfileBorderColor(const Color(0xFF2a2a2a));
    await appSettings.setProfileGlowEnabled(false);
    await appSettings.setProfileGlowColor(Colors.black);
    for (final k in _textKeys) {
      await appSettings.setTextColour(k, null);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.85),
      decoration: const BoxDecoration(
        color: cInk,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: cAsh,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                const Text(
                  'CUSTOMIZE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: cGold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Profile Card',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: cParchment,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 18, color: cSmoke),
                ),
              ],
            ),
          ),
          const Divider(color: cAsh, height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section('COLOUR'),
                  const SizedBox(height: 12),
                  const Text(
                    'What do you want to change?',
                    style: TextStyle(
                      fontSize: 11,
                      color: cSmoke,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _targetChip('Gradient Start', 'gradientStart'),
                      _targetChip('Gradient End', 'gradientEnd'),
                      _targetChip('Frame colour', 'frame'),
                      if (_glowEnabled) _targetChip('Glow colour', 'glow'),
                      ..._textKeys.map(
                        (key) => _targetChip(
                          AppSettings.textKeyLabels[key] ?? key,
                          'text:$key',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _colourRow(
                    label: _selectedTargetLabel(),
                    current: _currentForSelected(),
                    onPicked: (c) => _applyToSelected(c),
                  ),
                  const SizedBox(height: 18),
                  _glowRow(),
                  const SizedBox(height: 24),
                  _section('ANIMATED BORDER'),
                  const SizedBox(height: 6),
                  const Text(
                    'Pattern running around the card. Colour comes from Frame colour above.',
                    style: TextStyle(
                      fontSize: 11,
                      color: cSmoke,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _patternRow(),
                  const SizedBox(height: 14),
                  _valueSlider(
                    label: 'Thickness',
                    valueLabel: appSettings.animatedBorderThickness.toStringAsFixed(1),
                    value: appSettings.animatedBorderThickness,
                    min: 1,
                    max: 8,
                    onChanged: (v) => appSettings.setAnimatedBorderThickness(v),
                  ),
                  _valueSlider(
                    label: 'Waviness',
                    valueLabel: appSettings.animatedBorderWaviness.toStringAsFixed(1),
                    value: appSettings.animatedBorderWaviness,
                    min: 0,
                    max: 12,
                    onChanged: (v) => appSettings.setAnimatedBorderWaviness(v),
                  ),
                  _valueSlider(
                    label: 'Speed',
                    valueLabel: '${appSettings.animatedBorderSpeed.toStringAsFixed(1)}x',
                    value: appSettings.animatedBorderSpeed,
                    min: 0.3,
                    max: 2.5,
                    onChanged: (v) => appSettings.setAnimatedBorderSpeed(v),
                  ),
                  _valueSlider(
                    label: 'Opacity',
                    valueLabel: '${(appSettings.animatedBorderOpacity * 100).round()}%',
                    value: appSettings.animatedBorderOpacity,
                    min: 0.3,
                    max: 1.0,
                    onChanged: (v) => appSettings.setAnimatedBorderOpacity(v),
                  ),
                  _valueSlider(
                    label: 'Frame outset',
                    valueLabel: appSettings.animatedBorderFrameOutset.toStringAsFixed(0),
                    value: appSettings.animatedBorderFrameOutset,
                    min: -8,
                    max: 20,
                    onChanged: (v) => appSettings.setAnimatedBorderFrameOutset(v),
                  ),

                  const SizedBox(height: 8),
                  Container(height: 1, color: cAsh),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _reset,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: cEmber.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'Reset profile',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  color: cEmber,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            color: cParchment,
                            child: const Center(
                              child: Text(
                                'Done',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
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
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _patternRow() {
    const options = ['waves', 'spikes', 'gears', 'dice', 'swords', 'leaves', 'shields', 'flames', 'stars', 'runes', 'thorns', 'feathers', 'claws'];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.map((o) {
        final active = appSettings.animatedBorderPattern == o;
        return GestureDetector(
          onTap: () async {
            await appSettings.setAnimatedBorderPattern(o);
            if (mounted) setState(() {});
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: active ? cGold : cAsh),
              color: active ? cGold.withValues(alpha: 0.08) : Colors.transparent,
            ),
            child: Text(
              o[0].toUpperCase() + o.substring(1),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                letterSpacing: 1,
                color: active ? cGold : cSmoke,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _section(String text) => Text(
    text,
    style: const TextStyle(
      fontFamily: 'monospace',
      fontSize: 9,
      color: cGold,
      letterSpacing: 3,
    ),
  );

  Widget _valueSlider({
    required String label,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: cMist,
                fontWeight: FontWeight.w300,
              ),
            ),
            const Spacer(),
            Text(
              valueLabel,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                color: cGold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: cGold,
            inactiveTrackColor: cAsh,
            thumbColor: cParchment,
            overlayColor: cGold.withValues(alpha: 0.2),
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: (v) async {
              onChanged(v);
              if (mounted) setState(() {});
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _colourRow({
    required String label,
    required Color? current,
    required ValueChanged<Color?> onPicked,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: cMist,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(width: 8),
            if (current != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(border: Border.all(color: cAsh)),
                child: const Text(
                  'set',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 8,
                    color: cSmoke,
                    letterSpacing: 1,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              GestureDetector(
                onTap: () => onPicked(null),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    border: Border.all(color: current == null ? cGold : cAsh),
                    color: current == null ? cGold.withValues(alpha: 0.08) : Colors.transparent,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.format_color_reset_outlined,
                      size: 16,
                      color: current == null ? cGold : cSmoke,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ..._palette.map(
                (c) => GestureDetector(
                  onTap: () => onPicked(c),
                  child: Container(
                    width: 34,
                    height: 34,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: current == c ? cGold : Colors.white24,
                        width: current == c ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => LoreColourPicker.show(
                  context,
                  current: current ?? cGold,
                  onPicked: onPicked,
                ),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    border: Border.all(color: cGold),
                    color: cGold.withValues(alpha: 0.1),
                  ),
                  child: const Center(
                    child: Icon(Icons.colorize, size: 16, color: cGold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _glowRow() {
    // EDIT 9c: Replaces the dead Border style chips.
    // Glow is not a border style anymore — it's an on/off halo with
    // its own colour, so it can contrast with the frame:
    // e.g. white Runes on a black glow.
    Widget chip({required String label, required bool active, required VoidCallback onTap}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: active ? cGold : cAsh),
            color: active ? cGold.withValues(alpha: 0.08) : Colors.transparent,
          ),
          child: Text(
            label,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Glow',
          style: TextStyle(
            fontSize: 13,
            color: cMist,
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            chip(label: 'ON', active: _glowEnabled, onTap: () => _setGlowEnabled(true)),
            chip(label: 'OFF', active: !_glowEnabled, onTap: () => _setGlowEnabled(false)),
          ],
        ),
      ],
    );
  }
}