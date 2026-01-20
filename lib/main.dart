import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'common/auth_provider.dart';
import 'common/notification_service.dart';
import 'common/floating_ball_service.dart';
import 'common/shizuku_service.dart';
import 'pages/auth/login_page.dart';
import 'pages/main_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 Shizuku 服务（更早初始化，给它时间自动启用无障碍）
  final shizukuService = ShizukuService();
  shizukuService.init(); // 不等待，让它在后台运行
  
  // 初始化悬浮球服务（不等待TTS完全初始化，让它在后台完成）
  final floatingBallService = FloatingBallService();
  // 延迟初始化TTS，让应用先启动
  Future.delayed(const Duration(milliseconds: 500), () {
    floatingBallService.init();
  });
  
  runApp(MyApp(floatingBallService: floatingBallService, shizukuService: shizukuService));
}

class MyApp extends StatelessWidget {
  final FloatingBallService floatingBallService;
  final ShizukuService shizukuService;
  
  const MyApp({super.key, required this.floatingBallService, required this.shizukuService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkLogin()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
        ChangeNotifierProvider.value(value: floatingBallService),
        ChangeNotifierProvider.value(value: shizukuService),
      ],
      child: ScreenUtilInit(
        designSize: const Size(375, 812), // Assuming standard iPhone X design size from UniApp default
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return MaterialApp(
            title: '知颐',
            navigatorKey: NotificationService.navigatorKey,
            theme: ThemeData(
              primarySwatch: Colors.green,
              scaffoldBackgroundColor: const Color(0xFFF5F5F5),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFE8F5E9),
                foregroundColor: Colors.black,
                elevation: 0,
              ),
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: Color(0xFFE8F5E9),
                selectedItemColor: Color(0xFF4CAF50),
                unselectedItemColor: Color(0xFF666666),
              ),
            ),
            home: const AuthGuard(),
          );
        },
      ),
    );
  }
}

class AuthGuard extends StatelessWidget {
  const AuthGuard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return auth.isLoggedIn ? const MainPage() : const LoginPage();
  }
}
