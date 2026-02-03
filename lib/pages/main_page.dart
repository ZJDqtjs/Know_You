import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../common/floating_ball_service.dart';
import '../common/shizuku_service.dart';
import '../widgets/voice_assistant_overlay.dart';
import 'index/index_page.dart';
import 'familyGuard/family_guard_page.dart';
import 'community/community_page.dart';
import 'mine/mine_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  final List<Widget> _pages = const [
    IndexPage(),
    CommunityPage(),
    FamilyGuardPage(),
    MinePage(),
  ];

  @override
  void initState() {
    super.initState();
    // 延迟启动悬浮球，确保 Overlay 已经准备好
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 先给 ShizukuService 一些时间自动启用无障碍（如果配置了）
      await Future.delayed(const Duration(seconds: 1));
      
      final service = Provider.of<FloatingBallService>(context, listen: false);
      
      if (!service.isEnabled && service.preferredEnabled) {
        // 检查无障碍服务
        await _checkAccessibilityService();
        service.enable(context);
      }
    });
  }
  
  @override
  void dispose() {
    _pageController.dispose();
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
        // 检查是否配置了 Shizuku 保活方式
        final shizukuService = Provider.of<ShizukuService>(context, listen: false);
        
        // 如果配置了 Shizuku 保活方式，等待 Shizuku 尝试自动启用
        if (shizukuService.keepAliveMethod == KeepAliveMethod.shizuku) {
          // 等待 Shizuku 尝试自动启用（最多等待 5 秒）
          for (int i = 0; i < 10; i++) {
            await Future.delayed(const Duration(milliseconds: 500));
            await shizukuService.refreshStatus();
            
            if (shizukuService.isAccessibilityEnabled) {
              print('[MainPage] Shizuku 已自动启用无障碍服务');
              return; // 已启用，不需要弹窗
            }
          }
          
          // 如果 Shizuku 可用但未能启用，说明可能是首次授权或网络问题
          if (shizukuService.isShizukuAvailable) {
            print('[MainPage] Shizuku 可用但未能自动启用，跳过弹窗让用户手动操作');
            return; // 让用户去设置页面手动处理
          }
        }
        
        // 没有配置保活方式或 Shizuku 不可用，显示提示对话框
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
    
    return VoiceAssistantOverlay(
      child: ReadableTextWrapper(
        service: floatingService,
        child: Scaffold(
          body: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            physics: const BouncingScrollPhysics(),
            children: _pages,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() => _currentIndex = index);
              _pageController.jumpToPage(index);
            },
            items: [
              BottomNavigationBarItem(
                icon: Image.asset('assets/images/home.png', width: 24, height: 24, errorBuilder: (c,e,s) => const Icon(Icons.home)),
                activeIcon: Image.asset('assets/images/home-active.png', width: 24, height: 24, errorBuilder: (c,e,s) => const Icon(Icons.home, color: Colors.green)),
                label: '主页',
              ),
              BottomNavigationBarItem(
                icon: Image.asset('assets/images/community.png', width: 24, height: 24, errorBuilder: (c,e,s) => const Icon(Icons.groups)),
                activeIcon: Image.asset('assets/images/community-active.png', width: 24, height: 24, errorBuilder: (c,e,s) => const Icon(Icons.groups, color: Colors.green)),
                label: '社区生活',
              ),
              BottomNavigationBarItem(
                icon: Image.asset('assets/images/family.png', width: 24, height: 24, errorBuilder: (c,e,s) => const Icon(Icons.favorite)),
                activeIcon: Image.asset('assets/images/family-active.png', width: 24, height: 24, errorBuilder: (c,e,s) => const Icon(Icons.favorite, color: Colors.green)),
                label: '亲情守护',
              ),
              BottomNavigationBarItem(
                icon: Image.asset('assets/images/user.png', width: 24, height: 24, errorBuilder: (c,e,s) => const Icon(Icons.person)),
                activeIcon: Image.asset('assets/images/user-active.png', width: 24, height: 24, errorBuilder: (c,e,s) => const Icon(Icons.person, color: Colors.green)),
                label: '我的',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
