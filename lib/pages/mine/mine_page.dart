import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/services.dart';
import '../../common/api.dart';
import '../../common/auth_provider.dart';
import '../../widgets/common_card.dart';
import 'edit_profile_page.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key});

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  String _bindingCode = '------';
  bool _isLoadingCode = false;
  List<dynamic> _myInitiatorBindings = []; // 我控制的
  List<dynamic> _myTargetBindings = []; // 控制我的

  @override
  void initState() {
    super.initState();
    _fetchBindingCode();
    _fetchBindings();
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

  Future<void> _fetchBindings() async {
    try {
      // 获取我发起的绑定（我控制的）
      final initiatorRes = await Api.bindings.list('initiator');
      List<dynamic> initiatorList = [];
      if (initiatorRes is List) {
        initiatorList = initiatorRes;
      } else if (initiatorRes is Map && initiatorRes['list'] is List) {
        initiatorList = initiatorRes['list'];
      }

      // 获取我被绑定的（控制我的）
      final targetRes = await Api.bindings.list('target');
      List<dynamic> targetList = [];
      if (targetRes is List) {
        targetList = targetRes;
      } else if (targetRes is Map && targetRes['list'] is List) {
        targetList = targetRes['list'];
      }

      setState(() {
        _myInitiatorBindings = initiatorList.where((item) => item['status'] == 'accepted').toList();
        _myTargetBindings = targetList.where((item) => item['status'] == 'accepted').toList();
      });
    } catch (e) {
      print('Fetch bindings failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final nickname = user?['nickname'] ?? user?['username'] ?? 'User';
    final avatarUrl = user?['avatar'];

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
                  backgroundColor: const Color(0xFFE1BEE7),
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Icon(Icons.person, size: 40.w, color: Colors.white)
                      : null,
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

            // Bound Lists
            CommonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('我正绑定谁 (我控制的)', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10.h),
                  _myInitiatorBindings.isEmpty
                      ? Text('暂无', style: TextStyle(color: Colors.grey, fontSize: 14.sp))
                      : Wrap(
                          spacing: 10.w,
                          runSpacing: 10.h,
                          children: _myInitiatorBindings.map((binding) {
                            final user = binding['targetUser'] ?? binding['targetUserInfo'];
                            return _buildAvatarItem(user);
                          }).toList(),
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
                  _myTargetBindings.isEmpty
                      ? Text('暂无', style: TextStyle(color: Colors.grey, fontSize: 14.sp))
                      : Wrap(
                          spacing: 10.w,
                          runSpacing: 10.h,
                          children: _myTargetBindings.map((binding) {
                            final user = binding['initiatorUser'] ?? binding['initiatorUserInfo'];
                            return _buildAvatarItem(user);
                          }).toList(),
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const EditProfilePage()),
                        ).then((_) {
                          // 编辑完成后刷新数据
                          setState(() {});
                        });
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

  Widget _buildAvatarItem(dynamic user) {
    if (user == null) return const SizedBox.shrink();
    final name = user['nickname'] ?? user['username'] ?? 'User';
    final avatarUrl = user['avatar'];
    
    return Column(
      children: [
        CircleAvatar(
          radius: 25.w,
          backgroundColor: const Color(0xFFE1BEE7),
          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
              ? NetworkImage(avatarUrl)
              : null,
          child: avatarUrl == null || avatarUrl.isEmpty
              ? Text(
                  name[0].toUpperCase(),
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.white),
                )
              : null,
        ),
        SizedBox(height: 4.h),
        Text(name, style: TextStyle(fontSize: 12.sp)),
      ],
    );
  }
}
