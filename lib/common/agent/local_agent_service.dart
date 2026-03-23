import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../shizuku_service.dart';
import '../app_config.dart';

/// 飞言本地 Agent 服务（Shizuku 驱动）
class LocalAgentService {
  static final LocalAgentService _instance = LocalAgentService._internal();

  factory LocalAgentService() => _instance;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.currentOrDefault.agentApiUrl ?? AppConfig.currentOrDefault.apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    headers: {
      if ((AppConfig.currentOrDefault.agentServerToken ?? '').isNotEmpty)
        'x-server-token': AppConfig.currentOrDefault.agentServerToken,
    },
  ));

  LocalAgentService._internal();

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  String? _sessionId;
  
  /// 取消令牌，用于手动中断流程
  CancelToken? _cancelToken;

  /// 回调：用于向 UI 更新状态和日志
  Function(String text)? onLog;
  Function(bool running)? onStateChange;
  Function(bool capturing)? onCaptureStateChange;

  static const _adbKeyboardImeId = 'com.android.adbkeyboard/.AdbIME';
  String? _originalIme;

  void _log(String text) {
    print('[LocalAgent] $text');
    onLog?.call(text);
  }

  /// 启动一次独立 Agent 任务
  Future<void> runTask(String task, {required String userId}) async {
    if (_isRunning) {
      _log('任务正在运行中，请勿重复启动');
      return;
    }

    _isRunning = true;
    onStateChange?.call(true);
    _cancelToken = CancelToken();
    _sessionId = null;
    Map<String, dynamic>? previousResult;

    try {
      _log('开始执行任务: $task');
      await _ensureAdbKeyboardReady();

      while (!_cancelToken!.isCancelled) {
        // 1. 获取屏幕状态
        onCaptureStateChange?.call(true);
        await Future.delayed(const Duration(milliseconds: 120));
        final screenshotBase64 = await _captureScreenBase64();
        onCaptureStateChange?.call(false);
        final currentApp = await _detectCurrentApp();
        final size = await _getScreenSize();

        if (screenshotBase64 == null) {
          _log('无法截取屏幕，任务中止');
          break;
        }

        // 2. 组装请求体
        final body = {
          'user_id': userId,
          if (_sessionId == null) 'task': task,
          if (_sessionId != null) 'session_id': _sessionId,
          'screenshot_base64': screenshotBase64,
          'current_app': currentApp,
          'screen_width': size.width.round(),
          'screen_height': size.height.round(),
          if (previousResult != null) 'previous_step_result': previousResult,
        };

        // 3. 请求云端 API 获取下一步
        _log('正在请求下一步指令...');
        final resp = await _dio.post('/v1/local/next', data: body, cancelToken: _cancelToken);
        
        final data = resp.data as Map<String, dynamic>;
        _sessionId = data['session_id'] as String?;
        
        final message = data['message'];
        final thinking = data['thinking'];
        if (thinking != null) {
          _log('Agent思考: $thinking');
        }

        if (data['finished'] == true) {
          _log('任务完成: $message');
          break;
        }

        final packet = data['command_packet'] as Map<String, dynamic>?;
        if (packet == null) {
          _log('未收到 command_packet，退出');
          break;
        }

        final exec = packet['execution'] as Map<String, dynamic>;
        
        // 4. 利用 Shizuku 在本地设备执行 ADB 指令
        _log('开始执行本地指令...');
        previousResult = await _executePacketViaShizuku(exec);

        if (!(previousResult['ok'] as bool)) {
          _log('命令执行出现错误，尝试回传模型纠错...');
        }
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        _log('由于手动取消导致结束');
      } else {
        _log('出现异常: $e');
      }
    } catch (e) {
      _log('出现异常: $e');
    } finally {
      onCaptureStateChange?.call(false);
      await _restoreInputMethod();
      _isRunning = false;
      onStateChange?.call(false);
    }
  }

  /// 停止任务
  Future<void> stopTask() async {
    if (_isRunning) {
      _log('正在停止任务...');
      _cancelToken?.cancel();
      // 调用清理接口
      if (_sessionId != null) {
        try {
          await _dio.post('/v1/local/reset', data: {'session_id': _sessionId});
        } catch (e) {
          print('Reset API failed: $e');
        }
      }
    }
  }

  Future<void> _ensureAdbKeyboardReady() async {
    try {
      final currentImeRes = await ShizukuService().executeShellCommand('settings get secure default_input_method');
      if (currentImeRes['success'] == true) {
        final currentIme = (currentImeRes['output'] ?? '').toString().trim();
        if (currentIme.isNotEmpty) {
          _originalIme = currentIme;
        }
      }

      final pkgRes = await ShizukuService().executeShellCommand('pm path com.android.adbkeyboard');
      final output = (pkgRes['output'] ?? '').toString();
      final installed = pkgRes['success'] == true && output.contains('package:');
      if (!installed) {
        _log('未检测到ADBKeyBoard（com.android.adbkeyboard），请先安装并启用');
        return;
      }

      await ShizukuService().executeShellCommand('ime enable $_adbKeyboardImeId');
      final setRes = await ShizukuService().executeShellCommand('ime set $_adbKeyboardImeId');
      if (setRes['success'] == true) {
        _log('已切换到ADBKeyBoard输入法');
      } else {
        _log('ADBKeyBoard启用失败，请在系统中手动启用输入法');
      }
    } catch (e) {
      _log('检查ADBKeyBoard失败: $e');
    }
  }

  Future<void> _restoreInputMethod() async {
    final ime = _originalIme;
    if (ime == null || ime.isEmpty || ime == _adbKeyboardImeId) return;
    try {
      await ShizukuService().executeShellCommand('ime set $ime');
    } catch (_) {
      // ignore restore failure
    }
  }

  /// 通过 Shizuku 截屏并回传 Base64
  Future<String?> _captureScreenBase64() async {
    final res = await ShizukuService().executeShellCommand('screencap -p | base64');
    if (res['success'] == true) {
      String b64 = res['output'] as String;
      // 需要把换行符等替换掉
      b64 = b64.replaceAll(RegExp(r'\s+'), '');
      return b64.isNotEmpty ? b64 : null;
    }
    return null;
  }

  /// 检测当前活跃 App 包名
  Future<String> _detectCurrentApp() async {
    final res = await ShizukuService().executeShellCommand('dumpsys window | grep mCurrentFocus');
    if (res['success'] == true) {
      final output = res['output'] as String;
      // e.g. "  mCurrentFocus=Window{a1b2c3d u0 com.tencent.mm/com.tencent.mm.ui.LauncherUI}"
      final match = RegExp(r'u0\s+([^/]+)/').firstMatch(output);
      if (match != null) {
        return match.group(1) ?? 'Unknown';
      }
    }
    return 'System Home';
  }

  /// 获取屏幕尺寸 (物理像素)
  Future<Size> _getScreenSize() async {
    final res = await ShizukuService().executeShellCommand('wm size');
    if (res['success'] == true) {
      final output = res['output'] as String;
      // e.g. "Physical size: 1080x2400"
      final match = RegExp(r'(\d+)x(\d+)').firstMatch(output);
      if (match != null) {
        return Size(
          double.parse(match.group(1)!),
          double.parse(match.group(2)!),
        );
      }
    }
    // Fallback 到 Flutter 逻辑屏幕
    final physicalSize = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
    return physicalSize;
  }

  /// 执行指令包并收集结果
  Future<Map<String, dynamic>> _executePacketViaShizuku(Map<String, dynamic> exec) async {
    bool overallOk = true;
    final executedAt = DateTime.now().millisecondsSinceEpoch;
    final List<Map<String, dynamic>> commandResults = [];
    final List<Map<String, dynamic>> clientResults = [];

    // 1. 执行命令
    final commands = exec['commands'] as List<dynamic>? ?? [];
    for (final cmdObj in commands) {
      final cmd = cmdObj as Map<String, dynamic>;
      final commandId = cmd['command_id'];
      final String adbCommand = cmd['command'];
      final bool captureOutput = cmd['capture_output'] ?? false;
      final int delayMsAfter = cmd['delay_ms_after'] ?? 0;

      final start = DateTime.now().millisecondsSinceEpoch;
      // 利用 ShizukuService
      final res = await ShizukuService().executeShellCommand(adbCommand);
      final duration = DateTime.now().millisecondsSinceEpoch - start;

      final bool success = res['success'] == true;
      if (!success) {
        overallOk = false;
      }

      String output = res['output'] ?? '';
      
      commandResults.add({
        'command_id': commandId,
        'command': adbCommand,
        'exit_code': success ? 0 : -1,
        'stdout': captureOutput && success ? output : '',
        'stderr': !success ? output : '',
        'duration_ms': duration,
      });

      if (delayMsAfter > 0 && overallOk) {
         await Future.delayed(Duration(milliseconds: delayMsAfter));
      }

      if (!success) {
        // 如果某个命令失败，是否中断后续执行看需求
        // 这里选择简单记录并继续，把错误留给模型判断
        break; 
      }
    }

    // 2. 执行客户端动作
    final clientActions = exec['client_actions'] as List<dynamic>? ?? [];
    for (final ca in clientActions) {
      final actionStr = ca.toString();
      // 这里可解析 ca 字典
      if (ca is Map && ca['type'] == 'restore_input_method') {
        // ... (可选) 恢复输入法逻辑
        clientResults.add({'type': 'restore_input_method', 'ok': true});
      } else if (ca is Map && ca['type'] == 'delay') {
        final delayMs = ca['duration_ms'] ?? 1000;
        await Future.delayed(Duration(milliseconds: delayMs));
        clientResults.add({'type': 'delay', 'ok': true});
      } else {
        clientResults.add({'type': actionStr, 'ok': true});
      }
    }

    return {
      'ok': overallOk,
      'executed_at': executedAt,
      'commands': commandResults,
      'client_actions': clientResults,
    };
  }
}
