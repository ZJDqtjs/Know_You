import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../common/api.dart';
import '../../common/app_config.dart';
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
  Timer? _healthSyncTimer;
  
  // WebRTC
  WebRTCService? _webRTC;
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _rendererInitialized = false;
  bool _inCall = false;
  bool _virtualMouseEnabled = false;
  WebRTCConnectionState _rtcState = WebRTCConnectionState.idle;
  String _rtcStatusText = '等待家人接受...';
  bool _assistDialogOpen = false;
  final ValueNotifier<int> _assistUiVersion = ValueNotifier<int>(0);

  final Map<int, Map<String, dynamic>> _healthByUserId = {};
  final Map<int, bool> _healthLoadingByUserId = {};
  final Map<int, Map<String, dynamic>> _weatherByUserId = {};
  final Map<int, bool> _weatherLoadingByUserId = {};

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _fetchMembers();
    _startHealthAutoSync();
  }

  Future<void> _initRenderers() async {
    await _remoteRenderer.initialize();
    _rendererInitialized = true;
  }

  @override
  void dispose() {
    if (_rendererInitialized) {
      try {
        _remoteRenderer.dispose();
      } catch (e) {
        // 忽略 flutter_webrtc 在 Surface 为空时的已知崩溃
        print('RTCVideoRenderer dispose ignored: $e');
      }
    }
    _webRTC?.close();
    _assistUiVersion.dispose();
    _healthSyncTimer?.cancel();
    super.dispose();
  }

  void _startHealthAutoSync() {
    _healthSyncTimer?.cancel();
    _healthSyncTimer = Timer.periodic(const Duration(minutes: 10), (_) => _refreshActiveMemberHealth());
  }

  void _refreshActiveMemberHealth() {
    if (_activeIndex == -1 || _activeIndex >= _members.length) return;
    final memberId = _members[_activeIndex]['id'];
    if (memberId is int) {
      _loadMemberHealth(memberId);
      _loadMemberWeather(memberId);
    }
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
      if (_members.isNotEmpty) {
        final id = _members[0]['id'];
        if (id is int) {
          _loadMemberHealth(id);
          _loadMemberWeather(id);
        }
      }
    } catch (e) {
      print('Fetch members failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMemberHealth(int userId) async {
    _healthLoadingByUserId[userId] = true;
    setState(() {});
    try {
      final data = await Api.health.latest(userId);
      _healthByUserId[userId] = Map<String, dynamic>.from(data ?? {});
      _healthLoadingByUserId[userId] = false;
      _bumpAssistUi();
      if (mounted) setState(() {});
    } catch (e) {
      _healthByUserId.remove(userId);
      _healthLoadingByUserId[userId] = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadMemberWeather(int userId) async {
    _weatherLoadingByUserId[userId] = true;
    setState(() {});
    try {
      final data = await Api.weather.get(userId);
      _weatherByUserId[userId] = Map<String, dynamic>.from(data ?? {});
      _weatherLoadingByUserId[userId] = false;
      if (mounted) setState(() {});
    } catch (e) {
      _weatherByUserId.remove(userId);
      _weatherLoadingByUserId[userId] = false;
      if (mounted) setState(() {});
    }
  }

  String _formatSleepHours(dynamic hours) {
    if (hours == null) return '暂无数据';
    final h = double.tryParse(hours.toString());
    if (h == null) return '暂无数据';
    return '${h.toStringAsFixed(1)}小时';
  }

  String _formatHeartRate(dynamic hr) {
    if (hr == null) return '暂无数据';
    final v = int.tryParse(hr.toString());
    if (v == null) return '暂无数据';
    return '平均心率: ${v}次/分';
  }

  String _formatBloodPressure(dynamic bp) {
    if (bp is Map) {
      final sys = bp['systolic'];
      final dia = bp['diastolic'];
      if (sys != null || dia != null) {
        return '收缩压: ${sys ?? '--'}mmHg 舒张压: ${dia ?? '--'}mmHg';
      }
    }
    return '暂无数据';
  }

  String _formatSteps(dynamic steps) {
    if (steps == null) return '暂无数据';
    final v = int.tryParse(steps.toString());
    if (v == null) return '暂无数据';
    return '${v}步';
  }

  String _formatWeather(Map<String, dynamic>? weather) {
    if (weather == null) return '暂无数据';
    final location = weather['location'] as Map?;
    final city = location?['city']?.toString();
    final temp = weather['temperature']?.toString();
    final humidity = weather['humidity']?.toString();
    final condition = weather['condition']?.toString();
    final t = temp != null ? '${temp}°C' : '--';
    final h = humidity != null ? '湿度${humidity}%' : '湿度--';
    final c = condition ?? '未知';
    return city != null ? '$city $c $t · $h' : '$c $t · $h';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('亲情守护'),centerTitle: true),
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
                                height: 110.h,
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
                                      onTap: () {
                                        setState(() => _activeIndex = index);
                                        final id = member['id'];
                                        if (id is int) {
                                          _loadMemberHealth(id);
                                          _loadMemberWeather(id);
                                        }
                                      },
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
                                                  backgroundImage: avatarUrl != null && avatarUrl.toString().isNotEmpty
                                                      ? NetworkImage(AppConfig.currentOrDefault.resolveHttpUrl(avatarUrl.toString()))
                                                      : null,
                                                  child: avatarUrl == null || avatarUrl.toString().isEmpty
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
    final memberId = member['id'];
    final health = memberId is int ? _healthByUserId[memberId] : null;
    final loading = memberId is int ? (_healthLoadingByUserId[memberId] ?? false) : false;
    final weather = memberId is int ? _weatherByUserId[memberId] : null;
    final weatherLoading = memberId is int ? (_weatherLoadingByUserId[memberId] ?? false) : false;
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
                  icon: SvgPicture.asset(
                    'assets/images/icon-remote.svg',
                    width: 30.w,
                    height: 30.w,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                  label: Text('远程协助', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: memberId is int ? () => _loadMemberHealth(memberId) : null,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('刷新健康数据'),
                ),
              ),
            ],
          ),
        ),
        
        // Health Data Placeholders
        CommonCard(
          child: Column(
            children: [
              Row(
                children: [
                  Text('健康数据', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32))),
                  const Spacer(),
                  if (loading || weatherLoading)
                    SizedBox(width: 16.w, height: 16.w, child: const CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              SizedBox(height: 10.h),
              _buildHealthRow(Icons.wb_sunny, '今日天气', _formatWeather(weather), const Color(0xFFFFA726)),
              SizedBox(height: 10.h),
              _buildHealthRow(Icons.directions_walk, '今日步数', _formatSteps(health?['steps']), const Color(0xFF43A047)),
              SizedBox(height: 10.h),
              _buildHealthRow(Icons.bedtime, '睡眠时长', _formatSleepHours(health?['sleepHours']), const Color(0xFF9C27B0)),
              SizedBox(height: 10.h),
              _buildHealthRow(Icons.favorite, '血压', _formatBloodPressure(health?['bloodPressure']), const Color(0xFFEF5350),multilineValue:true,),
              SizedBox(height: 10.h),
              _buildHealthRow(Icons.favorite, '心率', _formatHeartRate(health?['heartRate']), const Color(0xFFE91E63)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHealthRow(IconData icon, String label, String value, Color iconColor, {bool multilineValue = false}) {
    return Row(
      children: [
        Icon(icon, size: 24.w, color: iconColor),
        SizedBox(width: 10.w),
        Text(label, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500)),
        const Spacer(),
        SizedBox(
          width: 130.w,
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: multilineValue ? 2 : 1,
            overflow: multilineValue ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14.sp, color: const Color(0xFF666666)),
          ),
        ),
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
    // Properly clean up any existing connection first
    if (_webRTC != null) {
      _webRTC!.reset();
      _webRTC = null;
    }
    
    // Create new WebRTC service instance
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
        } else if (msg['type'] == 'control') {
          final payload = msg['payload'];
          if (payload is Map && payload['command'] == 'security_blocked') {
            _rtcStatusText = '触发支付风控，协助已中断';
            Fluttertoast.showToast(msg: '检测到支付/转账风险，远程协助已自动断开');
            _stopRemoteControl(closeDialog: true);
          }
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
    if (_webRTC != null) {
      _webRTC!.reset();
      _webRTC = null;
    }
    _remoteRenderer.srcObject = null;
    _inCall = false;
    _rtcState = WebRTCConnectionState.idle;  // Reset to idle instead of closed
    _bumpAssistUi();

    if (closeDialog && _assistDialogOpen && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  // Gesture tracking for swipe detection
  Offset? _panStartPosition;
  Offset? _panCurrentPosition;
  DateTime? _panStartTime;
  
  // Key for the video container to get its size
  final GlobalKey _videoContainerKey = GlobalKey();

  void _sendClick(TapUpDetails details) {
    if (_webRTC != null) {
      // Use the video container's size for coordinate calculation
      final RenderBox? box = _videoContainerKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final size = box.size;
        final x = details.localPosition.dx / size.width;
        final y = details.localPosition.dy / size.height;
        
        print('[FamilyGuard] Sending click at ($x, $y)');
        _webRTC!.sendControlCommand('click', {'x': x, 'y': y});
      }
    }
  }

  void _onPanStart(DragStartDetails details) {
    _panStartPosition = details.localPosition;
    _panCurrentPosition = details.localPosition;
    _panStartTime = DateTime.now();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    // Track the actual current position during drag
    _panCurrentPosition = details.localPosition;
  }

  void _onPanEnd(DragEndDetails details) {
    if (_webRTC != null && _panStartPosition != null && _panCurrentPosition != null && _panStartTime != null) {
      final RenderBox? box = _videoContainerKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final size = box.size;
        final duration = DateTime.now().difference(_panStartTime!).inMilliseconds;
        
        // Use actual tracked positions instead of velocity estimation
        final startX = _panStartPosition!.dx / size.width;
        final startY = _panStartPosition!.dy / size.height;
        final endX = _panCurrentPosition!.dx / size.width;
        final endY = _panCurrentPosition!.dy / size.height;
        
        // Only send swipe if there's meaningful movement
        final distance = (_panCurrentPosition! - _panStartPosition!).distance;
        if (distance > 10) {  // Minimum swipe distance threshold
          print('[FamilyGuard] Sending swipe from ($startX, $startY) to ($endX, $endY), distance: $distance');
          _webRTC!.sendControlCommand('swipe', {
            'startX': startX.clamp(0.0, 1.0),
            'startY': startY.clamp(0.0, 1.0),
            'endX': endX.clamp(0.0, 1.0),
            'endY': endY.clamp(0.0, 1.0),
            'duration': duration.clamp(50, 800),  // Faster response
          });
        }
      }
    }
    _panStartPosition = null;
    _panCurrentPosition = null;
    _panStartTime = null;
  }

  void _sendBack() {
    if (_webRTC != null) {
      print('[FamilyGuard] Sending back command');
      _webRTC!.sendControlCommand('back', {});
    }
  }

  void _sendHome() {
    if (_webRTC != null) {
      print('[FamilyGuard] Sending home command');
      _webRTC!.sendControlCommand('home', {});
    }
  }

  void _sendRecents() {
    if (_webRTC != null) {
      print('[FamilyGuard] Sending recents command');
      _webRTC!.sendControlCommand('recents', {});
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
            final activeMember = _activeIndex != -1 ? _members[_activeIndex] : null;
            final activeMemberId = activeMember != null ? activeMember['id'] : null;
            final activeHealth = activeMemberId is int ? _healthByUserId[activeMemberId] : null;
            final activeWeather = activeMemberId is int ? _weatherByUserId[activeMemberId] : null;
            return Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(
                child: Column(
                  children: [
                    // Video area - takes most of the space but leaves room for controls
                    Expanded(
                      child: Container(
                        key: _videoContainerKey,
                        margin: const EdgeInsets.only(bottom: 8),
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
                            
                            // Gesture area for virtual clicks and swipes
                            if (hasRemote)
                              Positioned.fill(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTapUp: (details) => _sendClick(details),
                                  onPanStart: _onPanStart,
                                  onPanUpdate: _onPanUpdate,
                                  onPanEnd: _onPanEnd,
                                ),
                              ),

                            // Status indicator at top left
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      hasRemote ? Icons.sensors : Icons.sensors_off,
                                      color: hasRemote ? Colors.greenAccent : Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _rtcStatusText,
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Health info at top right
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('健康信息', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text(_formatHeartRate(activeHealth?['heartRate']), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                    Text(_formatBloodPressure(activeHealth?['bloodPressure']), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                    Text('睡眠: ${_formatSleepHours(activeHealth?['sleepHours'])}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                    Text(_formatWeather(activeWeather), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Bottom control bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNavButton(Icons.arrow_back_ios_rounded, '返回', _sendBack),
                          _buildNavButton(Icons.circle_outlined, '主页', _sendHome),
                          _buildNavButton(Icons.crop_square_rounded, '最近', _sendRecents),
                          _buildNavButton(Icons.close, '退出', () => _stopRemoteControl(closeDialog: true), isExit: true),
                        ],
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

  Widget _buildNavButton(IconData icon, String label, VoidCallback onPressed, {bool isExit = false}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isExit ? Colors.red.withOpacity(0.2) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isExit ? Colors.redAccent : Colors.white, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isExit ? Colors.redAccent : Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(IconData icon, String label, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
