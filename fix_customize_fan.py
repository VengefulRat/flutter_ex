import pathlib
p = pathlib.Path("lib/screens/customize_screen.dart")
t = p.read_text(encoding="utf-8")

# 1. Fan card size UI under Floating menu colour
old = """                      const SizedBox(height: 24),
                      const Divider(color: cAsh),
                      const SizedBox(height: 16),
                      _section('MOTION'),"""
assert old in t, "MOTION anchor not found"
if "Fan card size" not in t:
    new = """                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text(
                            'Fan card size',
                            style: TextStyle(fontSize: 13, color: cMist, fontWeight: FontWeight.w300),
                          ),
                          const Spacer(),
                          _fanSizeChip('S', 'small'),
                          const SizedBox(width: 6),
                          _fanSizeChip('M', 'normal'),
                          const SizedBox(width: 6),
                          _fanSizeChip('L', 'large'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: cAsh),
                      const SizedBox(height: 16),
                      _section('MOTION'),"""
    t = t.replace(old, new, 1)
    print("Fan card size UI added")
else:
    print("Fan card size UI already present, skipping")

# 2. Helper — anchor is STATIC
if "Widget _fanSizeChip" not in t:
    anchor = "  static Widget _section(String text)"
    assert anchor in t, "_section helper not found"
    helper = """  static Widget _fanSizeChip(String label, String value) {
    final active = appSettings.fanCardSize == value;
    return GestureDetector(
      onTap: () => appSettings.setFanCardSize(value),
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
    t = t.replace(anchor, helper + anchor, 1)
    print("_fanSizeChip helper added")
else:
    print("_fanSizeChip already present, skipping")

p.write_text(t, encoding="utf-8")
print("customize done")