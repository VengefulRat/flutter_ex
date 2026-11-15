import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import 'update_downloader_stub.dart'
    if (dart.library.io) 'update_downloader_io.dart' as downloader;

class UpdateService {
  static const String _repoOwner = 'VengefulRat';
  static const String _repoName = 'flutter_ex';

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      debugPrint('UPDATE CHECK: current=$currentVersion');

      final url = Uri.parse(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases',
      );

      final response =
          await http.get(url).timeout(const Duration(seconds: 10));
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
      final latestVersion = latestTag.replaceAll('v', '');
      debugPrint('UPDATE CHECK: latest=$latestVersion');

      if (!_isNewerVersion(currentVersion, latestVersion)) return;

      final prefs = await SharedPreferences.getInstance();
      final dismissedVersion = prefs.getString('dismissed_update_version');
      if (dismissedVersion == latestVersion) return;

      if (!context.mounted) return;
      _showUpdateDialog(context, latestVersion, latestTag);
    } catch (e) {
      debugPrint('UPDATE CHECK FAILED: $e');
    }
  }

  static bool _isNewerVersion(String current, String latest) {
    final currParts =
        current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final lastParts =
        latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final c = i < currParts.length ? currParts[i] : 0;
      final l = i < lastParts.length ? lastParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  static void _showUpdateDialog(
    BuildContext context,
    String newVersion,
    String tag,
  ) {
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
                'A new version of Lore (v$newVersion) is out! Update now to get the latest features and fixes.',
                style: const TextStyle(
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
                      onTap: () async {
                        final prefs =
                            await SharedPreferences.getInstance();
                        await prefs.setString(
                          'dismissed_update_version',
                          newVersion,
                        );
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
                      onTap: () {
                        Navigator.pop(ctx);
                        _downloadAndInstall(context, tag);
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
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _downloadAndInstall(
    BuildContext context,
    String tag,
  ) async {
    final apkUrl =
        'https://github.com/$_repoOwner/$_repoName/releases/download/$tag/flutter_ex-releases.apk';

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
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(cGold),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await downloader.downloadAndInstall(
        apkUrl,
        (p) => progress.value = p,
      );
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: cInk,
          ),
        );
      }
    } finally {
      progress.dispose();
    }
  }
}