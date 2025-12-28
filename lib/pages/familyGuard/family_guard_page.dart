import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../common/api.dart';
import '../../common/webrtc_service.dart';
import '../../widgets/common_card.dart';
import 'package:fluttertoast/fluttertoast.dart';

class FamilyGuardPage extends StatefulWidget {
  const FamilyGuardPage({super.key});

  @override
  State<FamilyGuardPage> createState() => _FamilyGuardPageState();
}

class _FamilyGuardPageState extends State<FamilyGuardPage> {
  List<dynamic> _members = [];
  int _activeIndex = -1;
  bool _isLoading = false;
  
  // WebRTC
  WebRTCService? _webRTC;
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _inCall = false;
  bool _virtualMouseEnabled = false;
  WebRTCConnectionState _rtcState = WebRTCConnectionState.idle;
  String _rtcStatusText = '等待家人接受...';
  bool _assistDialogOpen = false;
  final ValueNotifier<int> _assistUiVersion = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _fetchMembers();
  }

  Future<void> _initRenderers() async {
    await _remoteRenderer.initialize();
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    _webRTC?.close();
    _assistUiVersion.dispose();
    super.dispose();
  }

  Future<void> _fetchMembers() async {
    setState(() => _isLoading = true);
    try {
      // Logic from UniApp: list('initiator') -> collect target users
      // Simplified: Just get list and filter
      final res = await Api.bindings.list('initiator');
      List<dynamic> list = [];
      if (res is List) {
        list = res;
      } else if (res is Map && res['list'] is List) {
        list = res['list'];
      }

      // Extract target users
      List<dynamic> members = [];
      for (var item in list) {
        if (item['targetUser'] != null) {
          members.add(item['targetUser']);
        } else if (item['targetUserInfo'] != null) {
          members.add(item['targetUserInfo']);
        }
      }

      setState(() {
        _members = members;
        if (_members.isNotEmpty) {
          _activeIndex = 0;
        } else {
          _activeIndex = -1;
        }
      });
    } catch (e) {
      print('Fetch members failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('亲情守护')),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: IntrinsicHeight(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Member List (Horizontal Scroll or Grid)
                              Container(
                                height: 100.h,
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                color: Colors.white,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _members.length + 1,
                                  itemBuilder: (context, index) {
                                    if (index == _members.length) {
                                      // Add button
                                      return GestureDetector(
                                        onTap: _showAddBindingDialog,
                                        child: Container(
                                          width: 80.w,
                                          margin: EdgeInsets.symmetric(horizontal: 10.w),
                                          child: Column(
                                            children: [
                                              CircleAvatar(
                                                radius: 30.w,
                                                backgroundColor: Colors.grey[200],
                                                child: Icon(Icons.add, size: 30.w, color: Colors.grey),
                                              ),
                                              SizedBox(height: 5.h),
                                              Text('绑定', style: TextStyle(fontSize: 12.sp)),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                    
                                    final member = _members[index];
                                    final isSelected = index == _activeIndex;
                                    final name = member['nickname'] ?? member['username'] ?? 'User ${member['id']}';
                                    final avatarUrl = member['avatar'];
                                    
                                    return GestureDetector(
                                      onTap: () => setState(() => _activeIndex = index),
                                      child: Container(
                                        width: 80.w,
                                        margin: EdgeInsets.symmetric(horizontal: 10.w),
                                        child: SizedBox(
                                          height: 84.h,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(2.w),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: isSelected ? Border.all(color: Colors.green, width: 2.w) : null,
                                                ),
                                                child: CircleAvatar(
                                                  radius: 28.w,
                                                  backgroundColor: const Color(0xFFE1BEE7),
                                                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                                      ? NetworkImage(avatarUrl)
                                                      : null,
                                                  child: avatarUrl == null || avatarUrl.isEmpty
                                                      ? const Icon(Icons.person, color: Colors.white)
                                                      : null,
                                                ),
                                              ),
                                              SizedBox(height: 8.h),
                                              Text(
                                                name,
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                  color: isSelected ? Colors.green : Colors.black,
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 12),

                              if (_members.isEmpty)
                                const Center(child: Text('尚未绑定家人'))
                              else if (_activeIndex != -1)
                                _buildDetailCard(_members[_activeIndex]),
                              const Spacer(),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }

  Widget _buildDetailCard(dynamic member) {
    return Column(
      children: [
        CommonCard(
          child: Column(
            children: [
              Text(member['nickname'] ?? member['username'] ?? '家人', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton.icon(
                  onPressed: () => _startRemoteAssist(member['id']),
                  icon: const Icon(Icons.screen_share),
                  label: const Text('远程协助'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Health Data Placeholders
        CommonCard(
          child: Column(
            children: [
              _buildHealthRow(Icons.wb_sunny, '今日天气', '7°C~18°C', const Color(0xFFFFA726)),
              SizedBox(height: 10.h),
              _buildHealthRow(Icons.bedtime, '睡眠时长', '8小时48分钟', const Color(0xFF9C27B0)),
              SizedBox(height: 10.h),
              _buildHealthRow(Icons.favorite, '血压', '收缩压: 125mmHg 舒张压: 75mmHg', const Color(0xFFEF5350)),
              SizedBox(height: 10.h),
              _buildHealthRow(Icons.favorite, '心率', '平均心率: 70次/分', const Color(0xFFE91E63)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHealthRow(IconData icon, String label, String value, Color iconColor) {
    return Row(
      children: [
        Icon(icon, size: 24.w, color: iconColor),
        SizedBox(width: 10.w),
        Text(label, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500)),
        const Spacer(),
        Flexible(child: Text(value, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.right)),
      ],
    );
  }

  void _showAddBindingDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入绑定码'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '请输入对方分享的绑定码'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                try {
                  await Api.bindings.useCode(controller.text);
                  Fluttertoast.showToast(msg: '绑定成功');
                  Navigator.pop(context);
                  _fetchMembers();
                } catch (e) {
                  Fluttertoast.showToast(msg: '绑定失败: $e');
                }
              }
            },
            child: const Text('绑定'),
          ),
        ],
      ),
    );
  }

  Future<void> _startRemoteAssist(int targetUserId) async {
    // Reset state for new session
    _webRTC?.close();
    _webRTC = WebRTCService();
    _rtcState = WebRTCConnectionState.connecting;
    _rtcStatusText = '等待家人接受...';
    _inCall = false;
    _remoteRenderer.srcObject = null;
    _bumpAssistUi();

    _openAssistDialog();

    _webRTC!.onRemoteStream = (stream) {
      _remoteRenderer.srcObject = stream;
      _inCall = true;
      _rtcStatusText = '已连接';
      _bumpAssistUi();
    };

    _webRTC!.onStateChange = (state) {
      _rtcState = state;
      switch (state) {
        case WebRTCConnectionState.connecting:
          _rtcStatusText = '连接中...';
          break;
        case WebRTCConnectionState.connected:
          _rtcStatusText = '已连接';
          break;
        case WebRTCConnectionState.failed:
          _rtcStatusText = '连接失败';
          Fluttertoast.showToast(msg: '远程协助失败，请重试');
          _stopRemoteControl(closeDialog: true);
          break;
        case WebRTCConnectionState.closed:
          _rtcStatusText = '会话已结束';
          _stopRemoteControl(closeDialog: true);
          break;
        case WebRTCConnectionState.idle:
          _rtcStatusText = '等待家人接受...';
          break;
      }
      _bumpAssistUi();
    };

    _webRTC!.onMessage = (msg) {
      if (msg is Map) {
        if (msg['type'] == 'session-accepted') {
          _rtcStatusText = '对方已同意，正在建立连接...';
          _bumpAssistUi();
        } else if (msg['type'] == 'session-rejected') {
          _rtcStatusText = '对方已拒绝';
          Fluttertoast.showToast(msg: '对方拒绝了远程协助');
          _stopRemoteControl(closeDialog: true);
        }
      }
      _bumpAssistUi();
    };

    _webRTC!.onError = (e) {
      print('[FamilyGuard] WebRTC error: $e');
      // Don't show toast for "target not connected" errors during initial connection
      if (e.toString().contains('not connected')) {
        _rtcStatusText = '等待对方接受并连接...';
      } else {
        Fluttertoast.showToast(msg: '连接错误: $e');
        _rtcStatusText = '连接错误';
        _stopRemoteControl(closeDialog: true);
      }
      _bumpAssistUi();
    };
    
    try {
      await _webRTC!.initAsViewer(targetUserId);
    } catch (e) {
      Fluttertoast.showToast(msg: '发起远程协助失败: $e');
      _stopRemoteControl(closeDialog: true);
    }
  }

  void _stopRemoteControl({bool closeDialog = false}) {
    _webRTC?.close();
    _webRTC = null;
    _remoteRenderer.srcObject = null;
    _inCall = false;
    _rtcState = WebRTCConnectionState.closed;
    _bumpAssistUi();

    if (closeDialog && _assistDialogOpen && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _sendMouseCommand(String type, TapUpDetails details) {
    if (_webRTC != null) {
      // Calculate normalized coordinates relative to screen
      final size = MediaQuery.of(context).size;
      final x = details.globalPosition.dx / size.width;
      final y = details.globalPosition.dy / size.height;

      _webRTC!.sendControlCommand('virtualClick', {'x': x, 'y': y});
    }
  }

  void _openAssistDialog() {
    if (_assistDialogOpen) return;
    _assistDialogOpen = true;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Remote Assist',
      pageBuilder: (context, animation, secondaryAnimation) {
        return ValueListenableBuilder<int>(
          valueListenable: _assistUiVersion,
          builder: (context, _, __) {
            final hasRemote = _remoteRenderer.srcObject != null;
            return Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: hasRemote
                          ? RTCVideoView(
                              _remoteRenderer,
                              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                            )
                          : Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(color: Colors.white),
                                  const SizedBox(height: 12),
                                  Text(
                                    _rtcStatusText,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    
                    // Gesture area for virtual clicks
                    if (hasRemote)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapUp: (details) => _sendMouseCommand('click', details),
                        ),
                      ),

                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sensors, color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              _rtcStatusText,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      top: 16,
                      right: 16,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: () => _stopRemoteControl(closeDialog: true),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _assistDialogOpen = false;
      _remoteRenderer.srcObject = null;
    });
  }

  void _bumpAssistUi() {
    _assistUiVersion.value++;
  }
}
