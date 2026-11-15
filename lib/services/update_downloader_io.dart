import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

Future<void> downloadAndInstall(String url, void Function(double progress) onProgress) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/lore_update.apk');
  if (await file.exists()) await file.delete();

  final request = http.Request('GET', Uri.parse(url));
  final response = await http.Client().send(request);
  final total = response.contentLength ?? 0;
  var received = 0;

  final sink = file.openWrite();
  await for (final chunk in response.stream) {
    sink.add(chunk);
    received += chunk.length;
    if (total > 0) onProgress(received / total);
  }
  await sink.close();

  await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
}