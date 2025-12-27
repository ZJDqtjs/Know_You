import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'http.dart';
import 'api.dart';
import 'webrtc_service.dart';
import 'package:fluttertoast/fluttertoast.dart';

class NotificationService extends ChangeNotifier {
  WebSocketChannel? _channel;
  static const String _wsUrl = 'ws://8.155.162.219:8084/ws';
  Timer? _reconnectTimer;
  bool _isConnected = false;
  WebRTCService? _screenSharer;

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

    print('[Notification] Connecting to $_wsUrl');
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
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
      // Start screen sharing
      _screenSharer?.close();
      _screenSharer = WebRTCService();
      _screenSharer!.onStateChange = (state) {
        if (state == WebRTCConnectionState.connected) {
          Fluttertoast.showToast(msg: '屏幕共享中');
        } else if (state == WebRTCConnectionState.closed || state == WebRTCConnectionState.failed) {
          Fluttertoast.showToast(msg: '远程协助已结束');
        }
      };
      _screenSharer!.onError = (e) {
        Fluttertoast.showToast(msg: '远程协助出错: $e');
      };

      // Wait a bit as in original code
      await Future.delayed(const Duration(seconds: 1));
      await _screenSharer!.initAsSharer(sessionId);
    } catch (e) {
      Fluttertoast.showToast(msg: '操作失败: $e');
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
}
