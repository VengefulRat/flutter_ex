import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  // Replace with your actual GitHub username and repo name
  static const String _repoOwner = 'VengefulRat';
  static const String _repoName = 'flutter_ex';

    // In update_service.dart, replace the checkForUpdates method with this:

  static Future<void> checkForUpdates(BuildContext context) async {
    print('--- 🚀 STARTING UPDATE CHECK ---');
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      print('📱 CURRENT APP VERSION: $currentVersion');

      // Fetch the LIST of releases instead of just the latest
      final url = Uri.parse('https://api.github.com/repos/$_repoOwner/$_repoName/releases');
      print('🌐 FETCHING URL: $url');
      
      final response = await http.get(url);
      print('📡 STATUS CODE: ${response.statusCode}');

      if (response.statusCode != 200) {
        print('❌ FAILED TO FETCH FROM GITHUB. Body: ${response.body}');
        return;
      }

      final List<dynamic> releases = jsonDecode(response.body);
      if (releases.isEmpty) {
        print('❌ NO RELEASES FOUND ON GITHUB.');
        return;
      }

      // Find the first release that is NOT a draft and NOT a prerelease
      final latestRelease = releases.firstWhere(
        (r) => r['draft'] == false && r['prerelease'] == false,
        orElse: () => null,
      );

      if (latestRelease == null) {
        print('❌ NO PUBLISHED RELEASES FOUND (They might all be drafts/pre-releases).');
        return;
      }

      final latestTag = latestRelease['tag_name'] as String? ?? ''; 
      final downloadUrl = latestRelease['html_url'] as String? ?? ''; 
      
      final latestVersion = latestTag.replaceAll('v', '');
      print('🏷️ LATEST GITHUB VERSION: $latestVersion');

      final needsUpdate = _isNewerVersion(currentVersion, latestVersion);
      print('🤔 NEEDS UPDATE? $needsUpdate');

      if (needsUpdate) {
        final prefs = await SharedPreferences.getInstance();
        final dismissedVersion = prefs.getString('dismissed_update_version');
        print('🙈 DISMISSED VERSION: $dismissedVersion');
        
        if (dismissedVersion == latestVersion) {
          print('⏭️ User already dismissed this version.');
          return; 
        }

        if (!context.mounted) {
          print('⚠️ CONTEXT NOT MOUNTED. CANNOT SHOW DIALOG.');
          return;
        }
        print('✅ SHOWING UPDATE DIALOG NOW');
        _showUpdateDialog(context, latestVersion, downloadUrl);
      }
    } catch (e) {
      print('💥 UPDATE CHECK FAILED WITH ERROR: $e');
    }
  }

    static bool _isNewerVersion(String current, String latest) {
    final currParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final lastParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final c = i < currParts.length ? currParts[i] : 0;
      final l = i < lastParts.length ? lastParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  static void _showUpdateDialog(BuildContext context, String newVersion, String downloadUrl) {
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
                style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cGold, letterSpacing: 4),
              ),
              const SizedBox(height: 12),
              Text(
                'A new version of Lore (v$newVersion) is out! Update now to get the latest features and fixes.',
                style: const TextStyle(fontSize: 13, color: cMist, fontStyle: FontStyle.italic, height: 1.7),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('dismissed_update_version', newVersion);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(border: Border.all(color: cAsh)),
                        child: const Center(child: Text('Later', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cSmoke, letterSpacing: 2))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        final uri = Uri.parse(downloadUrl);
                        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                          debugPrint('Could not open download link');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: cGold,
                        child: const Center(child: Text('Update Now', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cVoid, letterSpacing: 1))),
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
}