import pathlib

# --- 1. floating_menu.dart: button colour + pass gyro through ---
p = pathlib.Path("lib/widgets/floating_menu.dart")
t = p.read_text(encoding="utf-8")

# 1a. Define menuColour inside build's LayoutBuilder
old = """        final screen = Size(constraints.maxWidth, constraints.maxHeight);
        final pos = _currentPos(screen);"""
assert old in t, "floating build anchor not found"
new = """        final screen = Size(constraints.maxWidth, constraints.maxHeight);
        final pos = _currentPos(screen);
        final menuColour = appSettings.floatingMenuColor;"""
t = t.replace(old, new, 1)

# 1b. Button: cGold -> menuColour (only the 3 uses in the round button)
old_border = """                    border: Border.all(
                      color: cGold.withValues(alpha: 0.7),
                      width: 1.5,
                    ),"""
assert old_border in t
t = t.replace(old_border, """                    border: Border.all(
                      color: menuColour.withValues(alpha: 0.7),
                      width: 1.5,
                    ),""", 1)

old_shadow = """                      BoxShadow(
                        color: cGold.withValues(alpha: 0.3),
                        blurRadius: 22,
                        spreadRadius: 2,
                      ),"""
assert old_shadow in t
t = t.replace(old_shadow, """                      BoxShadow(
                        color: menuColour.withValues(alpha: 0.3),
                        blurRadius: 22,
                        spreadRadius: 2,
                      ),""", 1)

old_icon = """                      child: Icon(
                        _menuOpen ? Icons.close : widget.menuIcon,
                        color: cGold,
                        size: 24,
                      ),"""
assert old_icon in t
t = t.replace(old_icon, """                      child: Icon(
                        _menuOpen ? Icons.close : widget.menuIcon,
                        color: menuColour,
                        size: 24,
                      ),""", 1)

# 1c. Fan cards: pass global gyro switch through
old_holo = """    tile = HoloCardV2(
      accent: accent,
      intensity: 0.35,"""
assert old_holo in t, "fan HoloCardV2 not found"
t = t.replace(old_holo, """    tile = HoloCardV2(
      accent: accent,
      gyroEnabled: appSettings.gyroEnabled,
      intensity: 0.35,""", 1)
p.write_text(t, encoding="utf-8")
print("floating_menu wired")

# --- 2. holo_card_v2.dart: global gyro switch wins over per-card default ---
p = pathlib.Path("lib/widgets/holo_card_v2.dart")
t = p.read_text(encoding="utf-8")

old_import = "import 'holo_parallax.dart';"
assert old_import in t
if "settings.dart" not in t:
    t = t.replace(old_import, old_import + "\nimport '../settings.dart';", 1)

# Effective gyro = per-card flag AND global switch
old_state = """class _HoloCardV2State extends State<HoloCardV2> with TickerProviderStateMixin {"""
assert old_state in t
t = t.replace(old_state, old_state + "\n  bool get _gyroAllowed => widget.gyroEnabled && appSettings.gyroEnabled;", 1)

old_init = "    if (widget.gyroEnabled && !kIsWeb) {"
assert old_init in t
t = t.replace(old_init, "    if (_gyroAllowed && !kIsWeb) {", 1)

old_did = """    if (oldWidget.gyroEnabled == widget.gyroEnabled) return;
    if (widget.gyroEnabled && !kIsWeb && !_gyroAcquired) {"""
assert old_did in t
t = t.replace(old_did, """    final oldAllowed = oldWidget.gyroEnabled && appSettings.gyroEnabled;
    if (oldAllowed == _gyroAllowed) return;
    if (_gyroAllowed && !kIsWeb && !_gyroAcquired) {""", 1)

old_else = "    } else if (!widget.gyroEnabled && _gyroAcquired) {"
assert old_else in t
t = t.replace(old_else, "    } else if (!_gyroAllowed && _gyroAcquired) {", 1)

p.write_text(t, encoding="utf-8")
print("holo_card_v2 wired")