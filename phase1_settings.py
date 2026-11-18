import pathlib
p = pathlib.Path("lib/settings.dart")
t = p.read_text(encoding="utf-8")

def replace_once(old, new):
    global t
    assert old in t, f"NOT FOUND: {old[:80]}"
    assert t.count(old) == 1, f"NOT UNIQUE: {old[:80]}"
    t = t.replace(old, new, 1)

# 1. Prefs keys - after _kProfileGlowColor
replace_once(
    "  static const _kProfileGlowColor = 'as_profile_glow_color';",
    """  static const _kProfileGlowColor = 'as_profile_glow_color';
  static const _kShowLogo = 'as_show_logo';
  static const _kLogoText = 'as_logo_text';
  static const _kShowFloatingButton = 'as_show_fab';
  static const _kGyroEnabled = 'as_gyro_enabled';
  static const _kFloatingMenuColor = 'as_floating_menu_color';
  static const _kHiddenBlocks = 'as_hidden_blocks';"""
)

# 2. Fields - after _profileGlowColor field
replace_once(
    "  Color _profileGlowColor = Colors.black;",
    """  Color _profileGlowColor = Colors.black;
  // Phase 1 - Level 2 customization
  bool _showLogo = true;
  String _logoText = 'LORE';
  bool _showFloatingButton = true;
  bool _gyroEnabled = true;
  Color _floatingMenuColor = const Color(0xFFC9A96E);
  Set<String> _hiddenBlocks = {};"""
)

# 3. Getters + setters - after setProfileGlowColor method
old_setter = """  Future<void> setProfileGlowColor(Color v) async {
    _profileGlowColor = v;
    (await SharedPreferences.getInstance()).setInt(
      _kProfileGlowColor,
      v.toARGB32(),
    );
    _touch();
    notifyListeners();
  }"""
assert old_setter in t
t = t.replace(old_setter, old_setter + """

  // --- Phase 1: Level 2 customization ---
  bool get showLogo => _showLogo;
  String get logoText => _logoText;
  bool get showFloatingButton => _showFloatingButton;
  bool get gyroEnabled => _gyroEnabled;
  Color get floatingMenuColor => _floatingMenuColor;
  Set<String> get hiddenBlocks => Set.unmodifiable(_hiddenBlocks);
  bool isBlockHidden(String id) => _hiddenBlocks.contains(id);

  Future<void> setShowLogo(bool v) async {
    _showLogo = v;
    (await SharedPreferences.getInstance()).setBool(_kShowLogo, v);
    _touch();
    notifyListeners();
  }

  Future<void> setLogoText(String v) async {
    _logoText = v;
    (await SharedPreferences.getInstance()).setString(_kLogoText, v);
    _touch();
    notifyListeners();
  }

  Future<void> setShowFloatingButton(bool v) async {
    _showFloatingButton = v;
    (await SharedPreferences.getInstance()).setBool(_kShowFloatingButton, v);
    _touch();
    notifyListeners();
  }

  Future<void> setGyroEnabled(bool v) async {
    _gyroEnabled = v;
    (await SharedPreferences.getInstance()).setBool(_kGyroEnabled, v);
    _touch();
    notifyListeners();
  }

  Future<void> setFloatingMenuColor(Color v) async {
    _floatingMenuColor = v;
    (await SharedPreferences.getInstance()).setInt(_kFloatingMenuColor, v.toARGB32());
    _touch();
    notifyListeners();
  }

  Future<void> setBlockHidden(String id, bool hidden) async {
    if (hidden) {
      _hiddenBlocks.add(id);
    } else {
      _hiddenBlocks.remove(id);
    }
    (await SharedPreferences.getInstance()).setStringList(_kHiddenBlocks, _hiddenBlocks.toList());
    _touch();
    notifyListeners();
  }
""", 1)

# 4. Cloud serialize - after profileGlowColor line
replace_once(
    "    'profileGlowColor': _profileGlowColor.toARGB32(),",
    """    'profileGlowColor': _profileGlowColor.toARGB32(),
    'showLogo': _showLogo,
    'logoText': _logoText,
    'showFloatingButton': _showFloatingButton,
    'gyroEnabled': _gyroEnabled,
    'floatingMenuColor': _floatingMenuColor.toARGB32(),
    'hiddenBlocks': _hiddenBlocks.toList(),"""
)

# 5. Cloud apply - after _profileGlowEnabled apply block
replace_once(
    """    _profileGlowEnabled =
        j['profileGlowEnabled'] as bool? ?? _profileGlowEnabled;""",
    """    _profileGlowEnabled =
        j['profileGlowEnabled'] as bool? ?? _profileGlowEnabled;
    _showLogo = j['showLogo'] as bool? ?? _showLogo;
    _logoText = j['logoText'] as String? ?? _logoText;
    _showFloatingButton = j['showFloatingButton'] as bool? ?? _showFloatingButton;
    _gyroEnabled = j['gyroEnabled'] as bool? ?? _gyroEnabled;
    if (j['floatingMenuColor'] is int) {
      _floatingMenuColor = Color(j['floatingMenuColor'] as int);
    }
    if (j['hiddenBlocks'] is List) {
      _hiddenBlocks = Set<String>.from((j['hiddenBlocks'] as List).map((e) => e.toString()));
    }"""
)

# 6. Prefs load - after savedGlowColor handling (if present, else skip)
# The load block looks like: if (savedGlowColor != null) _profileGlowColor = ...
# We add our loads right after the _profileGlowColor prefs line in _saveAllToPrefs/load area
# Try prefs-load anchor first
try:
    replace_once(
        "    await p.setInt(_kProfileGlowColor, _profileGlowColor.toARGB32());",
        """    await p.setInt(_kProfileGlowColor, _profileGlowColor.toARGB32());
    await p.setBool(_kShowLogo, _showLogo);
    await p.setString(_kLogoText, _logoText);
    await p.setBool(_kShowFloatingButton, _showFloatingButton);
    await p.setBool(_kGyroEnabled, _gyroEnabled);
    await p.setInt(_kFloatingMenuColor, _floatingMenuColor.toARGB32());
    await p.setStringList(_kHiddenBlocks, _hiddenBlocks.toList());"""
    )
    print("prefs-save patched")
except AssertionError as e:
    print("prefs-save anchor not found, skipping:", e)

p.write_text(t, encoding="utf-8")
print("Phase 1 settings patched OK")