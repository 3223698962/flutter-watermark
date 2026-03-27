import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

// 条件导入：默认使用IO实现，如果是web则使用web实现
// 注意：先导入IO版本，如果html库可用则覆盖为web版本
import 'platform_utils_io.dart' if (dart.library.html) 'platform_utils_web.dart';

/// 检查是否是Web平台
bool get isWeb => kIsWeb;

/// 保存文件到 Download 目录
Future<String?> saveImage(Uint8List bytes, String filename) async {
  return saveImageImpl(bytes, filename);
}

/// 下载文件
void downloadBytes(Uint8List bytes, String filename) {
  downloadBytesImpl(bytes, filename);
}