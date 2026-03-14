import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 无障碍保活方式
enum KeepAliveMethod {
  none,       // 不保活
  shizuku,    // Shizuku 方式
  wirelessAdb // 无线调试方式
}

/// Shizuku 服务管理
/// 
/// 核心原理（参考 GKD 项目）：
/// 1. 通过 Shizuku 的 IPackageManager 接口授予应用 WRITE_SECURE_SETTINGS 权限
/// 2. 获得权限后，应用可直接修改 Settings.Secure 来启用/禁用无障碍服务
class ShizukuService extends ChangeNotifier with WidgetsBindingObserver {
  static final ShizukuService _instance = ShizukuService._internal();
  factory ShizukuService() => _instance;
  ShizukuService._internal();

  static const _channel = MethodChannel('com.example.know_you/shizuku');
  static const _prefsKey = 'keep_alive_method';
  
  bool _isInitialized = false;
  bool _isShizukuInstalled = false;
  bool _isShizukuRunning = false;
  bool _hasShizukuPermission = false;
  bool _hasWriteSecureSettings = false;
  bool _isAccessibilityEnabled = false;
  KeepAliveMethod _keepAliveMethod = KeepAliveMethod.none;
  
  Timer? _keepAliveTimer;
  DateTime? _lastReenableTime;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isShizukuInstalled => _isShizukuInstalled;
  bool get isShizukuRunning => _isShizukuRunning;
  bool get hasShizukuPermission => _hasShizukuPermission;
  bool get hasWriteSecureSettings => _hasWriteSecureSettings;
  bool get isAccessibilityEnabled => _isAccessibilityEnabled;
  KeepAliveMethod get keepAliveMethod => _keepAliveMethod;
  
  /// 初始化服务
  Future<void> init() async {
    if (_isInitialized) return;
    
    // 添加生命周期监听
    WidgetsBinding.instance.addObserver(this);
    
    // 加载保存的设置
    final prefs = await SharedPreferences.getInstance();
    final methodIndex = prefs.getInt(_prefsKey) ?? 0;
    _keepAliveMethod = KeepAliveMethod.values[methodIndex];
    
    // 设置原生回调
    _channel.setMethodCallHandler(_handleNativeCall);
    
    // 初始化 Shizuku 监听器
    try {
      await _channel.invokeMethod('initShizukuListeners');
    } catch (e) {
      print('Failed to init Shizuku listeners: $e');
    }
    
    // 获取初始状态
    await refreshStatus();
    
    // 如果选择了 Shizuku 保活且 Shizuku 可用，尝试自动启用
    if (_keepAliveMethod == KeepAliveMethod.shizuku && isShizukuAvailable) {
      if (!_isAccessibilityEnabled) {
        print('[Shizuku] 尝试自动启用无障碍服务...');
        await enableAccessibilityViaShizuku();
      }
      _startKeepAliveTimer();
    } else if (_keepAliveMethod != KeepAliveMethod.none) {
      _startKeepAliveTimer();
    }
    
    _isInitialized = true;
    notifyListeners();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // 当应用从后台回到前台时，检查无障碍服务状态
    if (state == AppLifecycleState.resumed) {
      print('App resumed, checking accessibility status...');
      Future.delayed(const Duration(milliseconds: 500), () async {
        await refreshStatus();
        // 如果无障碍服务被关闭了，尝试自动重新启用
        if (!_isAccessibilityEnabled && _keepAliveMethod == KeepAliveMethod.shizuku && isShizukuAvailable) {
          print('[Shizuku] 检测到无障碍服务未启用，尝试自动启用...');
          await enableAccessibilityViaShizuku();
        }
      });
    }
  }
  
