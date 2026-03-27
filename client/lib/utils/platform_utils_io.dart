// IO平台实现（Android, iOS, Desktop）
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';

Future<String?> saveImageImpl(Uint8List bytes, String filename) async {
  try {
    if (Platform.isAndroid || Platform.isIOS) {
      // Android/iOS: 保存到系统相册
      // 先保存到临时文件，再导入相册（不指定album，避免Android重新编码）
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$filename');
      await tempFile.writeAsBytes(bytes);
      // 直接保存到相册，不指定album以避免Android重新编码
      await Gal.putImage(tempFile.path);
      return '已保存到相册';
    } else {
      // Desktop: 使用应用文档目录
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/$filename');
      await file.writeAsBytes(bytes);
      return file.path;
    }
  } catch (e) {
    return null;
  }
}

void downloadBytesImpl(Uint8List bytes, String filename) {
  // IO平台不使用此方法
}