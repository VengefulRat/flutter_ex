import pathlib
p = pathlib.Path("lib/main.dart")
t = p.read_text(encoding="utf-8")

# 1. Tile background + border + glow: use per-block style, fall back to defaults
old_deco = """              decoration: BoxDecoration(
                color: appSettings.surfaceColor,
                border: Border.all(color: cAsh, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),"""
assert old_deco in t, "home tile decoration not found"
new_deco = """              decoration: BoxDecoration(
                color: appSettings.styleForBlock(items[i].blockKey).background ??
                    appSettings.surfaceColor,
                border: Border.all(color: cAsh, width: 1.5),
                borderRadius: BorderRadius.circular(12),
                boxShadow: appSettings.styleForBlock(items[i].blockKey).glowEnabled
                    ? [
                        BoxShadow(
                          color: (appSettings.styleForBlock(items[i].blockKey).glowColor ??
                                  cGold)
                              .withValues(alpha: 0.35),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),"""
t = t.replace(old_deco, new_deco, 1)

# 2. Icon colour: per-block accent, fall back to floating-menu accent
old_icon = "                    Icon(items[i].icon, size: 18, color: items[i].accent),"
assert old_icon in t, "home tile icon not found"
new_icon = "                    Icon(items[i].icon, size: 18, color: appSettings.styleForBlock(items[i].blockKey).accent ?? items[i].accent),"
t = t.replace(old_icon, new_icon, 1)

p.write_text(t, encoding="utf-8")
print("home tiles now read BlockStyle")