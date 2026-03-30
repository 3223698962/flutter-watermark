import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // 智能识别平台，自动切换API地址
  static String get baseUrl {
    if (kIsWeb) {
      // Web端使用localhost
      return 'http://localhost:8000/api';
    } else {
      // Android模拟器使用10.0.2.2
      // 真机需要使用电脑IP地址
      return 'http://10.0.2.2:8000/api';
    }
  }

  static String? _customBaseUrl;
  static const String _prefKey = 'server_url';

  /// 加载保存的服务器地址
  static Future<void> loadSavedUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && saved.isNotEmpty) {
        _customBaseUrl = '$saved/api';
      }
    } catch (e) {
      // 忽略错误
    }
  }

  /// 设置自定义服务器地址
  static Future<void> setBaseUrl(String url) async {
    _customBaseUrl = url.isNotEmpty ? '$url/api' : null;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (url.isNotEmpty) {
        await prefs.setString(_prefKey, url);
      } else {
        await prefs.remove(_prefKey);
      }
    } catch (e) {
      // 忽略错误
    }
  }

  /// 获取当前保存的服务器地址（不带/api）
  static Future<String?> getSavedUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefKey);
    } catch (e) {
      return null;
    }
  }

  static String get _effectiveBaseUrl => _customBaseUrl ?? baseUrl;

  /// 文本水印嵌入
  static Future<Map<String, dynamic>> embedTextWatermark(
    String text,
    String watermark,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_effectiveBaseUrl/text/embed'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'watermark': watermark,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(error['detail'] ?? '水印嵌入失败');
      }
    } catch (e) {
      throw Exception('网络错误: $e');
    }
  }

  /// 文本水印提取
  static Future<Map<String, dynamic>> extractTextWatermark(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$_effectiveBaseUrl/text/extract'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(error['detail'] ?? '水印提取失败');
      }
    } catch (e) {
      throw Exception('网络错误: $e');
    }
  }

  /// 文本水印移除
  static Future<Map<String, dynamic>> removeTextWatermark(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$_effectiveBaseUrl/text/remove'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(error['detail'] ?? '水印移除失败');
      }
    } catch (e) {
      throw Exception('网络错误: $e');
    }
  }

  /// 图像水印嵌入
  static Future<Uint8List> embedImageWatermark(
    Uint8List imageBytes,
    String watermark,
    String filename, {
    String algorithm = 'LSB',
    double? strength,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_effectiveBaseUrl/image/embed'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: filename,
        ),
      );
      request.fields['watermark'] = watermark;
      request.fields['algorithm'] = algorithm;
      if (strength != null) {
        request.fields['strength'] = strength.toString();
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        final body = utf8.decode(response.bodyBytes);
        try {
          final error = jsonDecode(body);
          throw Exception(error['detail'] ?? '图像水印嵌入失败');
        } catch (_) {
          throw Exception('请求失败 (${response.statusCode})');
        }
      }
    } catch (e) {
      throw Exception('网络错误: $e');
    }
  }

  /// 图像水印嵌入（带记录信息）
  static Future<Map<String, dynamic>> embedImageWatermarkWithInfo(
    Uint8List imageBytes,
    String watermark,
    String filename, {
    String algorithm = 'LSB',
    double? strength,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_effectiveBaseUrl/image/embed'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: filename,
        ),
      );
      request.fields['watermark'] = watermark;
      request.fields['algorithm'] = algorithm;
      if (strength != null) {
        request.fields['strength'] = strength.toString();
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final headers = response.headers;
        // 解析previousInfo
        Map<String, dynamic>? previousInfo;
        final previousInfoStr = headers['x-previous-info'];
        if (previousInfoStr != null && previousInfoStr.isNotEmpty) {
          try {
            previousInfo = jsonDecode(previousInfoStr);
          } catch (_) {}
        }
        return {
          'imageBytes': response.bodyBytes,
          'imageHash': headers['x-image-hash'],
          'isKnown': headers['x-image-known'] == 'true',
          'watermarkHash': headers['x-watermark-hash'],
          'algorithm': headers['x-watermark-algorithm'],
          'strength': headers['x-watermark-strength'],
          'previousInfo': previousInfo,
        };
      } else {
        final body = utf8.decode(response.bodyBytes);
        try {
          final error = jsonDecode(body);
          throw Exception(error['detail'] ?? '图像水印嵌入失败');
        } catch (_) {
          throw Exception('请求失败 (${response.statusCode})');
        }
      }
    } catch (e) {
      throw Exception('网络错误: $e');
    }
  }

  /// 图像水印提取
  static Future<Map<String, dynamic>> extractImageWatermark(
    Uint8List imageBytes,
    String filename, {
    String algorithm = 'LSB',
    double? strength,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_effectiveBaseUrl/image/extract'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: filename,
        ),
      );
      request.fields['algorithm'] = algorithm;
      if (strength != null) {
        request.fields['strength'] = strength.toString();
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        final body = utf8.decode(response.bodyBytes);
        try {
          final error = jsonDecode(body);
          throw Exception(error['detail'] ?? '图像水印提取失败');
        } catch (_) {
          throw Exception('请求失败 (${response.statusCode})');
        }
      }
    } catch (e) {
      throw Exception('网络错误: $e');
    }
  }

  /// 获取支持的图像水印算法
  static Future<Map<String, dynamic>> getImageAlgorithms() async {
    try {
      final response = await http
          .get(Uri.parse('$_effectiveBaseUrl/image/algorithms'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {'algorithms': ['LSB', 'DCT', 'DWT']};
    } catch (e) {
      return {
        'algorithms': ['LSB', 'DCT', 'DWT'],
        'descriptions': {
          'LSB': '最低有效位替换 - 简单高效',
          'DCT': '离散余弦变换 - 抗JPEG压缩',
          'DWT': '离散小波变换 - 多分辨率',
        }
      };
    }
  }

  /// 检查服务器连接
  static Future<bool> checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse(_effectiveBaseUrl.replaceAll('/api', '')))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}