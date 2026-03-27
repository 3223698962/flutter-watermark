import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../utils/platform_utils.dart';

class ImageWatermarkScreen extends StatefulWidget {
  const ImageWatermarkScreen({super.key});

  @override
  State<ImageWatermarkScreen> createState() => _ImageWatermarkScreenState();
}

class _ImageWatermarkScreenState extends State<ImageWatermarkScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _watermarkController = TextEditingController();

  Uint8List? _selectedImageBytes;
  String? _selectedFileName;
  Uint8List? _watermarkedImage;
  String? _extractedWatermark;
  bool _isLoading = false;
  bool _isEmbedMode = true;
  late AnimationController _animationController;

  // 算法选择
  String _selectedAlgorithm = 'DCT';
  final Map<String, String> _algorithmDescriptions = {
    'LSB': '最低有效位',
    'DCT': '离散余弦变换',
    'DWT': '离散小波变换',
  };
  final Map<String, IconData> _algorithmIcons = {
    'LSB': Icons.layers,
    'DCT': Icons.waves,
    'DWT': Icons.grid_on,
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _watermarkController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<bool> _requestStoragePermission() async {
    if (kIsWeb) return true;

    // Android 13+ 使用 photos 权限
    if (await Permission.photos.isGranted) {
      return true;
    }

    // 尝试请求 photos 权限 (Android 13+)
    var status = await Permission.photos.request();
    if (status.isGranted) return true;

    // 回退到 storage 权限 (Android 12及以下)
    status = await Permission.storage.request();
    if (status.isGranted) return true;

    // 最后尝试 manageExternalStorage
    status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedImageBytes = file.bytes;
          _selectedFileName = file.name;
          _watermarkedImage = null;
          _extractedWatermark = null;
        });
      }
    } catch (e) {
      _showSnackBar('选择图片失败: $e');
    }
  }

  Future<void> _embedWatermark() async {
    if (_selectedImageBytes == null) {
      _showSnackBar('请先选择图片');
      return;
    }
    if (_watermarkController.text.isEmpty) {
      _showSnackBar('请输入水印内容');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.embedImageWatermarkWithInfo(
        _selectedImageBytes!,
        _watermarkController.text,
        _selectedFileName ?? 'image.png',
        algorithm: _selectedAlgorithm,
      );

      setState(() {
        _watermarkedImage = result['imageBytes'];
        _selectedImageBytes = result['imageBytes'];
        if (!_selectedFileName!.startsWith('watermarked_')) {
          _selectedFileName = 'watermarked_$_selectedFileName';
        }
        _extractedWatermark = null;
      });

      _animationController.forward(from: 0);

      // 显示图片记录信息
      if (result['isKnown'] == true) {
        _showRecordDialog(
          '图片已有记录',
          '此图片之前已被处理过\n'
          '图片哈希: ${result['imageHash'] ?? '未知'}\n'
          '首次记录: ${result['previousInfo']?['first_seen'] ?? '未知'}\n'
          '已嵌入次数: ${result['previousInfo']?['watermark_count'] ?? 0}',
        );
      } else {
        _showSnackBar('水印嵌入成功！哈希: ${result['imageHash'] ?? '未知'}');
      }
    } catch (e) {
      _showSnackBar('嵌入失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _extractWatermark() async {
    if (_selectedImageBytes == null) {
      _showSnackBar('请先选择图片');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.extractImageWatermark(
        _selectedImageBytes!,
        _selectedFileName ?? 'image.png',
        algorithm: _selectedAlgorithm,
      );

      setState(() {
        _extractedWatermark = result['watermark'];
        _watermarkedImage = null;
      });

      _animationController.forward(from: 0);

      // 显示图片记录信息
      if (result['is_watermarked'] == true && result['record_info'] != null) {
        final info = result['record_info'];
        _showRecordDialog(
          '图片已记录',
          '此图片于 ${info['created'] ?? '未知时间'} 嵌入水印\n'
          '水印内容: ${info['watermark'] ?? '未知'}\n'
          '算法: ${info['algorithm'] ?? '未知'}\n'
          '图片哈希: ${result['image_hash'] ?? '未知'}',
        );
      } else if (result['record_info'] != null) {
        final info = result['record_info'];
        _showSnackBar('图片哈希: ${result['image_hash']} (已嵌入${info['watermark_count'] ?? 0}次水印)');
      } else if (result['success']) {
        _showSnackBar('水印提取成功！哈希: ${result['image_hash']}');
      } else {
        _showSnackBar('${result['message']} (哈希: ${result['image_hash'] ?? '未知'})');
      }
    } catch (e) {
      _showSnackBar('提取失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showRecordDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveImage() async {
    if (_watermarkedImage == null) return;

    if (!await _requestStoragePermission()) {
      _showSnackBar('请授予存储权限');
      return;
    }

    try {
      final fileName = 'watermarked_${_selectedAlgorithm}_${DateTime.now().millisecondsSinceEpoch}.png';

      if (kIsWeb) {
        downloadBytes(_watermarkedImage!, fileName);
        _showSnackBar('图片已下载');
      } else {
        final path = await saveImage(_watermarkedImage!, fileName);
        if (path != null) {
          _showSnackBar('已保存到系统相册');
        } else {
          _showSnackBar('保存失败');
        }
      }
    } catch (e) {
      _showSnackBar('保存失败: $e');
    }
  }

  Future<void> _shareImage() async {
    if (_watermarkedImage == null) return;

    if (kIsWeb) {
      _saveImage();
      return;
    }

    try {
      final fileName = 'watermarked_${DateTime.now().millisecondsSinceEpoch}.png';
      final path = await saveImage(_watermarkedImage!, fileName);
      if (path != null) {
        await Share.shareXFiles([XFile(path)], text: '带水印的图片');
      }
    } catch (e) {
      _showSnackBar('分享失败: $e');
    }
  }

  void _clearAll() {
    _watermarkController.clear();
    setState(() {
      _selectedImageBytes = null;
      _selectedFileName = null;
      _watermarkedImage = null;
      _extractedWatermark = null;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.image,
                size: 20,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            const Text('图像水印'),
          ],
        ),
        actions: [
          if (_selectedImageBytes != null)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearAll,
              tooltip: '清空',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 模式切换
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('嵌入水印'),
                    icon: Icon(Icons.add_circle_outline, size: 18),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('提取水印'),
                    icon: Icon(Icons.search, size: 18),
                  ),
                ],
                selected: {_isEmbedMode},
                onSelectionChanged: (Set<bool> selection) {
                  setState(() {
                    _isEmbedMode = selection.first;
                    _watermarkedImage = null;
                    _extractedWatermark = null;
                    _selectedImageBytes = null;
                    _selectedFileName = null;
                    _watermarkController.clear();
                  });
                },
                style: ButtonStyle(
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 算法选择
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.science,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '水印算法',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: _algorithmDescriptions.keys.map((algo) {
                        final isSelected = _selectedAlgorithm == algo;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: algo != 'DWT' ? 8 : 0,
                            ),
                            child: InkWell(
                              onTap: () => setState(() => _selectedAlgorithm = algo),
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primaryContainer
                                      : Theme.of(context).colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      _algorithmIcons[algo],
                                      size: 24,
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      algo,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Theme.of(context).colorScheme.primary
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _algorithmDescriptions[_selectedAlgorithm]!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 图片选择
            GestureDetector(
              onTap: _pickImage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: _selectedImageBytes == null ? 180 : 220,
                decoration: BoxDecoration(
                  color: _selectedImageBytes == null
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedImageBytes == null
                        ? Theme.of(context).colorScheme.outlineVariant
                        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                    width: _selectedImageBytes == null ? 1 : 2,
                  ),
                ),
                child: _selectedImageBytes == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 40,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '点击选择图片',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '支持 PNG, JPG 格式',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(
                              _selectedImageBytes!,
                              fit: BoxFit.contain,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.edit,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // 水印输入（仅嵌入模式）
            if (_isEmbedMode) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lock,
                            size: 20,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '水印内容',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _watermarkController,
                        decoration: InputDecoration(
                          hintText: '输入要嵌入的水印信息',
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 操作按钮
            FilledButton.icon(
              onPressed: _isLoading ? null : (_isEmbedMode ? _embedWatermark : _extractWatermark),
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_isEmbedMode ? Icons.add_circle_outline : Icons.search),
              label: Text(_isEmbedMode ? '嵌入水印' : '提取水印'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 带水印的图片显示
            if (_watermarkedImage != null) ...[
              FadeTransition(
                opacity: _animationController,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.easeOut,
                  )),
                  child: _buildResultImageCard(),
                ),
              ),
            ],

            // 提取的水印显示
            if (_extractedWatermark != null) ...[
              FadeTransition(
                opacity: _animationController,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.easeOut,
                  )),
                  child: _buildExtractedWatermarkCard(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultImageCard() {
    return Card(
      elevation: 0,
      color: Colors.blue.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle, size: 20, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '带水印的图片',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _watermarkedImage!,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saveImage,
                    icon: Icon(kIsWeb ? Icons.download : Icons.save),
                    label: Text(kIsWeb ? '下载' : '保存'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                if (!kIsWeb) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _shareImage,
                      icon: const Icon(Icons.share),
                      label: const Text('分享'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtractedWatermarkCard() {
    return Card(
      elevation: 0,
      color: Colors.green.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.verified, size: 20, color: Colors.green),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '提取的水印',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.green),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _extractedWatermark!));
                    _showSnackBar('已复制到剪贴板');
                  },
                  tooltip: '复制',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                _extractedWatermark!,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}