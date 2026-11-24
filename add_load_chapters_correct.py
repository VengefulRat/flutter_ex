import pathlib, re

p = pathlib.Path("lib/screens/rp_room.dart")
t = p.read_text(encoding="utf-8")

assert "_loadChapters().then" not in t, "Daar is al 'n call - moenie 2x run nie"

cls = t.find("class _RPRoomScreenState")
assert cls != -1
after = t[cls:]
m = re.search(r"void initState\(\) \{\s*\n(\s*super\.initState\(\);)", after)
assert m, "NOT FOUND: initState in _RPRoomScreenState"
old = m.group(0)
new = old + "\n    _loadChapters().then((_) { if (mounted) setState(() {}); });"
t = t[:cls] + after.replace(old, new, 1)
p.write_text(t, encoding="utf-8")
print("OK: _loadChapters in _RPRoomScreenState se initState")
print("DONE")