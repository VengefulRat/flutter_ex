import pathlib, re

# --- 1. settings.dart: add size to BlockStyle ---
p = pathlib.Path("lib/settings.dart")
t = p.read_text(encoding="utf-8")

# 1a. Field — first "final Color? accent;" is BlockStyle's
old = "  final Color? accent;"
assert old in t
t = t.replace(old, "  final Color? accent;\n  final String size;", 1)

# 1b. Constructor default — BlockStyle constructor ends with this.accent,
old = "    this.accent,\n  });"
assert old in t, "BlockStyle constructor not found"
t = t.replace(old, "    this.accent,\n    this.size = 'normal',\n  });", 1)

# 1c. isDefault — TWO lines in your file
old = """  bool get isDefault =>
      background == null && glowColor == null && !glowEnabled && accent == null;"""
assert old in t, "isDefault not found"
t = t.replace(old, """  bool get isDefault =>
      background == null && glowColor == null && !glowEnabled && accent == null && size == 'normal';""", 1)

# 1d. copyWith param — the one followed by clearBackground
old = "    Color? accent,\n    bool clearBackground = false,"
assert old in t, "copyWith params not found"
t = t.replace(old, "    Color? accent,\n    String? size,\n    bool clearBackground = false,", 1)

# 1e. copyWith body
old = "    accent: clearAccent ? null : (accent ?? this.accent),"
assert old in t, "copyWith body not found"
t = t.replace(old, old + "\n    size: size ?? this.size,", 1)

# 1f. toJson
old = "    if (accent != null) 'ac': accent!.toARGB32(),"
assert old in t, "toJson accent not found"
t = t.replace(old, old + "\n    if (size != 'normal') 'sz': size,", 1)

# 1g. fromJson — match with regex so indent doesn't matter
m = re.search(r"accent: j\['ac'\] != null \? Color\(j\['ac'\] as int\) : null,", t)
assert m, "fromJson accent not found"
t = t[:m.end()] + "\n      size: j['sz'] as String? ?? 'normal'," + t[m.end():]

p.write_text(t, encoding="utf-8")
print("settings: BlockStyle.size added")

# --- 2. block_style_sheet.dart: Size chips in Block sheet ---
p = pathlib.Path("lib/widgets/block_style_sheet.dart")
t = p.read_text(encoding="utf-8")

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