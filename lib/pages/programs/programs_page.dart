import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'app_detail_page.dart';

class ProgramsPage extends StatefulWidget {
  const ProgramsPage({super.key});

  @override
  State<ProgramsPage> createState() => _ProgramsPageState();
}

class _ProgramsPageState extends State<ProgramsPage> {
  final List<Map<String, dynamic>> _apps = [
    {
      'id': 1,
      'name': '微信',
      'packageName': 'com.tencent.mm',
      'icon': 'assets/images/weixin.png'
    },
    {
      'id': 2,
      'name': '抖音',
      'packageName': 'com.ss.android.ugc.aweme',
      'icon': 'assets/images/douyin.png'
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('程序')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Wrap(
          spacing: 30.w,
          runSpacing: 30.w,
          children: [
            ..._apps.map((app) => _buildAppItem(app)),
            _buildAddAppItem(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppItem(Map<String, dynamic> app) {
    return GestureDetector(
      onTap: () => _navigateToAppDetail(app),
      child: Container(
        width: 160.w,
        height: 220.h,
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20.r),
              child: Image.asset(
                app['icon'],
                width: 120.w, // Adjusted to fit
                height: 120.w,
                fit: BoxFit.cover,
                errorBuilder: (c,e,s) => Image.asset('assets/images/avatar.svg', width: 120.w, height: 120.w),
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              app['name'],
              style: TextStyle(fontSize: 28.sp, color: const Color(0xFF333333), fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddAppItem() {
    return GestureDetector(
      onTap: _addApp,
      child: Container(
        width: 160.w,
        height: 220.h,
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: const Color(0xFF4CAF50), width: 2.w),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.w,
              height: 80.w,
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('+', style: TextStyle(color: Colors.white, fontSize: 60.sp, fontWeight: FontWeight.w300)),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              '添加应用',
              style: TextStyle(fontSize: 28.sp, color: const Color(0xFF4CAF50), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToAppDetail(Map<String, dynamic> app) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppDetailPage(app: app),
      ),
    );
  }

  void _addApp() {
    Fluttertoast.showToast(msg: '添加应用功能开发中');
  }
}
