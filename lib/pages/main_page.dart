import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../common/floating_ball_service.dart';
import 'index/index_page.dart';
import 'familyGuard/family_guard_page.dart';
import 'mine/mine_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  final List<Widget> _pages = const [
    IndexPage(),
    FamilyGuardPage(),
    MinePage(),
  ];

  @override
  void initState() {
    super.initState();
    // 延迟启动悬浮球，确保 Overlay 已经准备好
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final service = Provider.of<FloatingBallService>(context, listen: false);
      
      if (!service.isEnabled) {
        // 先检查无障碍服务
        await _checkAccessibilityService();
        service.enable(context);
      }
    });
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  void _showNoTtsEngineDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('缺少语音引擎'),
          ],
        ),
        content: const Text(
          '您的设备上没有安装语音合成(TTS)引擎，朗读功能将无法使用。\n\n'
          '建议安装"Google 文字转语音"应用。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('以后再说'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final service = Provider.of<FloatingBallService>(context, listen: false);
              await service.openTtsSettings();
            },
            child: const Text('系统设置'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final service = Provider.of<FloatingBallService>(context, listen: false);
              await service.openTtsEngineInstall();
            },
            child: const Text('去安装'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _checkAccessibilityService() async {
    try {
      const platform = MethodChannel('com.example.know_you/accessibility');
      final isEnabled = await platform.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
      
      if (!isEnabled && mounted) {
        // 显示提示对话框
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('需要启用无障碍服务'),
            content: const Text('为了使用悬浮球朗读功能，需要启用"知颐"无障碍服务。\n\n这将允许应用读取屏幕上的文字内容。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('暂不启用'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await platform.invokeMethod('openAccessibilitySettings');
                },
                child: const Text('去设置'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Error checking accessibility service: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final floatingService = Provider.of<FloatingBallService>(context);
    
    return ReadableTextWrapper(
      service: floatingService,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: [
            BottomNavigationBarItem(
              icon: Image.asset('assets/static/images/home.png', width: 24, height: 24, errorBuilder: (c,e,s) => const Icon(Icons.home)),
              activeIcon: Image.asset('assets/static/images/home-active.png', width: 24, height: 24, errorBuilder: (c,e,s) => const Icon(Icons.home, color: Colors.green)),
              label: '主页',
            ),
            BottomNavigationBarItem(
              icon: Image.asset('assets/static/images/family.png', width: 24, height: 24, errorBuilder: (c,e,s) => const Icon(Icons.favorite)),
              activeIcon: Image.asset('assets/static/images/family-active.png', width: 24, height: 24, errorBuilder: (c,e,s) => const Icon(Icons.favorite, color: Colors.green)),
              label: '亲情守护',
            ),
            BottomNavigationBarItem(
              icon: Image.asset('assets/static/images/user.png', width: 24, height: 24, errorBuilder: (c,e,s) => const Icon(Icons.person)),
              activeIcon: Image.asset('assets/static/images/user-active.png', width: 24, height: 24, errorBuilder: (c,e,s) => const Icon(Icons.person, color: Colors.green)),
              label: '我的',
            ),
          ],
        ),
        // 悬浮球开关按钮（当悬浮球未启用时显示）
        floatingActionButton: !floatingService.isEnabled
            ? FloatingActionButton.small(
                onPressed: () => floatingService.enable(context),
                backgroundColor: Colors.green,
                child: const Icon(Icons.record_voice_over, color: Colors.white),
              )
            : null,
      ),
    );
  }
}
