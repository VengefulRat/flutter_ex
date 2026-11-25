import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import 'update_downloader_stub.dart'
    if (dart.library.io) 'update_downloader_io.dart'
    as downloader;

class UpdateService {
  static const String _repoOwner = 'VengefulRat';
  static const String _repoName = 'flutter_ex';

  static Future<void> checkForUpdates(BuildContext context) async {
    final platform = defaultTargetPlatform;
    if (kIsWeb ||
        (platform != TargetPlatform.android &&
            platform != TargetPlatform.windows)) {
      return;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      debugPrint('UPDATE CHECK: current=$currentVersion');

      final url = Uri.parse(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        debugPrint('UPDATE CHECK: GitHub returned ${response.statusCode}');
        return;
      }

      final List<dynamic> releases = jsonDecode(response.body);
      if (releases.isEmpty) return;

      final latestRelease = releases.firstWhere(
        (r) => r['draft'] == false && r['prerelease'] == false,
        orElse: () => null,
      );
      if (latestRelease == null) return;

      final latestTag = latestRelease['tag_name'] as String? ?? '';
      final latestVersion = latestTag.replaceFirst(RegExp(r'^v'), '');
      debugPrint('UPDATE CHECK: latest=$latestVersion');

      if (!_isNewerVersion(currentVersion, latestVersion)) return;

      final prefs = await SharedPreferences.getInstance();
      final dismissedVersion = prefs.getString('dismissed_update_version');
      if (dismissedVersion == latestVersion) return;

      final changelog = (latestRelease['body'] as String?) ?? '';
      final expectedAssetName = platform == TargetPlatform.windows
          ? 'LoreEx-Setup.exe'
          : 'flutter_ex-releases.apk';
      final assets = latestRelease['assets'];
      if (assets is! List) {
        debugPrint('UPDATE CHECK: release has no assets list');
        return;
      }

      final matchingAssets = assets.whereType<Map<String, dynamic>>().where(
        (asset) =>
            (asset['name'] as String?)?.toLowerCase() ==
            expectedAssetName.toLowerCase(),
      );
      if (matchingAssets.isEmpty) {
        debugPrint('UPDATE CHECK: release asset $expectedAssetName not found');
        return;
      }

      final asset = matchingAssets.first;
      final downloadUrl = asset['browser_download_url'];
      final downloadUri = downloadUrl is String
          ? Uri.tryParse(downloadUrl)
          : null;
      if (downloadUri == null ||
          downloadUri.scheme != 'https' ||
          downloadUri.host != 'github.com') {
        debugPrint('UPDATE CHECK: release asset has an invalid download URL');
        return;
      }
      final assetSize = (asset['size'] as num?)?.toInt();

      if (!context.mounted) return;
      _showUpdateDialog(
        context,
        latestVersion,
        changelog,
        assetSize,
        downloadUri.toString(),
      );
    } catch (e) {
      debugPrint('UPDATE CHECK FAILED: $e');
    }
  }

  static bool _isNewerVersion(String current, String latest) {
    final currParts = current
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    final lastParts = latest
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();

    for (int i = 0; i < 3; i++) {
      final c = i < currParts.length ? currParts[i] : 0;
      final l = i < lastParts.length ? lastParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  static List<String> _parseChangelog(String body) {
    final lines = <String>[];
    for (final raw in body.split('\n')) {
      var line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#')) {
        line = line.replaceAll(RegExp(r'^#+\s*'), '').trim();
        if (line.isEmpty) continue;
        lines.add('__HEADER__$line');
        continue;
      }
      line = line.replaceAll(RegExp(r'^[-*•]\s*'), '').trim();
      line = line.replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1');
      line = line.replaceAll('`', '');
      if (line.isEmpty) continue;
      lines.add(line);
    }
    return lines;
  }

  static String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024 * 1024) {
      return ' • ${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return ' • ${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }

  static void _showUpdateDialog(
    BuildContext context,
    String newVersion,
    String changelog,
    int? assetSize,
    String downloadUrl,
  ) {
    final items = _parseChangelog(changelog);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: cInk,
        shape: const RoundedRectangleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'UPDATE AVAILABLE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: cGold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Lore v$newVersion is out${_formatSize(assetSize)}. What\'s new:',
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
                              const Text(
                                '•  ',
                                style: TextStyle(fontSize: 13, color: cGold),
                              ),
                              Expanded(
                                child: Text(
                                  item,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: cMist,
                                    height: 1.5,
                                  ),
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
                    fontSize: 13,
                    color: cMist,
                    fontStyle: FontStyle.italic,
                    height: 1.7,
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // Later = snooze, show again next open.
                        // Do NOT save dismissed_update_version here.
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: cAsh),
                        ),
                        child: const Center(
                          child: Text(
                            'Later',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              color: cSmoke,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        if (defaultTargetPlatform == TargetPlatform.windows) {
                          final confirmed = await showDialog<bool>(
                            context: ctx,
                            builder: (_) => const WindowsInstallerWarning(),
                          );
                          if (confirmed != true || !ctx.mounted) return;
                        }
                        Navigator.pop(ctx);
                        _downloadAndInstall(context, downloadUrl);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: cGold,
                        child: const Center(
                          child: Text(
                            'Update Now',
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
                    await prefs.setString(
                      'dismissed_update_version',
                      newVersion,
                    );
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
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _downloadAndInstall(
    BuildContext context,
    String downloadUrl,
  ) async {
    final progress = ValueNotifier<double>(0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: cInk,
        shape: const RoundedRectangleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, p, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DOWNLOADING UPDATE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: cGold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  p <= 0
                      ? 'Starting download...'
                      : p >= 1
                      ? 'Download complete. Opening installer...'
                      : 'Downloading... ${(p * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 13,
                    color: cMist,
                    fontStyle: FontStyle.italic,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: p <= 0 ? null : p,
                  backgroundColor: cAsh,
                  valueColor: const AlwaysStoppedAnimation<Color>(cGold),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await downloader.downloadAndInstall(
        downloadUrl,
        (p) => progress.value = p,
      );
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: cInk),
        );
      }
    } finally {
      progress.dispose();
    }
  }
}

class WindowsInstallerWarning extends StatelessWidget {
  const WindowsInstallerWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: cInk,
      title: const Text(
        'Unsigned Windows installer',
        style: TextStyle(color: cGold),
      ),
      content: const Text(
        'Only download Lore installers from the official '
        'github.com/VengefulRat/flutter_ex releases. This installer is not '
        'digitally signed, so even an official download cannot be verified '
        'against tampering. Continue only if you accept this risk.',
        style: TextStyle(color: cMist),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Install anyway'),
        ),
      ],
    );
  }
}
