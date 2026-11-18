import pathlib
p = pathlib.Path("lib/widgets/block_style_sheet.dart")
t = p.read_text(encoding="utf-8")

# --- 1. Add target-selector state + helpers to _BlockStyleSheetState ---
anchor = """  String get _blockLabel =>
      AppSettings.blockLabels[widget.blockKey] ?? widget.blockKey;
"""
assert anchor in t, "blockLabel anchor not found"
helpers = anchor + """
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
"""
t = t.replace(anchor, helpers, 1)

# --- 2. Replace Block build body: TILE + 5x _colourRow -> COLOUR + target chips + ONE _colourRow ---
start = t.index("                  _sectionLabel('TILE'),")
end_marker = "                  const SizedBox(height: 8),\n                  Container(height: 1, color: cAsh),"
end = t.index(end_marker, start)
new_body = """                  _sectionLabel('COLOUR'),
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
"""
t = t[:start] + new_body + t[end:]

# --- 3. Remove Glow colour row from _glowRow (it now lives in the target selector) ---
old_glow_colour = """        if (s.glowEnabled) ...[
          const SizedBox(height: 18),
          _colourRow(
            label: 'Glow colour',
            current: s.glowColor,
            onPicked: (c) => _updateTile(
              s.copyWith(glowColor: c, clearGlowColor: c == null),
            ),
          ),
        ],
"""
assert old_glow_colour in t, "glow colour block in _glowRow not found"
t = t.replace(old_glow_colour, "", 1)

p.write_text(t, encoding="utf-8")
print("BlockStyleSheet converted to target-selector + one picker")