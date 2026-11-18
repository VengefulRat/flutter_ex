import pathlib
p = pathlib.Path("lib/screens/customize_screen.dart")
t = p.read_text(encoding="utf-8")

# 1. chip calls: label: -> text:
t = t.replace(
    "chip(label: onLabel, active: value, onTap: () => onChanged(true)),",
    "chip(text: onLabel, active: value, onTap: () => onChanged(true)),",
    1,
)
t = t.replace(
    "chip(label: offLabel, active: !value, onTap: () => onChanged(false)),",
    "chip(text: offLabel, active: !value, onTap: () => onChanged(false)),",
    1,
)

# 2. LoreColourPicker gives non-null Color - drop the null check
t = t.replace(
    """                              onPicked: (c) {
                                if (c != null) appSettings.setFloatingMenuColor(c);
                              },""",
    """                              onPicked: (c) => appSettings.setFloatingMenuColor(c),""",
    1,
)

p.write_text(t, encoding="utf-8")
print("fixed")