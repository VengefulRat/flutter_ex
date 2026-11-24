import pathlib, re

p = pathlib.Path("lib/screens/rp_room.dart")
lines = p.read_text(encoding="utf-8").splitlines()

current_class = "???"
for i, line in enumerate(lines, 1):
    m = re.search(r"class\s+(\w+)", line)
    if m:
        current_class = m.group(1)
    if "void initState()" in line:
        print(f"Lyn {i}: initState in klas {current_class}")
    if "_loadChapters().then" in line:
        print(f"  -> Lyn {i}: _loadChapters CALL in klas {current_class}: {line.strip()}")