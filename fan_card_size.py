import pathlib

# --- 1. settings.dart: fanCardSize, mirroring floatingMenuColor ---
p = pathlib.Path("lib/settings.dart")
t = p.read_text(encoding="utf-8")

old = "  static const _kFloatingMenuColor = 'as_floating_menu_color';"
assert old in t, "kFloatingMenuColor not found"
t = t.replace(old, old + "\n  static const _kFanCardSize = 'as_fan_card_size';", 1)

old = "  Color _floatingMenuColor = const Color(0xFFC9A96E);"
assert old in t, "floatingMenuColor field not found"
t = t.replace(old, old + "\n  String _fanCardSize = 'normal';", 1)

old = "    'floatingMenuColor': _floatingMenuColor.toARGB32(),"
assert old in t, "toJson floatingMenuColor not found"
t = t.replace(old, old + "\n    'fanCardSize': _fanCardSize,", 1)

old = """    if (j['floatingMenuColor'] is int) {
      _floatingMenuColor = Color(j['floatingMenuColor'] as int);
    }"""
assert old in t, "fromJson floatingMenuColor not found"
t = t.replace(old, old + """
    if (j['fanCardSize'] is String) {
      _fanCardSize = j['fanCardSize'] as String;
    }""", 1)

old = "  Color get floatingMenuColor => _floatingMenuColor;"
assert old in t, "floatingMenuColor getter not found"
t = t.replace(old, old + """
  String get fanCardSize => _fanCardSize;
  double get fanCardSizePx {
    switch (_fanCardSize) {
      case 'small':
        return 64;
      case 'large':
        return 100;
      default:
        return 82;
    }
  }""", 1)

old = "  Future<void> setFloatingMenuColor(Color v) async {"
assert old in t, "setFloatingMenuColor not found"
new_setter = """  Future<void> setFanCardSize(String v) async {
    _fanCardSize = v;
    (await SharedPreferences.getInstance()).setString(_kFanCardSize, v);
    notifyListeners();
  }

"""
t = t.replace(old, new_setter + old, 1)
p.write_text(t, encoding="utf-8")
print("settings: fanCardSize added")

# --- 2. floating_menu.dart: _cardSize from settings, not hard-coded 82 ---
p = pathlib.Path("lib/widgets/floating_menu.dart")
t = p.read_text(encoding="utf-8")
old = "  static const double _cardSize = 82;"
assert old in t, "_cardSize not found"
t = t.replace(old, "  double get _cardSize => appSettings.fanCardSizePx;", 1)
p.write_text(t, encoding="utf-8")
print("floating_menu: _cardSize from settings")

# --- 3. customize_screen.dart: Fan card size chips under Floating menu colour ---
p = pathlib.Path("lib/screens/customize_screen.dart")
t = p.read_text(encoding="utf-8")
old = """                      const SizedBox(height: 24),
                      const Divider(color: cAsh),
                      const SizedBox(height: 16),
                      _section('MOTION'),"""
assert old in t, "MOTION anchor not found"
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

# Helper _fanSizeChip — insert before _section or before _onOffRow helper.
# Find the first helper definition in this file to anchor on.
# Fallback: _section( is used everywhere, so anchor on "Widget _section(" if present,
# otherwise on "_onOffRow(".
if "Widget _fanSizeChip" not in t:
    if "  Widget _section(" in t:
        anchor = "  Widget _section("
        helper = """  Widget _fanSizeChip(String label, String value) {
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
    else:
        raise AssertionError("no _section helper to anchor _fanSizeChip on — paste the bottom of customize_screen.dart")
p.write_text(t, encoding="utf-8")
print("customize: Fan card size chips added")