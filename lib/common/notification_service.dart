import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'webrtc_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'app_config.dart';

class NotificationService extends ChangeNotifier {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _riskMonitorTimer;
  bool _isConnected = false;
  bool _riskBlocked = false;
  WebRTCService? _screenSharer;
  
  // Method channel for accessibility service control
  static const MethodChannel _accessibilityChannel = MethodChannel('com.example.know_you/accessibility');

  static const Set<String> _highRiskActivities = {
    'com.tencent.mm.plugin.mall.ui.MallIndexUIv2',
    'com.tencent.mm.framework.app.UIPageFragmentActivity',
    'com.alipay.mobile.nebulax.xriver.activity.XRiverActivity',
    'com.alipay.mobile.transferapp.ui.TFToAccountConfirmMainActivityNew',
    'com.alipay.mobile.transferapp.ui.TFToCardFormCubeActivity',
  };

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();
  
  // Use a global navigator key to show dialogs from service
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  void connect() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_access_token');
    
    if (token == null || token.isEmpty) {
      print('[Notification] No token, skipping connection');
      return;
    }

    if (_isConnected) return;

    final wsUrl = (await AppConfig.load()).wsUrl;

    print('[Notification] Connecting to $wsUrl');
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;

      _channel!.stream.listen((message) {
        _onMessage(message);
      }, onDone: () {
        print('[Notification] Closed');
        _isConnected = false;
        _scheduleReconnect();
      }, onError: (error) {
        print('[Notification] Error: $error');
        _isConnected = false;
      });
      
