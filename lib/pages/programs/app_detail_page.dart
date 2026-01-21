import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:installed_apps/installed_apps.dart';

class AppDetailPage extends StatelessWidget {
  final Map<String, dynamic> app;

  const AppDetailPage({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    Widget iconWidget;
    if (app['iconData'] != null) {
      iconWidget = Image.memory(
        app['iconData'],
        width: 200.w,
        height: 200.w,
        fit: BoxFit.cover,
      );
    } else if (app['icon'] != null) {
      iconWidget = Image.asset(
        app['icon'],
        width: 200.w,
        height: 200.w,
        fit: BoxFit.cover,
        errorBuilder: (c,e,s) => Image.asset('assets/images/avatar.svg', width: 200.w, height: 200.w),
      );
    } else {
       iconWidget = Icon(Icons.android, size: 200.w, color: Colors.green);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('应用详情')),
      body: Center(
        child: Column(
          children: [
            SizedBox(height: 60.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 60.h),
              margin: EdgeInsets.symmetric(horizontal: 40.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(40.r),
                    child: iconWidget,
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    app['name'],
                    style: TextStyle(fontSize: 48.sp, color: const Color(0xFF333333), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            SizedBox(height: 60.h),
            SizedBox(
              width: 0.8.sw,
              height: 120.h,
              child: ElevatedButton(
                onPressed: () => _launchApp(app['packageName']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(60.r)),
                  elevation: 8,
                  shadowColor: const Color(0xFF4CAF50).withOpacity(0.3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('📱', style: TextStyle(fontSize: 48.sp)),
                    SizedBox(width: 16.w),
                    Text('打开应用', style: TextStyle(fontSize: 36.sp, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchApp(String packageName) async {
    try {
      await InstalledApps.startApp(packageName);
    } catch (e) {
      debugPrint('Error launching app: $e');
    }
  }
}
