import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

Future<void> downloadAndInstall(
  String url,
  void Function(double progress) onProgress,
) async {
  debugPrint('DOWNLOADER: starting $url');

  final dir = await getExternalStorageDirectory() ??
      await getApplicationDocumentsDirectory();
  final fileName = Uri.parse(url).pathSegments.isNotEmpty ? Uri.parse(url).pathSegments.last : 'flutter_ex-releases.apk';
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

  final isWin = Platform.isWindows;
  final result = isWin
      ? await OpenFilex.open(file.path)
      : await OpenFilex.open(
          file.path,
          type: 'application/vnd.android.package-archive',
        );
  debugPrint('DOWNLOADER: OpenFilex result type=${result.type} message=${result.message}');

  if (result.type != ResultType.done) {
    throw Exception('Could not open installer: ${result.message}');
  }
}