      // Wait a bit for connection to open then authenticate
      // WebSocketChannel doesn't have onOpen callback easily accessible in all implementations, 
      // but usually the stream starts immediately.
      // However, we need to send auth message.
      Future.delayed(const Duration(milliseconds: 500), () {
        _authenticate(token);
      });

    } catch (e) {
      print('[Notification] Connection failed: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      connect();
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _stopRiskMonitor();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _screenSharer?.close();
    _screenSharer = null;
  }

  void _authenticate(String token) {
    if (_channel != null) {
      final authMsg = {
        'action': 'auth',
        'token': token
      };
      _channel!.sink.add(jsonEncode(authMsg));
    }
  }

  void _onMessage(dynamic data) {
    if (data is String) {
      try {
        final message = jsonDecode(data);
        final type = message['type'];
        final payload = message['data'];

        print('[Notification] Received: $type');

        switch (type) {
          case 'auth_success':
            print('[Notification] Auth success: ${payload['userId']}');
            break;
          case 'auth_failed':
            print('[Notification] Auth failed');
            break;
          case 'screen_session_request':
            _handleScreenSessionRequest(payload);
            break;
          case 'binding_request':
            _handleBindingRequest(payload);
            break;
          case 'echo':
            print('[Notification] Echo: $payload');
            break;
        }
      } catch (e) {
        print('[Notification] Parse error: $e');
      }
    }
  }

  void _handleScreenSessionRequest(dynamic data) {
    final sessionId = data['sessionId'];
    final initiatorUser = data['initiatorUser'];
    final initiatorUserId = data['initiatorUserId'];
    final displayName = initiatorUser?['nickname'] ?? initiatorUser?['username'] ?? 'User $initiatorUserId';

    showDialog(
      context: navigatorKey.currentContext!,
      builder: (context) => AlertDialog(
        title: const Text('远程协助请求'),
        content: Text('$displayName 请求远程协助您的设备'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectScreenSession(sessionId);
            },
            child: const Text('拒绝'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _acceptScreenSession(sessionId);
            },
            child: const Text('同意'),
          ),
        ],
      ),
    );
  }

  void _handleBindingRequest(dynamic data) {
    final bindingId = data['bindingId'];
    final initiatorUser = data['initiatorUser'];
    final initiatorUserId = data['initiatorUserId'];
    final displayName = initiatorUser?['nickname'] ?? initiatorUser?['username'] ?? 'User $initiatorUserId';

    showDialog(
      context: navigatorKey.currentContext!,
      builder: (context) => AlertDialog(
        title: const Text('绑定请求'),
        content: Text('$displayName 请求与您建立亲情守护关系'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectBinding(bindingId);
            },
            child: const Text('拒绝'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _acceptBinding(bindingId);
            },
            child: const Text('同意'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptScreenSession(String sessionId) async {
    try {
      await Api.screen.accept(sessionId);
      // Some backends require an explicit remote-start to notify target to begin screen share
      try {
        await Api.screen.remoteStart(sessionId);
      } catch (_) {
        // If not required/available, ignore
      }
      Fluttertoast.showToast(msg: '已同意远程协助');
      
      // Check if accessibility service is enabled for remote control
      if (Platform.isAndroid) {
        try {
          final isEnabled = await _accessibilityChannel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
          if (!isEnabled) {
            // Show dialog to enable accessibility service
            _showAccessibilityDialog();
          }
        } catch (e) {
          print('[NotificationService] Error checking accessibility: $e');
        }
      }
      
      // Properly clean up existing screen sharer
      if (_screenSharer != null) {
        _screenSharer!.reset();
        _screenSharer = null;
      }
      
      // Start screen sharing
      _screenSharer = WebRTCService();
      _screenSharer!.onStateChange = (state) {
        if (state == WebRTCConnectionState.connected) {
          Fluttertoast.showToast(msg: '屏幕共享中');
          _startRiskMonitor();
        } else if (state == WebRTCConnectionState.closed || state == WebRTCConnectionState.failed) {
          _stopRiskMonitor();
          Fluttertoast.showToast(msg: '远程协助已结束');
          // Clean up when session ends
          _screenSharer?.reset();
          _screenSharer = null;
        }
      };
      _screenSharer!.onError = (e) {
        _stopRiskMonitor();
        Fluttertoast.showToast(msg: '远程协助出错: $e');
        // Clean up on error
        _screenSharer?.reset();
        _screenSharer = null;
      };
      
      // Handle control commands from the controller
      _screenSharer!.onControlCommand = (payload) {
        _handleControlCommand(payload);
      };

      // Wait a bit as in original code
      await Future.delayed(const Duration(seconds: 1));
      await _screenSharer!.initAsSharer(sessionId);
    } catch (e) {
      _stopRiskMonitor();
      Fluttertoast.showToast(msg: '操作失败: $e');
      // Clean up on exception
      _screenSharer?.reset();
      _screenSharer = null;
    }
  }

  void _startRiskMonitor() {
    if (!Platform.isAndroid || _screenSharer == null) return;
    _riskBlocked = false;
    _riskMonitorTimer?.cancel();
    _riskMonitorTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      _checkRiskAndBlock();
    });
  }

  void _stopRiskMonitor() {
    _riskMonitorTimer?.cancel();
    _riskMonitorTimer = null;
    _riskBlocked = false;
  }

  Future<void> _checkRiskAndBlock() async {
    if (!Platform.isAndroid || _screenSharer == null || _riskBlocked) return;

    try {
      final pkg = await _accessibilityChannel.invokeMethod<String>('getForegroundPackage');
      final packageName = (pkg ?? '').trim();
      final topActivityRaw = await _accessibilityChannel.invokeMethod<String>('getTopActivity') ?? '';
      print('[NotificationService] risk-check pkg=$packageName top=$topActivityRaw');

      final matchedActivity = _matchHighRiskActivity(topActivityRaw);
      if (matchedActivity != null) {
        print('[NotificationService] risk-hit activity=$matchedActivity');
        await _triggerRiskBlock(
          reason: 'high_risk_activity:$matchedActivity',
          packageName: _resolveTargetPackage(
            foregroundPackage: packageName,
            matchedActivity: matchedActivity,
          ),
        );
      }
    } catch (e) {
      print('[NotificationService] Risk monitor error: $e');
    }
  }

  String? _matchHighRiskActivity(String source) {
    final components = _extractActivityComponents(source);
    for (final component in components) {
      if (_highRiskActivities.contains(component)) return component;
      for (final activity in _highRiskActivities) {
        if (component.endsWith(activity)) {
          return activity;
        }
      }
    }
    return null;
  }

  List<String> _extractActivityComponents(String source) {
    final result = <String>{};

    final fullPattern = RegExp(r'([a-zA-Z0-9_]+(?:\.[a-zA-Z0-9_]+)+)/(\.[a-zA-Z0-9_$.]+|[a-zA-Z0-9_$.]+)');
    for (final m in fullPattern.allMatches(source)) {
      final pkg = m.group(1) ?? '';
      final clsRaw = m.group(2) ?? '';
      if (pkg.isEmpty || clsRaw.isEmpty) continue;
      final fullCls = clsRaw.startsWith('.') ? '$pkg$clsRaw' : clsRaw;
      result.add(fullCls);
      result.add('$pkg/$clsRaw');
      result.add('$pkg/$fullCls');
    }

    final classPattern = RegExp(r'[a-zA-Z0-9_]+(?:\.[a-zA-Z0-9_]+){2,}');
    for (final m in classPattern.allMatches(source)) {
      final token = m.group(0);
      if (token != null) result.add(token);
    }

    return result.toList();
  }

  String? _resolveTargetPackage({
    required String foregroundPackage,
    required String matchedActivity,
  }) {
    final canonical = _highRiskActivities.firstWhere(
      (activity) => activity == matchedActivity || activity.endsWith(matchedActivity),
      orElse: () => matchedActivity,
    );

    if (canonical.startsWith('com.tencent.mm.')) {
      return 'com.tencent.mm';
    }
    if (canonical.startsWith('com.alipay.mobile.')) {
      return 'com.eg.android.AlipayGphone';
    }

    if (foregroundPackage.isNotEmpty && foregroundPackage != 'com.example.know_you') {
      return foregroundPackage;
    }
    return null;
  }

  Future<void> _triggerRiskBlock({required String reason, String? packageName}) async {
    if (_riskBlocked) return;
    _riskBlocked = true;
    _riskMonitorTimer?.cancel();

    Fluttertoast.showToast(msg: '检测到支付/转账风险，已自动中断远程协助');

    try {
      await _performHome();
      await Future.delayed(const Duration(milliseconds: 200));
      await _performRecents();
      await Future.delayed(const Duration(milliseconds: 200));

      if (packageName != null && packageName.isNotEmpty) {
        final result = await _accessibilityChannel.invokeMethod<dynamic>('forceStopPackage', {
          'packageName': packageName,
        });
        print('[NotificationService] forceStopPackage($packageName): $result');
      }

      _screenSharer?.sendControlCommand('security_blocked', {
        'reason': reason,
        'packageName': packageName,
        'time': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('[NotificationService] Trigger risk block error: $e');
    } finally {
      await _screenSharer?.close();
      _screenSharer?.reset();
      _screenSharer = null;
      _riskBlocked = false;
    }
  }
  
  void _handleControlCommand(dynamic payload) {
    if (payload == null) return;
    
    final command = payload['command'];
    final data = payload['payload'] ?? {};
    
    print('[NotificationService] Received control command: $command, data: $data');
    
    switch (command) {
      case 'virtualClick':
      case 'click':
        final x = (data['x'] as num?)?.toDouble() ?? 0.0;
        final y = (data['y'] as num?)?.toDouble() ?? 0.0;
        _performClick(x, y);
        break;
      case 'swipe':
        final startX = (data['startX'] as num?)?.toDouble() ?? 0.0;
        final startY = (data['startY'] as num?)?.toDouble() ?? 0.0;
        final endX = (data['endX'] as num?)?.toDouble() ?? 0.0;
        final endY = (data['endY'] as num?)?.toDouble() ?? 0.0;
        final duration = (data['duration'] as num?)?.toInt() ?? 300;
        _performSwipe(startX, startY, endX, endY, duration);
        break;
      case 'scroll':
        final x = (data['x'] as num?)?.toDouble() ?? 0.5;
        final y = (data['y'] as num?)?.toDouble() ?? 0.5;
        final deltaX = (data['deltaX'] as num?)?.toDouble() ?? 0.0;
        final deltaY = (data['deltaY'] as num?)?.toDouble() ?? 0.0;
        _performScroll(x, y, deltaX, deltaY);
        break;
      case 'back':
        _performBack();
        break;
      case 'home':
        _performHome();
        break;
      case 'recents':
        _performRecents();
        break;
      default:
        print('[NotificationService] Unknown control command: $command');
    }
  }
  
  Future<void> _performClick(double x, double y) async {
    if (!Platform.isAndroid) return;
    
    try {
      await _accessibilityChannel.invokeMethod('click', {'x': x, 'y': y});
      print('[NotificationService] Click performed at ($x, $y)');
    } catch (e) {
      print('[NotificationService] Click failed: $e');
      // Fallback: show a toast indicating the action
      // In a real implementation, this would require AccessibilityService
    }
  }
  
  Future<void> _performSwipe(double startX, double startY, double endX, double endY, int duration) async {
    if (!Platform.isAndroid) return;
    
    try {
      await _accessibilityChannel.invokeMethod('swipe', {
        'startX': startX,
        'startY': startY,
        'endX': endX,
        'endY': endY,
        'duration': duration,
      });
      print('[NotificationService] Swipe performed from ($startX, $startY) to ($endX, $endY)');
    } catch (e) {
      print('[NotificationService] Swipe failed: $e');
    }
  }
  
  Future<void> _performScroll(double x, double y, double deltaX, double deltaY) async {
    if (!Platform.isAndroid) return;
    
    try {
      // Convert scroll delta to swipe gesture
      final startX = x;
      final startY = y;
      final endX = x - deltaX * 0.5; // Scale down for reasonable scroll distance
      final endY = y - deltaY * 0.5;
      
      await _accessibilityChannel.invokeMethod('swipe', {
        'startX': startX,
        'startY': startY,
        'endX': endX,
        'endY': endY,
        'duration': 200,
      });
      print('[NotificationService] Scroll performed at ($x, $y) with delta ($deltaX, $deltaY)');
    } catch (e) {
      print('[NotificationService] Scroll failed: $e');
    }
  }
  
  Future<void> _performBack() async {
    if (!Platform.isAndroid) return;
    
    try {
      await _accessibilityChannel.invokeMethod('back');
      print('[NotificationService] Back performed');
    } catch (e) {
      print('[NotificationService] Back failed: $e');
    }
  }
  
  Future<void> _performHome() async {
    if (!Platform.isAndroid) return;
    
    try {
      await _accessibilityChannel.invokeMethod('home');
      print('[NotificationService] Home performed');
    } catch (e) {
      print('[NotificationService] Home failed: $e');
    }
  }
  
  Future<void> _performRecents() async {
    if (!Platform.isAndroid) return;
    
    try {
      await _accessibilityChannel.invokeMethod('recents');
      print('[NotificationService] Recents performed');
    } catch (e) {
      print('[NotificationService] Recents failed: $e');
    }
  }

  Future<void> _rejectScreenSession(String sessionId) async {
    try {
      await Api.screen.reject(sessionId);
      Fluttertoast.showToast(msg: '已拒绝远程协助');
    } catch (e) {
      print('Reject failed: $e');
    }
  }

  Future<void> _acceptBinding(int bindingId) async {
    try {
      await Api.bindings.accept(bindingId);
      Fluttertoast.showToast(msg: '已同意绑定');
    } catch (e) {
      Fluttertoast.showToast(msg: '操作失败: $e');
    }
  }

  Future<void> _rejectBinding(int bindingId) async {
    try {
      await Api.bindings.reject(bindingId);
      Fluttertoast.showToast(msg: '已拒绝绑定');
    } catch (e) {
      print('Reject binding failed: $e');
    }
  }
  
  void _showAccessibilityDialog() {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要开启无障碍服务'),
        content: const Text(
          '要启用远程控制功能（点击、滑动等），需要开启无障碍服务。\n\n'
          '请在设置中找到"Know You"并开启无障碍服务。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _accessibilityChannel.invokeMethod('openAccessibilitySettings');
              } catch (e) {
                print('[NotificationService] Open settings failed: $e');
              }
            },
            child: const Text('去开启'),
          ),
        ],
      ),
    );
  }
}
