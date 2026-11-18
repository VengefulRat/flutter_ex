import pathlib

# --- 1. LoreTopBar: read showLogo / logoText ---
p = pathlib.Path("lib/widgets/shared.dart")
t = p.read_text(encoding="utf-8")
old_import = "import '../theme.dart';"
assert old_import in t
if "settings.dart" not in t:
    t = t.replace(old_import, old_import + "\nimport '../settings.dart';", 1)

old_logo = """      GestureDetector(
        onTap: onLogoTap,
        child: const Text('L o r e', style: TextStyle(fontSize: 13,
            color: cGold, letterSpacing: 6, fontWeight: FontWeight.w300)),
      ),"""
assert old_logo in t, "LoreTopBar logo not found"
new_logo = """      GestureDetector(
        onTap: onLogoTap,
        child: appSettings.showLogo
            ? Text(
                appSettings.logoText.split('').join(' '),
                style: const TextStyle(
                  fontSize: 13,
                  color: cGold,
                  letterSpacing: 6,
                  fontWeight: FontWeight.w300,
                ),
              )
            : const SizedBox.shrink(),
      ),"""
t = t.replace(old_logo, new_logo, 1)
p.write_text(t, encoding="utf-8")
print("LoreTopBar wired")

# --- 2. main.dart: landing logo + floating OFF -> home blocks ---
p = pathlib.Path("lib/main.dart")
t = p.read_text(encoding="utf-8")

# 2a. Landing logo: hide if showLogo off, else spaced logoText
old_landing = """                        const Text(
                          'L o r e',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                            color: cGold,
                            letterSpacing: 8,
                          ),
                        ),"""
assert old_landing in t, "landing logo not found"
new_landing = """                        if (appSettings.showLogo)
                          Text(
                            appSettings.logoText.split('').join(' '),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                              color: cGold,
                              letterSpacing: 8,
                            ),
                          ),"""
t = t.replace(old_landing, new_landing, 1)

# 2b. Hide floating button when OFF
old_btn = "            FloatingMenuButton(items: _buildMenuItems()),"
assert old_btn in t, "floating button not found"
t = t.replace(
    old_btn,
    "            if (appSettings.showFloatingButton)\n              FloatingMenuButton(items: _buildMenuItems()),",
    1,
)

# 2c. Insert home blocks between Profile Card and Floating Bottom Bar
anchor = "// ── FLOATING BOTTOM BAR ──"
idx = t.index(anchor)
line_start = t.rfind("\n", 0, idx) + 1
home_blocks_call = """                          if (!appSettings.showFloatingButton)
                            _buildHomeBlocks(),
                          const SizedBox(height: 16),
"""
t = t[:line_start] + home_blocks_call + t[line_start:]

# 2d. Helpers before _buildMenuItems
anchor2 = "  List<FloatingMenuItem> _buildMenuItems() {"
assert anchor2 in t
helpers = '''  List<FloatingMenuItem> _orderedMenuItems() {
    final items = _buildMenuItems();
    // Hide hidden blocks
    final visible = items.where((it) => !appSettings.isBlockHidden(it.blockKey)).toList();
    // Order by saved homeOrder, unknown keys keep their original order at the end
    final order = appSettings.homeOrder;
    if (order.isEmpty) return visible;
    visible.sort((a, b) {
      final ia = order.indexOf(a.blockKey);
      final ib = order.indexOf(b.blockKey);
      if (ia == -1 && ib == -1) return 0;
      if (ia == -1) return 1;
      if (ib == -1) return -1;
      return ia.compareTo(ib);
    });
    return visible;
  }

  Future<void> _onReorderHomeBlocks(int oldIndex, int newIndex) async {
    final visible = _orderedMenuItems();
    if (newIndex > oldIndex) newIndex -= 1;
    final item = visible.removeAt(oldIndex);
    visible.insert(newIndex, item);
    await appSettings.setHomeOrder(visible.map((e) => e.blockKey).toList());
    if (mounted) setState(() {});
  }

  Widget _buildHomeBlocks() {
    final items = _orderedMenuItems();
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          'All blocks hidden. Turn them back on in Settings > Customize layout.',
          style: TextStyle(fontSize: 12, color: cSmoke, fontStyle: FontStyle.italic),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        onReorder: (o, n) => _onReorderHomeBlocks(o, n),
        itemBuilder: (context, i) {
          final it = items[i];
          return Container(
            key: ValueKey(it.blockKey),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: appSettings.surfaceColor,
              border: Border.all(color: cAsh, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: LoreTap(
              onTap: it.onTap,
              onLongPress: it.onLongPress,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                child: Row(
                  children: [
                    Icon(Icons.drag_handle, size: 16, color: cSmoke),
                    const SizedBox(width: 10),
                    Icon(it.icon, size: 18, color: it.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        it.label,
                        style: const TextStyle(
                          fontSize: 14,
                          color: cMist,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                    if (it.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: cGold),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${it.badge}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: cGold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, size: 16, color: cSmoke),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

'''
t = t.replace(anchor2, helpers + anchor2, 1)
p.write_text(t, encoding="utf-8")
print("main.dart wired")

# --- 3. CustomizeScreen: use real blockKeys, not fake ids ---
p = pathlib.Path("lib/screens/customize_screen.dart")
t = p.read_text(encoding="utf-8")
old_ids = """  static List<String> _blockIds() {
    final ids = <String>{};
    try {
      ids.addAll(appSettings.homeOrder);
    } catch (_) {}
    if (ids.isEmpty) {
      ids.addAll(['profile', 'continue', 'worlds', 'characters', 'posts']);
    }
    return ids.toList();
  }

  static String _blockLabel(String id) {
    if (id.isEmpty) return id;
    final s = id.replaceAll('_', ' ');
    return s[0].toUpperCase() + s.substring(1);
  }"""
assert old_ids in t, "customize _blockIds not found"
new_ids = """  static List<MapEntry<String, String>> _blockIds() {
    return [
      MapEntry(AppSettings.blockNotifications, 'Notifications'),
      MapEntry(AppSettings.blockRoleplays, 'Roleplays'),
      MapEntry(AppSettings.blockBrainstorms, 'Preludes'),
      MapEntry(AppSettings.blockRequestCard, 'Request Card'),
      MapEntry(AppSettings.blockSettings, 'Settings'),
    ];
  }"""
t = t.replace(old_ids, new_ids, 1)
# Update the usage: ..._blockIds().map((id) { -> ..._blockIds().map((e) {
old_use = """                      ..._blockIds().map((id) {
                        final hidden = appSettings.isBlockHidden(id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _onOffRow(
                            label: _blockLabel(id),
                            value: !hidden,
                            onLabel: 'SHOW',
                            offLabel: 'HIDE',
                            onChanged: (v) => appSettings.setBlockHidden(id, !v),
                          ),
                        );
                      }),"""
assert old_use in t, "customize blocks usage not found"
new_use = """                      ..._blockIds().map((e) {
                        final hidden = appSettings.isBlockHidden(e.key);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _onOffRow(
                            label: e.value,
                            value: !hidden,
                            onLabel: 'SHOW',
                            offLabel: 'HIDE',
                            onChanged: (v) => appSettings.setBlockHidden(e.key, !v),
                          ),
                        );
                      }),"""
t = t.replace(old_use, new_use, 1)
p.write_text(t, encoding="utf-8")
print("customize_screen fixed")