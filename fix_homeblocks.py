import pathlib
p = pathlib.Path("lib/main.dart")
t = p.read_text(encoding="utf-8")

# Replace reorder helper + _buildHomeBlocks with Column + up/down version
start = t.index("  Future<void> _onReorderHomeBlocks")
end = t.index("  List<FloatingMenuItem> _buildMenuItems() {", start)
new = '''  Future<void> _moveHomeBlock(int index, int delta) async {
    final visible = _orderedMenuItems();
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= visible.length) return;
    final item = visible.removeAt(index);
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
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++)
            Container(
              key: ValueKey(items[i].blockKey),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: appSettings.surfaceColor,
                border: Border.all(color: cAsh, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                child: Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => _moveHomeBlock(i, -1),
                          child: Icon(
                            Icons.keyboard_arrow_up,
                            size: 18,
                            color: i == 0 ? cAsh : cSmoke,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _moveHomeBlock(i, 1),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: i == items.length - 1 ? cAsh : cSmoke,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Icon(items[i].icon, size: 18, color: items[i].accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LoreTap(
                        onTap: items[i].onTap,
                        onLongPress: items[i].onLongPress,
                        child: Text(
                          items[i].label,
                          style: const TextStyle(
                            fontSize: 14,
                            color: cMist,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ),
                    if (items[i].badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: cGold),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${items[i].badge}',
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
        ],
      ),
    );
  }

'''
t = t[:start] + new + t[end:]
p.write_text(t, encoding="utf-8")
print("home blocks fixed - Column, no ReorderableListView")