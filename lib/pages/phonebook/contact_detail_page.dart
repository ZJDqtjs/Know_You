import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactDetailPage extends StatelessWidget {
  final Map<String, dynamic> contact;

  const ContactDetailPage({super.key, required this.contact});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('联系人详情')),
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
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE8F5E9), width: 8.w),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        contact['avatar'],
                        width: 200.w,
                        height: 200.w,
                        fit: BoxFit.cover,
                        errorBuilder: (c,e,s) => Image.asset('assets/images/avatar.svg', width: 200.w, height: 200.w),
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    contact['name'],
                    style: TextStyle(fontSize: 48.sp, color: const Color(0xFF333333), fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    contact['phone'],
                    style: TextStyle(fontSize: 36.sp, color: const Color(0xFF666666)),
                  ),
                ],
              ),
            ),
            SizedBox(height: 60.h),
            SizedBox(
              width: 0.8.sw,
              height: 120.h,
              child: ElevatedButton(
                onPressed: () => _makeCall(contact['phone']),
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
                    Text('📞', style: TextStyle(fontSize: 48.sp)),
                    SizedBox(width: 16.w),
                    Text('拨打电话', style: TextStyle(fontSize: 36.sp, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        Fluttertoast.showToast(msg: '无法拨打电话');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '拨打电话失败: $e');
    }
  }
}