  /// 处理原生回调
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onShizukuBinderReceived':
        _isShizukuRunning = true;
        await refreshStatus();
        notifyListeners();
        break;
      case 'onShizukuBinderDead':
        _isShizukuRunning = false;
        _hasShizukuPermission = false;
        notifyListeners();
        break;
      case 'onShizukuPermissionResult':
        final granted = call.arguments['granted'] as bool;
        _hasShizukuPermission = granted;
        if (granted && _keepAliveMethod == KeepAliveMethod.shizuku) {
          await enableAccessibilityViaShizuku();
        }
        notifyListeners();
        break;
    }
    return null;
  }
  
  /// 刷新状态
  Future<void> refreshStatus() async {
    try {
      final status = await _channel.invokeMethod<Map>('getShizukuStatus');
      if (status != null) {
        final wasEnabled = _isAccessibilityEnabled;
        _isShizukuInstalled = status['installed'] as bool? ?? false;
        _isShizukuRunning = status['running'] as bool? ?? false;
        _hasShizukuPermission = status['hasPermission'] as bool? ?? false;
        _hasWriteSecureSettings = status['hasWriteSecureSettings'] as bool? ?? false;
        _isAccessibilityEnabled = status['accessibilityEnabled'] as bool? ?? false;
        
        // 如果无障碍服务从启用变为未启用，且已设置保活，尝试自动重启
        if (wasEnabled && !_isAccessibilityEnabled && _keepAliveMethod == KeepAliveMethod.shizuku) {
          print('Accessibility service was disabled, attempting to re-enable...');
          await _autoReenableAccessibility();
        }
      }
      notifyListeners();
    } catch (e) {
      print('Failed to get Shizuku status: $e');
    }
  }
  
  /// 自动重新启用无障碍服务
  Future<void> _autoReenableAccessibility() async {
    if (_keepAliveMethod != KeepAliveMethod.shizuku || !isShizukuAvailable) {
      return;
    }
    
    // 避免短时间内重复重启（30秒内只重启一次）
    if (_lastReenableTime != null && 
        DateTime.now().difference(_lastReenableTime!) < const Duration(seconds: 30)) {
      print('Too soon to re-enable, skipping');
      return;
    }
    
    try {
      print('Auto re-enabling accessibility service via Shizuku');
      final result = await enableAccessibilityViaShizuku();
      if (result) {
        _lastReenableTime = DateTime.now();
        print('Accessibility service re-enabled successfully');
        notifyListeners();
      } else {
        print('Failed to re-enable accessibility service');
      }
    } catch (e) {
      print('Error auto re-enabling accessibility: $e');
    }
  }
  
  /// 检查 Shizuku 是否可用
  bool get isShizukuAvailable => _isShizukuInstalled && _isShizukuRunning && _hasShizukuPermission;
  
  /// 请求 Shizuku 权限
  Future<void> requestShizukuPermission() async {
    try {
      await _channel.invokeMethod('requestShizukuPermission');
    } catch (e) {
      print('Failed to request Shizuku permission: $e');
    }
  }
  
  /// 通过 Shizuku 启用无障碍服务
  Future<bool> enableAccessibilityViaShizuku() async {
    try {
      final result = await _channel.invokeMethod<bool>('enableAccessibilityViaShizuku');
      if (result == true) {
        _isAccessibilityEnabled = true;
        // 等待一下让系统更新状态
        await Future.delayed(const Duration(milliseconds: 500));
        await refreshStatus();
        notifyListeners();
      }
      return result ?? false;
    } catch (e) {
      print('Failed to enable accessibility via Shizuku: $e');
      return false;
    }
  }
  
  /// 重启无障碍服务（用于修复异常状态）
  Future<bool> restartAccessibilityService() async {
    if (!isShizukuAvailable) return false;
    
    try {
      final result = await _channel.invokeMethod<bool>('restartAccessibilityService');
      await refreshStatus();
      return result ?? false;
    } catch (e) {
      print('Failed to restart accessibility service: $e');
      return false;
    }
  }
  
  /// 通过 Shizuku 授予 WRITE_SECURE_SETTINGS 权限
  Future<bool> grantWriteSecureSettings() async {
    if (!hasShizukuPermission) return false;
    
    try {
      final result = await _channel.invokeMethod<bool>('grantWriteSecureSettings');
      if (result == true) {
        _hasWriteSecureSettings = true;
        notifyListeners();
      }
      return result ?? false;
    } catch (e) {
      print('Failed to grant WRITE_SECURE_SETTINGS: $e');
      return false;
    }
  }
  
  /// 保活无障碍服务
  Future<bool> keepAccessibilityAlive() async {
    if (_keepAliveMethod != KeepAliveMethod.shizuku || !isShizukuAvailable) {
      return false;
    }
    
    try {
      final result = await _channel.invokeMethod<bool>('keepAccessibilityAlive');
      await refreshStatus();
      return result ?? false;
    } catch (e) {
      print('Failed to keep accessibility alive: $e');
      return false;
    }
  }
  
  /// 打开 Shizuku 应用
  Future<bool> openShizukuApp() async {
    try {
      final result = await _channel.invokeMethod<bool>('openShizukuApp');
      return result ?? false;
    } catch (e) {
      print('Failed to open Shizuku app: $e');
      return false;
    }
  }
  
  /// 打开 Shizuku 下载页面
  Future<void> openShizukuDownload() async {
    try {
      await _channel.invokeMethod('openShizukuDownload');
    } catch (e) {
      print('Failed to open Shizuku download: $e');
    }
  }
  
  /// 获取无线调试指南
  Future<Map<String, String>?> getWirelessDebugGuide() async {
    try {
      final result = await _channel.invokeMethod<Map>('getWirelessDebugGuide');
      return result?.cast<String, String>();
    } catch (e) {
      print('Failed to get wireless debug guide: $e');
      return null;
    }
  }
  
  /// 获取 ADB 命令
  Future<String?> getAdbCommand() async {
    try {
      return await _channel.invokeMethod<String>('getAdbCommand');
    } catch (e) {
      print('Failed to get ADB command: $e');
      return null;
    }
  }
  
  /// 设置保活方式
  Future<void> setKeepAliveMethod(KeepAliveMethod method) async {
    _keepAliveMethod = method;
    
    // 保存设置
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, method.index);
    
    // 根据方式启动或停止保活
    if (method == KeepAliveMethod.shizuku) {
      _startKeepAliveTimer();
      // 使用 GKD 方法：通过 Shizuku 授予 WRITE_SECURE_SETTINGS 权限
      if (isShizukuAvailable) {
        print('[Shizuku] 已选择 Shizuku 保活方式，尝试启用无障碍服务...');
        await enableAccessibilityViaShizuku();
      }
    } else if (method == KeepAliveMethod.wirelessAdb) {
      _startKeepAliveTimer();
    } else {
      _stopKeepAliveTimer();
    }
    
    notifyListeners();
  }
  
  /// 启动保活定时器
  void _startKeepAliveTimer() {
    _stopKeepAliveTimer();
    // 每 30 秒检查一次
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await refreshStatus();
      // 如果无障碍服务被关闭了，尝试自动重新启用
      if (!_isAccessibilityEnabled && _keepAliveMethod == KeepAliveMethod.shizuku && isShizukuAvailable) {
        print('[Shizuku] 定时检测到无障碍服务未启用，尝试自动启用...');
        await _autoReenableAccessibility();
      }
      await keepAccessibilityAlive(); // 调用原生方法检查
    });
    
    // 立即执行一次检查
    Future.delayed(const Duration(seconds: 2), () async {
      await refreshStatus();
      // 如果无障碍服务未启用，尝试启用
      if (!_isAccessibilityEnabled && _keepAliveMethod == KeepAliveMethod.shizuku && isShizukuAvailable) {
        print('[Shizuku] 检测到无障碍服务未启用，尝试自动启用...');
        await enableAccessibilityViaShizuku();
      }
    });
  }
  
  /// 停止保活定时器
  void _stopKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }
  
  /// 执行本地 ADB 命令
  Future<Map<String, dynamic>> executeShellCommand(String command) async {
    try {
      final result = await _channel.invokeMethod('executeShellCommand', {
        'command': command,
      });
      // The native side returns mapOf("success" to success, "output" to output)
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      print('Failed to execute command: $e');
      return {
        'success': false,
        'output': e.toString(),
      };
    }
  }

  /// 释放资源
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopKeepAliveTimer();
    _channel.invokeMethod('removeShizukuListeners');
    super.dispose();
  }
}
