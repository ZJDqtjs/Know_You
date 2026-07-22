import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/services.dart';
import '../../common/api.dart';
import '../../common/app_config.dart';
import '../../common/auth_provider.dart';
import '../../common/shizuku_service.dart';
import '../../common/voice_assistant_service.dart';
import '../../widgets/common_card.dart';
import '../voice_assistant_settings_page.dart';
import 'floating_ball_settings_page.dart';
import 'edit_profile_page.dart';
import 'accessibility_keep_alive_page.dart';
import 'post_manage_page.dart';
import 'listing_product_page.dart';

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

  String _getUserName(dynamic user) {
    return user?['nickname'] ?? user?['username'] ?? '用户';
  }

  Future<void> _confirmUnlink(dynamic binding, String userName) async {
    final bindingId = binding is Map
        ? (binding['id'] ?? binding['bindingId'] ?? binding['binding_id'])
        : binding;
    if (bindingId == null) {
      Fluttertoast.showToast(msg: '未找到绑定信息');
      return;
    }
    final shouldUnlink = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解除绑定确认'),
        content: Text('确定要与“$userName”解除绑定吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('解除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldUnlink != true) return;
    try {
      await Api.bindings.unlink(bindingId);
      await _fetchBindings();
      Fluttertoast.showToast(msg: '已解除绑定');
    } catch (e) {
      Fluttertoast.showToast(msg: '解除绑定失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final nickname = user?['nickname'] ?? user?['username'] ?? 'User';
    final avatarUrl = user?['avatar'];

    return Scaffold(
      appBar: AppBar(title: const Text('我的'),centerTitle: true),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 20.h),
            
            // Avatar & Name
            GestureDetector(
              onTap: () {
                if (!auth.isLoggedIn) {
                  Fluttertoast.showToast(msg: '请先登录');
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditProfilePage()),
                ).then((_) {
                  setState(() {});
                });
              },
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40.w,
                    backgroundColor: const Color(0xFFE1BEE7),
                    backgroundImage: avatarUrl != null && avatarUrl.toString().isNotEmpty
                        ? NetworkImage(AppConfig.currentOrDefault.resolveHttpUrl(avatarUrl.toString()))
                        : null,
                    child: avatarUrl == null || avatarUrl.toString().isEmpty
                        ? Icon(Icons.person, size: 40.w, color: Colors.white)
                        : null,
                  ),
                  SizedBox(height: 10.h),
                  Text(nickname, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            // Binding Code
            CommonCard(
              child: Column(
                children: [
                  const Icon(Icons.monitor_heart, color: Colors.green, size: 40),
                  SizedBox(height: 2.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('我的关联码: ', style: TextStyle(fontSize: 16.sp)),
                      Text(_bindingCode, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    ],
                  ),
                  SizedBox(height: 10.h),
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
                      : SizedBox(
                          height: 75.h,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _myInitiatorBindings.length,
                            separatorBuilder: (context, index) => SizedBox(width: 12.w),
                            itemBuilder: (context, index) {
                              final binding = _myInitiatorBindings[index];
                              final user = binding['targetUser'] ?? binding['targetUserInfo'];
                              return _buildAvatarItem(
                                user,
                                onTap: () => _confirmUnlink(binding, _getUserName(user)),
                              );
                            },
                          ),
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
                      : SizedBox(
                          height: 75.h,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _myTargetBindings.length,
                            separatorBuilder: (context, index) => SizedBox(width: 12.w),
                            itemBuilder: (context, index) {
                              final binding = _myTargetBindings[index];
                              final user = binding['initiatorUser'] ?? binding['initiatorUserInfo'];
                              return _buildAvatarItem(
                                user,
                                onTap: () => _confirmUnlink(binding, _getUserName(user)),
                              );
                            },
                          ),
                        ),
                ],
              ),
            ),

            SizedBox(height: 20.h),
            
            // 商品上架
            CommonCard(
              child: InkWell(
                onTap: () {
                  // Permission Check Mock
                  // In a real verification, you would check user role here
                  // For now, we simulate a permission flow
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('商户权限验证'),
                      content: const Text('系统正在验证您的上架权限...'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context); // Close dialog
                            // Simulate success
                             Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ListingProductPage()),
                              );
                          },
                          child: const Text('验证通过 (模拟)'),
                        ),
                      ],
                    ),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.storefront, color: Colors.blue),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('上架商品', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500)),
                          Text('商家发布与管理商品', style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),

            // 帖子管理入口
            CommonCard(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PostManagePage()),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.article_outlined, color: Colors.orange),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('帖子管理', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500)),
                          Text('管理与删除我的帖子', style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),

            // 无障碍保活设置入口
            CommonCard(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AccessibilityKeepAlivePage()),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.accessibility_new, color: Colors.green),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('无障碍保活', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500)),
                          Consumer<ShizukuService>(
                            builder: (context, service, _) {
                              String statusText;
                              Color statusColor;
                              if (service.isAccessibilityEnabled) {
                                statusText = '无障碍服务运行中';
                                statusColor = Colors.green;
                              } else {
                                statusText = '未启用';
                                statusColor = Colors.orange;
                              }
                              return Text(
                                statusText,
                                style: TextStyle(fontSize: 12.sp, color: statusColor),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),

            // 语音助手设置入口
            CommonCard(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const VoiceAssistantSettingsPage()),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.mic, color: Colors.purple),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('语音助手', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500)),
                          Consumer<VoiceAssistantService>(
                            builder: (context, service, _) {
                              String statusText;
                              Color statusColor;
                              if (!service.speechAvailable) {
                                statusText = '识别不可用';
                                statusColor = Colors.redAccent;
                              } else if (service.isEnabled) {
                                statusText = '已启用';
                                statusColor = Colors.green;
                              } else {
                                statusText = '已禁用';
                                statusColor = Colors.orange;
                              }
                              return Text(
                                statusText,
                                style: TextStyle(fontSize: 12.sp, color: statusColor),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),

            // 悬浮球设置入口
            CommonCard(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FloatingBallSettingsPage()),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bubble_chart, color: Colors.blue),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('悬浮球设置', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500)),
                          Text('屏幕朗读与语音助手悬浮球', style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarItem(dynamic user, {VoidCallback? onTap}) {
    if (user == null) return const SizedBox.shrink();
    final name = _getUserName(user);
    final avatarUrl = user['avatar'];
    
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          CircleAvatar(
            radius: 25.w,
            backgroundColor: const Color(0xFFE1BEE7),
            backgroundImage: avatarUrl != null && avatarUrl.toString().isNotEmpty
                ? NetworkImage(AppConfig.currentOrDefault.resolveHttpUrl(avatarUrl.toString()))
                : null,
            child: avatarUrl == null || avatarUrl.toString().isEmpty
                ? Text(
                    name[0].toUpperCase(),
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.white),
                  )
                : null,
          ),
          SizedBox(height: 4.h),
          Text(name, style: TextStyle(fontSize: 12.sp)),
        ],
      ),
    );
  }
}
