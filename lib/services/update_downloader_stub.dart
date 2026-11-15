import 'package:url_launcher/url_launcher.dart';

Future<void> downloadAndInstall(String url, void Function(double progress) onProgress) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}