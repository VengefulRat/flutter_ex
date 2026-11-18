import pathlib
p = pathlib.Path("lib/services/update_service.dart")
t = p.read_text(encoding="utf-8")

# 1. Pull body + asset size from the release, pass to dialog
old = """      if (!context.mounted) return;
      _showUpdateDialog(context, latestVersion, latestTag);"""
assert old in t, "checkForUpdates dialog call not found"
new = """      final changelog = (latestRelease['body'] as String?) ?? '';
      int? apkSize;
      final assets = latestRelease['assets'] as List<dynamic>?;
      if (assets != null && assets.isNotEmpty) {
        apkSize = (assets.first['size'] as num?)?.toInt();
      }

      if (!context.mounted) return;
      _showUpdateDialog(context, latestVersion, latestTag, changelog, apkSize);"""
t = t.replace(old, new, 1)

# 2. New dialog signature + changelog parsing + size
old = """  static void _showUpdateDialog(
    BuildContext context,
    String newVersion,
    String tag,
  ) {"""
assert old in t, "_showUpdateDialog signature not found"
new = """  static List<String> _parseChangelog(String body) {
    final lines = <String>[];
    for (final raw in body.split('\\n')) {
      var line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#')) {
        line = line.replaceAll(RegExp(r'^#+\\s*'), '').trim();
        if (line.isEmpty) continue;
        lines.add('__HEADER__$line');
        continue;
      }
      line = line.replaceAll(RegExp(r'^[-*•]\\s*'), '').trim();
      line = line.replaceAll(RegExp(r'\\*\\*(.+?)\\*\\*'), r'$1');
      line = line.replaceAll('`', '');
      if (line.isEmpty) continue;
      lines.add(line);
    }
    return lines;
  }

  static String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024 * 1024) return ' • ${(bytes / 1024).toStringAsFixed(0)} KB';
    return ' • ${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }

  static void _showUpdateDialog(
    BuildContext context,
    String newVersion,
    String tag,
    String changelog,
    int? apkSize,
  ) {
    final items = _parseChangelog(changelog);"""
t = t.replace(old, new, 1)

# 3. Replace generic body text with version + size + changelog list
old = """              Text(
                'A new version of Lore (v$newVersion) is out! Update now to get the latest features and fixes.',
                style: const TextStyle(
                  fontSize: 13,
                  color: cMist,
                  fontStyle: FontStyle.italic,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 24),"""
assert old in t, "dialog body text not found"
new = """              Text(
                'Lore v$newVersion is out${_formatSize(apkSize)}. What\\'s new:',
                style: const TextStyle(
                  fontSize: 13,
                  color: cMist,
                  fontStyle: FontStyle.italic,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 12),
              if (items.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    border: Border.all(color: cAsh),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: items.map((item) {
                        if (item.startsWith('__HEADER__')) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Text(
                              item.replaceFirst('__HEADER__', ''),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                color: cGold,
                                letterSpacing: 2,
                              ),
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('•  ',
                                  style: TextStyle(fontSize: 13, color: cGold)),
                              Expanded(
                                child: Text(
                                  item,
                                  style: const TextStyle(
                                      fontSize: 13, color: cMist, height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                )
              else
                const Text(
                  'Latest features and fixes. Tap Update Now to install.',
                  style: TextStyle(
                      fontSize: 13, color: cMist, fontStyle: FontStyle.italic, height: 1.7),
                ),
              const SizedBox(height: 24),"""
t = t.replace(old, new, 1)

# 4. Later = snooze
old = """                      onTap: () async {
                        final prefs =
                            await SharedPreferences.getInstance();
                        await prefs.setString(
                          'dismissed_update_version',
                          newVersion,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },"""
assert old in t, "Later handler not found"
new = """                      onTap: () {
                        // Later = snooze, show again next open.
                        // Do NOT save dismissed_update_version here.
                        if (ctx.mounted) Navigator.pop(ctx);
                      },"""
t = t.replace(old, new, 1)

# 5. Skip link — FIXED: use last occurrence of Update Now
idx_update = t.rfind("Update Now")
assert idx_update != -1, "Update Now button not found"
# Find the Row close AFTER that: first "              )," after idx_update
idx_close = t.find("              ),", idx_update)
assert idx_close != -1, "Row close not found"
skip = """              ),
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
              """
t = t[:idx_close] + skip + t[idx_close:]

p.write_text(t, encoding="utf-8")
print("update changelog dialog added")