import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

void downloadFile(String content, String filename) async {
  final base64Content = base64Encode(utf8.encode(content));
  final uri = Uri.parse('data:application/json;charset=utf-8;base64,$base64Content');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}
