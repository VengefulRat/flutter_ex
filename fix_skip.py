import pathlib
p = pathlib.Path("lib/services/update_service.dart")
t = p.read_text(encoding="utf-8")

start = t.find("                            'Update Now',")
assert start != -1, "Update Now not found"
# End = the Row close + Column children close after the broken block
end_marker = "                ],\n              ),\n            ],"
end = t.find(end_marker, start)
assert end != -1, "Row/Column close not found"
end += len(end_marker)

correct = """                            'Update Now',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              color: cVoid,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: GestureDetector(
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('dismissed_update_version', newVersion);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text(
                    'Skip this version',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      color: cSmoke,
                      letterSpacing: 2,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],"""

t = t[:start] + correct + t[end:]
p.write_text(t, encoding="utf-8")
print("Skip link fixed")
