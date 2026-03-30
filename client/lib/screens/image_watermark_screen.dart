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
  final ScrollController _scrollController = ScrollController();

  Uint8List? _selectedImageBytes;
  String? _selectedFileName;
  Uint8List? _watermarkedImage;
  String? _extractedWatermark;
  bool _isLoading = false;
  bool _isEmbedMode = true;
  late AnimationController _animationController;

  // 算法选择
  String _selectedAlgorithm = 'DWT-SVD';
  double _strength = 50;
  Map<String, Map<String, dynamic>> _strengthConfig = {};

  // 算法信息
  final Map<String, Map<String, dynamic>> _algorithmInfo = {
    'LSB': {
      'name': 'LSB',
      'fullName': '最低有效位',
      'desc': '容量大，易破坏',
      'robustness': 1,
      'icon': Icons.layers_outlined,
      'color': Color(0xFF9E9E9E),
    },
    'DCT': {
      'name': 'DCT',
      'fullName': '离散余弦变换',
      'desc': '抗JPEG压缩',
      'robustness': 3,
      'icon': Icons.waves_outlined,
      'color': Color(0xFF2196F3),
    },
    'DWT': {
      'name': 'DWT',
      'fullName': '离散小波变换',
      'desc': '较强鲁棒性',
      'robustness': 4,
      'icon': Icons.grid_on_outlined,
      'color': Color(0xFF4CAF50),
    },
    'DWT-SVD': {
      'name': 'DWT-SVD',
      'fullName': '小波+SVD混合',
      'desc': '极强鲁棒性',
      'robustness': 5,
      'icon': Icons.shield_outlined,
      'color': Color(0xFFFF9800),
    },
    'QIM': {
      'name': 'QIM',
      'fullName': '量化索引调制',
      'desc': '最先进方法',
      'robustness': 4,
      'icon': Icons.science_outlined,
      'color': Color(0xFF9C27B0),
    },
    'SS': {
      'name': 'SS',
      'fullName': '扩频水印',
      'desc': '高安全性',
      'robustness': 5,
      'icon': Icons.signal_cellular_alt_outlined,
      'color': Color(0xFFF44336),
    },
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _initStrengthConfig();
    _updateStrengthForAlgorithm(_selectedAlgorithm);
  }

  void _initStrengthConfig() {
    _strengthConfig = {
      'LSB': {'min': 1.0, 'max': 1.0, 'step': 0.0, 'default': 1.0, 'label': '固定'},
      'DCT': {'min': 20.0, 'max': 100.0, 'step': 10.0, 'default': 50.0, 'label': '系数差值'},
      'DWT': {'min': 40.0, 'max': 150.0, 'step': 10.0, 'default': 80.0, 'label': '系数差值'},
      'DWT-SVD': {'min': 0.01, 'max': 0.1, 'step': 0.01, 'default': 0.03, 'label': '修改比例'},
      'QIM': {'min': 15.0, 'max': 60.0, 'step': 5.0, 'default': 30.0, 'label': '量化步长'},
      'SS': {'min': 5.0, 'max': 30.0, 'step': 5.0, 'default': 15.0, 'label': '扩频强度'},
    };
  }

  void _updateStrengthForAlgorithm(String algo) {
    if (_strengthConfig.containsKey(algo)) {
      _strength = _strengthConfig[algo]!['default'];
    }
  }

  @override
  void dispose() {
    _watermarkController.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<bool> _requestStoragePermission() async {
    if (kIsWeb) return true;
    if (await Permission.photos.isGranted) return true;
    var status = await Permission.photos.request();
    if (status.isGranted) return true;
    status = await Permission.storage.request();
    if (status.isGranted) return true;
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
        strength: _selectedAlgorithm != 'LSB' ? _strength : null,
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

      // 显示详细弹窗
      _showEmbedResultDialog(result);
    } catch (e) {
      _showSnackBar('嵌入失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showEmbedResultDialog(Map<String, dynamic> result) {
    final colorScheme = Theme.of(context).colorScheme;
    final isKnown = result['isKnown'] == true;
    final previousInfo = result['previousInfo'] as Map<String, dynamic>?;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text('水印嵌入成功'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 算法信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('算法: ${result['algorithm'] ?? _selectedAlgorithm}',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.tune, size: 16, color: colorScheme.secondary),
                      const SizedBox(width: 8),
                      Text('强度: ${result['strength'] ?? _strength.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.fingerprint, size: 16, color: colorScheme.tertiary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('哈希: ${result['imageHash'] ?? ''}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 历史记录提示
            if (isKnown && previousInfo != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        const Text('图片历史记录',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('首次记录: ${previousInfo['first_seen'] ?? '未知'}',
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('已嵌入水印次数: ${previousInfo['watermark_count'] ?? 0}',
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    const Text('此图片已在系统中记录，可追溯水印历史。',
                        style: TextStyle(fontSize: 11, color: Colors.orange)),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.new_releases, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('新图片记录已创建',
                          style: TextStyle(color: Colors.green)),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _saveImage();
            },
            child: const Text('保存图片'),
          ),
        ],
      ),
    );
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
        strength: _selectedAlgorithm == 'QIM' || _selectedAlgorithm == 'DWT-SVD' ? _strength : null,
      );

      setState(() {
        _extractedWatermark = result['watermark'];
        _watermarkedImage = null;
      });

      _animationController.forward(from: 0);

      // 显示提取结果弹窗
      _showExtractResultDialog(result);
    } catch (e) {
      _showSnackBar('提取失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showExtractResultDialog(Map<String, dynamic> result) {
    final colorScheme = Theme.of(context).colorScheme;
    final success = result['success'] == true;
    final isWatermarked = result['is_watermarked'] == true;
    final recordInfo = result['record_info'] as Map<String, dynamic>?;
    final confidence = result['confidence'] as double? ?? 0.0;
    final detection = result['detection'] as Map<String, dynamic>?;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              success ? Icons.verified : Icons.warning_amber,
              color: success ? Colors.green : Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(success ? '水印提取成功' : '提取结果'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 水印内容
              if (success && result['watermark'] != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('水印内容:',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      SelectableText(
                        result['watermark'],
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(result['message'] ?? '未检测到水印'),
                ),
              const SizedBox(height: 12),
              // 置信度信息
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.analytics, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        const Text('盲检测分析',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('当前算法($_selectedAlgorithm)置信度: ',
                            style: const TextStyle(fontSize: 12)),
                        Text('${(confidence * 100).toStringAsFixed(1)}%',
                            style: TextStyle(fontWeight: FontWeight.bold,
                              color: confidence > 0.5 ? Colors.green : Colors.orange)),
                      ],
                    ),
                    if (detection != null && detection['best_match'] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('最佳匹配算法: ${detection['best_match']}',
                              style: const TextStyle(fontSize: 12)),
                          Text(' (${((detection['best_confidence'] as num? ?? 0) * 100).toStringAsFixed(1)}%)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                    if (!success && confidence > 0.3)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('提示: 检测到可能的水印特征，建议尝试其他算法',
                            style: TextStyle(fontSize: 11, color: Colors.blue[700])),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // 图片信息
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.fingerprint, size: 16, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('图片哈希: ${result['image_hash'] ?? ''}',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 16, color: colorScheme.secondary),
                        const SizedBox(width: 8),
                        Text('使用算法: ${result['algorithm'] ?? _selectedAlgorithm}',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              // 历史记录
              if (isWatermarked && recordInfo != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.history, color: Colors.purple, size: 20),
                          const SizedBox(width: 8),
                          const Text('水印记录',
                              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.purple)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (recordInfo['watermark'] != null)
                        Text('水印内容: ${recordInfo['watermark']}',
                            style: const TextStyle(fontSize: 12)),
                      if (recordInfo['algorithm'] != null)
                        Text('嵌入算法: ${recordInfo['algorithm']}',
                            style: const TextStyle(fontSize: 12)),
                      if (recordInfo['created'] != null)
                        Text('嵌入时间: ${recordInfo['created']}',
                            style: const TextStyle(fontSize: 12)),
                      if (recordInfo['strength'] != null)
                        Text('嵌入强度: ${recordInfo['strength']}',
                            style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (success && result['watermark'] != null)
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: result['watermark']));
                Navigator.pop(context);
                _showSnackBar('已复制到剪贴板');
              },
              child: const Text('复制水印'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
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
          _showSnackBar('已保存到相册');
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
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 600;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.image, size: 20, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 10),
            const Text('图像水印'),
          ],
        ),
        actions: [
          if (_selectedImageBytes != null)
            IconButton(icon: const Icon(Icons.clear_all), onPressed: _clearAll, tooltip: '清空'),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(horizontal: isWide ? 32 : 16, vertical: 16),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildModeSwitch(),
                const SizedBox(height: 20),
                _buildAlgorithmSelector(),
                const SizedBox(height: 20),
                _buildImagePicker(),
                const SizedBox(height: 16),
                if (_isEmbedMode) ...[
                  _buildWatermarkInput(),
                  const SizedBox(height: 16),
                ],
                _buildActionButton(),
                const SizedBox(height: 24),
                if (_watermarkedImage != null) _buildResultCard(),
                if (_extractedWatermark != null) _buildExtractedCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSwitch() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: true, label: Text('嵌入水印'), icon: Icon(Icons.add_circle_outline, size: 18)),
          ButtonSegment(value: false, label: Text('提取水印'), icon: Icon(Icons.search, size: 18)),
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
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ),
    );
  }

  Widget _buildAlgorithmSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 3 : 2;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text('选择算法', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.8,
              children: _algorithmInfo.keys.map((algo) {
                final info = _algorithmInfo[algo]!;
                final isSelected = _selectedAlgorithm == algo;
                return _buildAlgorithmCard(algo, info, isSelected);
              }).toList(),
            ),
            if (_selectedAlgorithm != 'LSB') ...[
              const SizedBox(height: 16),
              _buildStrengthSlider(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlgorithmCard(String algo, Map<String, dynamic> info, bool isSelected) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = info['color'] as Color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() {
          _selectedAlgorithm = algo;
          _updateStrengthForAlgorithm(algo);
        }),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.transparent, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(info['icon'], size: 20, color: isSelected ? color : colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(info['name'], style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? color : null)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(info['desc'], style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                _buildRobustnessIndicator(info['robustness'] as int, isSelected ? color : colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRobustnessIndicator(int level, Color color) {
    return Row(
      children: List.generate(5, (i) {
        return Container(
          width: 12,
          height: 4,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: i < level ? color : color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildStrengthSlider() {
    final config = _strengthConfig[_selectedAlgorithm]!;
    final min = config['min'] as double;
    final max = config['max'] as double;
    final step = config['step'] as double;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text('嵌入强度', style: TextStyle(fontWeight: FontWeight.w500, color: colorScheme.primary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _strength.toStringAsFixed(_selectedAlgorithm == 'DWT-SVD' ? 2 : 0),
                  style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.primary, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: _strength.clamp(min, max),
            min: min,
            max: max,
            divisions: step > 0 ? ((max - min) / step).round() : null,
            onChanged: (value) => setState(() => _strength = value),
            activeColor: colorScheme.primary,
            inactiveColor: colorScheme.primaryContainer.withValues(alpha: 0.5),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('低强度', style: TextStyle(fontSize: 10, color: colorScheme.outline)),
              Text('高强度', style: TextStyle(fontSize: 10, color: colorScheme.outline)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: _pickImage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: _selectedImageBytes == null ? 200 : 250,
        decoration: BoxDecoration(
          color: _selectedImageBytes == null ? colorScheme.surfaceContainerHighest : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedImageBytes == null ? colorScheme.outlineVariant : colorScheme.primary.withValues(alpha: 0.5),
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
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.add_photo_alternate_outlined, size: 40, color: colorScheme.primary),
                  ),
                  const SizedBox(height: 12),
                  Text('点击选择图片', style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('支持 PNG, JPG 格式', style: TextStyle(color: colorScheme.outline, fontSize: 12)),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(_selectedImageBytes!, fit: BoxFit.contain),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: colorScheme.surface, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.edit, size: 18, color: colorScheme.primary),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildWatermarkInput() {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, size: 20, color: colorScheme.secondary),
                const SizedBox(width: 8),
                Text('水印内容', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _watermarkController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: '输入要嵌入的水印信息...',
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return FilledButton.icon(
      onPressed: _isLoading ? null : (_isEmbedMode ? _embedWatermark : _extractWatermark),
      icon: _isLoading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(_isEmbedMode ? Icons.add_circle_outline : Icons.search),
      label: Text(_isEmbedMode ? '嵌入水印' : '提取水印'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildResultCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return FadeTransition(
      opacity: _animationController,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(_animationController),
        child: Card(
          elevation: 0,
          color: Colors.blue.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.check_circle, size: 20, color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('带水印的图片', style: TextStyle(fontWeight: FontWeight.w600))),
                    Text(_selectedAlgorithm, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_watermarkedImage!, fit: BoxFit.contain),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saveImage,
                        icon: Icon(kIsWeb ? Icons.download : Icons.save),
                        label: Text(kIsWeb ? '下载' : '保存'),
                        style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtractedCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return FadeTransition(
      opacity: _animationController,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(_animationController),
        child: Card(
          elevation: 0,
          color: Colors.green.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.verified, size: 20, color: Colors.green),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('提取的水印', style: TextStyle(fontWeight: FontWeight.w600))),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Colors.green),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _extractedWatermark!));
                        _showSnackBar('已复制到剪贴板');
                      },
                      tooltip: '复制',
                      style: IconButton.styleFrom(backgroundColor: Colors.green.withValues(alpha: 0.1)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(_extractedWatermark!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}