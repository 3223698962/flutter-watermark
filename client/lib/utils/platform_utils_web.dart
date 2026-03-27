// Web平台实现
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
// ignore: deprecated_member_use
import 'dart:html' as html;

Future<String?> saveImageImpl(Uint8List bytes, String filename) async {
  downloadBytesImpl(bytes, filename);
  return filename;
}

void downloadBytesImpl(Uint8List bytes, String filename) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}