import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/services.dart';
import '../../common/api.dart';
import '../../common/auth_provider.dart';
import '../../widgets/common_card.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key});

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  String _bindingCode = '------';
  bool _isLoadingCode = false;

  @override
  void initState() {
    super.initState();
    _fetchBindingCode();
  }

  Future<void> _fetchBindingCode() async {
    setState(() => _isLoadingCode = true);
    try {
      final res = await Api.bindings.genCode();
      setState(() {
        _bindingCode = res['code'];
      });
    } catch (e) {
      print('Gen code failed: $e');
    } finally {
      setState(() => _isLoadingCode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final nickname = user?['nickname'] ?? user?['username'] ?? 'User';

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 20.h),
            
            // Avatar & Name
            Column(
              children: [
                CircleAvatar(
                  radius: 40.w,
                  backgroundImage: const AssetImage('assets/static/images/avatar.svg'),
                  child: const Icon(Icons.person, size: 40),
                ),
                SizedBox(height: 10.h),
                Text(nickname, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
              ],
            ),

            // Binding Code
            CommonCard(
              child: Column(
                children: [
                  const Icon(Icons.monitor_heart, color: Colors.green, size: 40),
                  SizedBox(height: 10.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('我的关联码: ', style: TextStyle(fontSize: 16.sp)),
                      Text(_bindingCode, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _bindingCode));
                          Fluttertoast.showToast(msg: '已复制');
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text('复制', style: TextStyle(color: Colors.white)),
                      ),
                      ElevatedButton(
                        onPressed: _fetchBindingCode,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        child: const Text('刷新', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bound Lists (Simplified placeholder for now)
            CommonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('我正绑定谁 (我控制的)', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10.h),
                  // Placeholder list
                  Row(
                    children: [
                      _buildAvatarPlaceholder('Admin'),
                      SizedBox(width: 10.w),
                      _buildAvatarPlaceholder('Mom'),
                    ],
                  ),
                ],
              ),
            ),

             CommonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('我已被谁绑定 (控制我的)', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10.h),
                  // Placeholder list
                  Row(
                    children: [
                      _buildAvatarPlaceholder('Son'),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 20.h),
            
            // Logout
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Edit profile
                      },
                      child: const Text('编辑资料'),
                    ),
                  ),
                  SizedBox(width: 20.w),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        auth.logout();
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                      child: const Text('退出登录'),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    return Column(
      children: [
        CircleAvatar(child: Text(name[0])),
        SizedBox(height: 4.h),
        Text(name, style: TextStyle(fontSize: 12.sp)),
      ],
    );
  }
}
