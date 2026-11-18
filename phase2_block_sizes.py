import pathlib, re

# --- 1. settings.dart: add size to BlockStyle ---
p = pathlib.Path("lib/settings.dart")
t = p.read_text(encoding="utf-8")

# 1a. Field
old = "  final Color? accent;"
assert old in t
t = t.replace(old, "  final Color? accent;\n  final String size;", 1)

# 1b. Constructor default
old = "    this.accent,"
assert old in t
t = t.replace(old, "    this.accent,\n    this.size = 'normal',", 1)

# 1c. isDefault: size must be normal to count as default
old = "      background == null && glowColor == null && !glowEnabled && accent == null;"
assert old in t, "isDefault line not found"
t = t.replace(old, "      background == null && glowColor == null && !glowEnabled && accent == null && size == 'normal';", 1)

# 1d. copyWith param
old = "    Color? accent,"
assert old in t
# only the copyWith one — it appears after "BlockStyle copyWith({"
idx = t.index("BlockStyle copyWith({")
seg = t[idx:idx+600]
assert "Color? accent," in seg
t = t[:idx] + seg.replace("    Color? accent,\n", "    Color? accent,\n    String? size,\n", 1) + t[idx+600:]

# 1e. copyWith body: pass size through
old = "      accent: clearAccent ? null : (accent ?? this.accent),"
assert old in t
t = t.replace(old, old + "\n      size: size ?? this.size,", 1)

# 1f. toJson: save sz only when not normal
old = "    if (accent != null) 'ac': accent!.toARGB32(),"
assert old in t
t = t.replace(old, old + "\n    if (size != 'normal') 'sz': size,", 1)

# 1g. fromJson: read sz, default normal
old = "      accent: j['ac'] != null ? Color(j['ac'] as int) : null,"
assert old in t
t = t.replace(old, old + "\n      size: j['sz'] as String? ?? 'normal',", 1)

p.write_text(t, encoding="utf-8")
print("settings: BlockStyle.size added")

# --- 2. block_style_sheet.dart: Size chips in Block sheet ---
p = pathlib.Path("lib/widgets/block_style_sheet.dart")
t = p.read_text(encoding="utf-8")

# 2a. Size UI after _glowRow(s) in the BLOCK sheet (Profile uses _glowRow() with no arg)
old = "                  _glowRow(s),"
assert old in t, "Block _glowRow(s) not found"
new = """                  _glowRow(s),
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
                  ),"""
t = t.replace(old, new, 1)

# 2b. _sizeChip helper — insert before _targetChip in _BlockStyleSheetState
# Find the FIRST _targetChip (Block sheet's), insert before it
idx = t.index("  Widget _targetChip(String label, String target) {")
helper = """  Widget _sizeChip(String label, String value) {
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

"""
t = t[:idx] + helper + t[idx:]
p.write_text(t, encoding="utf-8")
print("block sheet: Size chips added")

# --- 3. main.dart: home tiles read size ---
p = pathlib.Path("lib/main.dart")
t = p.read_text(encoding="utf-8")

# 3a. Tile inner padding: S=8 / M=12 / L=22 vertical
old = "                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),"
assert old in t, "home tile padding not found"
new = """                padding: EdgeInsets.symmetric(
                  vertical: appSettings.styleForBlock(items[i].blockKey).size == 'small'
                      ? 8
                      : appSettings.styleForBlock(items[i].blockKey).size == 'large'
                          ? 22
                          : 12,
                  horizontal: 10,
                ),"""
t = t.replace(old, new, 1)

# 3b. Icon size: S=14 / M=18 / L=22
old = "                    Icon(items[i].icon, size: 18, color: appSettings.styleForBlock(items[i].blockKey).accent ?? items[i].accent),"
assert old in t, "home tile icon not found"
new = """                    Icon(
                      items[i].icon,
                      size: appSettings.styleForBlock(items[i].blockKey).size == 'small'
                          ? 14
                          : appSettings.styleForBlock(items[i].blockKey).size == 'large'
                              ? 22
                              : 18,
                      color: appSettings.styleForBlock(items[i].blockKey).accent ?? items[i].accent,
                    ),"""
t = t.replace(old, new, 1)

# 3c. Label font: S=12 / M=14 / L=16
old = """                          style: const TextStyle(
                            fontSize: 14,
                            color: cMist,
                            fontWeight: FontWeight.w300,
                          ),"""
assert old in t, "home tile label style not found"
new = """                          style: TextStyle(
                            fontSize: appSettings.styleForBlock(items[i].blockKey).size == 'small'
                                ? 12
                                : appSettings.styleForBlock(items[i].blockKey).size == 'large'
                                    ? 16
                                    : 14,
                            color: cMist,
                            fontWeight: FontWeight.w300,
                          ),"""
t = t.replace(old, new, 1)

p.write_text(t, encoding="utf-8")
print("main: home tiles read size")