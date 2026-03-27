import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class TextWatermarkScreen extends StatefulWidget {
  const TextWatermarkScreen({super.key});

  @override
  State<TextWatermarkScreen> createState() => _TextWatermarkScreenState();
}

class _TextWatermarkScreenState extends State<TextWatermarkScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _watermarkController = TextEditingController();

  String? _resultText;
  String? _extractedWatermark;
  bool _isLoading = false;
  bool _isEmbedMode = true;
  late AnimationController _animationController;

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
    _textController.dispose();
    _watermarkController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _embedWatermark() async {
    if (_textController.text.isEmpty) {
      _showSnackBar('请输入文本内容');
      return;
    }
    if (_watermarkController.text.isEmpty) {
      _showSnackBar('请输入水印内容');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.embedTextWatermark(
        _textController.text,
        _watermarkController.text,
      );

      setState(() {
        _resultText = result['watermarked_text'];
        _extractedWatermark = null;
      });

      _animationController.forward(from: 0);
      _showSnackBar('水印嵌入成功！');
    } catch (e) {
      _showSnackBar('嵌入失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _extractWatermark() async {
    if (_textController.text.isEmpty) {
      _showSnackBar('请输入待检测文本');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.extractTextWatermark(_textController.text);

      setState(() {
        _extractedWatermark = result['watermark'];
        _resultText = null;
      });

      _animationController.forward(from: 0);
      if (result['success']) {
        _showSnackBar('水印提取成功！');
      } else {
        _showSnackBar(result['message'] ?? '未检测到水印');
      }
    } catch (e) {
      _showSnackBar('提取失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeWatermark() async {
    if (_textController.text.isEmpty) {
      _showSnackBar('请输入文本内容');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.removeTextWatermark(_textController.text);

      setState(() {
        _resultText = result['clean_text'];
        _extractedWatermark = null;
      });

      _animationController.forward(from: 0);
      _showSnackBar('水印移除成功！');
    } catch (e) {
      _showSnackBar('移除失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('已复制到剪贴板');
  }

  void _clearAll() {
    _textController.clear();
    _watermarkController.clear();
    setState(() {
      _resultText = null;
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
                Icons.text_fields,
                size: 20,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            const Text('文本水印'),
          ],
        ),
        actions: [
          if (_textController.text.isNotEmpty || _resultText != null)
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
                    _resultText = null;
                    _extractedWatermark = null;
                    _textController.clear();
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

            // 文本输入卡片
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
                          Icons.edit_note,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '文本内容',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _textController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: _isEmbedMode ? '输入原始文本' : '输入带水印的文本',
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
            if (_isEmbedMode)
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _embedWatermark,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_circle_outline),
                      label: const Text('嵌入水印'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _removeWatermark,
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      label: const Text('移除'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              FilledButton.icon(
                onPressed: _isLoading ? null : _extractWatermark,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: const Text('提取水印'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // 结果显示
            if (_resultText != null) ...[
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
                  child: _buildResultCard(
                    title: '处理结果',
                    content: _resultText!,
                    icon: Icons.check_circle,
                    color: Colors.blue,
                    onCopy: () => _copyToClipboard(_resultText!),
                  ),
                ),
              ),
            ],

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
                  child: _buildResultCard(
                    title: '提取的水印',
                    content: _extractedWatermark!,
                    icon: Icons.verified,
                    color: Colors.green,
                    onCopy: () => _copyToClipboard(_extractedWatermark!),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
    required VoidCallback onCopy,
  }) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
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
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy_rounded, color: color),
                  onPressed: onCopy,
                  tooltip: '复制',
                  style: IconButton.styleFrom(
                    backgroundColor: color.withValues(alpha: 0.1),
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
                content,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}