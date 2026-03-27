import 'package:flutter/material.dart';
import 'text_watermark_screen.dart';
import 'image_watermark_screen.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isConnected = false;
  String? _currentServerUrl;

  final List<Widget> _screens = const [
    TextWatermarkScreen(),
    ImageWatermarkScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initState();
  }

  Future<void> _initState() async {
    await ApiService.loadSavedUrl();
    _currentServerUrl = await ApiService.getSavedUrl();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final connected = await ApiService.checkConnection();
    if (mounted) {
      setState(() {
        _isConnected = connected;
      });
    }
  }

  Future<void> _showServerSettings() async {
    final controller = TextEditingController(text: _currentServerUrl ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('服务器设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '当前: ${_currentServerUrl ?? "默认地址"}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'http://IP:PORT',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '留空则使用默认地址',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ApiService.setBaseUrl('');
              Navigator.pop(context, '');
            },
            child: const Text('重置'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null) {
      await ApiService.setBaseUrl(result);
      setState(() {
        _currentServerUrl = result.isNotEmpty ? result : null;
      });
      _checkConnection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // 顶部状态栏
              Container(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 服务器状态
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isConnected ? Colors.green.shade100 : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isConnected ? Icons.cloud_done : Icons.cloud_off,
                            size: 14,
                            color: _isConnected ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isConnected ? '已连接' : '未连接',
                            style: TextStyle(
                              fontSize: 11,
                              color: _isConnected ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 设置按钮
                    IconButton(
                      onPressed: _showServerSettings,
                      icon: const Icon(Icons.settings_outlined),
                      iconSize: 20,
                      tooltip: '服务器设置',
                    ),
                  ],
                ),
              ),
              // 主内容
              Expanded(child: _screens[_currentIndex]),
            ],
          ),
          if (!_isConnected)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: _buildConnectionBanner(),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.text_fields_outlined),
            selectedIcon: Icon(Icons.text_fields),
            label: '文本水印',
          ),
          NavigationDestination(
            icon: Icon(Icons.image_outlined),
            selectedIcon: Icon(Icons.image),
            label: '图像水印',
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionBanner() {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.wifi_off, color: Colors.orange, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '服务器未连接\n${_currentServerUrl ?? "默认地址"}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: _checkConnection,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}