import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class AppDetailPage extends StatelessWidget {
  final Map<String, dynamic> app;

  const AppDetailPage({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
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
                    child: Image.asset(
                      app['icon'],
                      width: 200.w,
                      height: 200.w,
                      fit: BoxFit.cover,
                      errorBuilder: (c,e,s) => Image.asset('assets/images/avatar.svg', width: 200.w, height: 200.w),
                    ),
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
    // Note: Launching apps by package name is tricky in standard Flutter without specific plugins like `external_app_launcher` or `device_apps`.
    // `url_launcher` supports some schemes.
    // For WeChat: weixin://
    // For Douyin: snssdk1128://
    
    String? scheme;
    if (packageName == 'com.tencent.mm') {
      scheme = 'weixin://';
    } else if (packageName == 'com.ss.android.ugc.aweme') {
      scheme = 'snssdk1128://';
    }

    if (scheme != null) {
      final Uri launchUri = Uri.parse(scheme);
      try {
        if (await canLaunchUrl(launchUri)) {
          await launchUrl(launchUri);
        } else {
          Fluttertoast.showToast(msg: '无法打开应用，请确认已安装');
        }
      } catch (e) {
        Fluttertoast.showToast(msg: '打开失败: $e');
      }
    } else {
      // For general Android apps, we would need `external_app_launcher` plugin or `android_intent_plus`.
      // Since I can't add arbitrary plugins without user approval usually, but `url_launcher` is already added.
      // I'll stick to schemes for known apps as per migration.
      Fluttertoast.showToast(msg: '暂不支持该应用跳转');
    }
  }
}
