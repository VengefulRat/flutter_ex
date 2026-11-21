import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';

Future<void> downloadAndInstall(
  String url,
  void Function(double progress) onProgress,
) async {
  debugPrint('DOWNLOADER: starting $url');

  // Windows: use %TEMP%, not Documents / ExternalStorage (Android-only).
  // The installer needs to replace the running exe, so we must exit after launching it.
  final fileName = Uri.parse(url).pathSegments.isNotEmpty
      ? Uri.parse(url).pathSegments.last
      : 'LoreEx-Setup.exe';

  final dir = Platform.isWindows
      ? Directory.systemTemp.createTempSync('lore_update_')
      : Directory.systemTemp;
  final file = File('${dir.path}/$fileName');
  debugPrint('DOWNLOADER: saving to ${file.path}');

  if (await file.exists()) {
    await file.delete();
  }

  final request = http.Request('GET', Uri.parse(url));
  final response = await http.Client().send(request);
  if (response.statusCode != 200) {
    throw Exception('Download failed: HTTP ${response.statusCode}');
  }

  final total = response.contentLength ?? -1;
  var received = 0;
  final sink = file.openWrite();
  await for (final chunk in response.stream) {
    received += chunk.length;
    sink.add(chunk);
    if (total > 0) onProgress(received / total);
  }
  await sink.close();
  onProgress(1.0);

  debugPrint('DOWNLOADER: saved ${await file.length()} bytes, exists=${await file.exists()}');

  if (Platform.isWindows) {
    // Inno Setup will prompt for admin itself (PrivilegesRequired=admin in lore_ex.iss).
    // Launch detached, then exit so the installer can overwrite the running exe.
    await Process.start(
      file.path,
      [],
      mode: ProcessStartMode.detached,
    );
    debugPrint('DOWNLOADER: installer launched, exiting app');
    // Small delay so the detached process actually spawns before we exit.
    await Future.delayed(const Duration(milliseconds: 500));
    exit(0);
  }

  // Android: keep existing behaviour.
  final result = await OpenFilex.open(
    file.path,
    type: 'application/vnd.android.package-archive',
  );
  debugPrint('DOWNLOADER: OpenFilex result type=${result.type} message=${result.message}');

  if (result.type != ResultType.done) {
    throw Exception('Could not open installer: ${result.message}');
  }
}