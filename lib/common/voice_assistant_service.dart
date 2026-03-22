import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'app_config.dart';
import 'agent/local_agent_service.dart';

class VoiceAssistantService extends ChangeNotifier {
  static const _prefKeyEnabled = 'voice_assistant_enabled';
  bool _isEnabled = true;
  bool _isListening = false;
  String _wakeWord = '你好，牛肉';
  String _speechToTextApiUrl = '';
  String _agentApiUrl = '';
  String _recognizedText = '';
  String _responseText = '';
  
  late stt.SpeechToText _speechToText;
  bool _speechAvailable = false;
  String _partialText = '';
  String? _lastError;
  bool _wakeWordDetected = false;
  bool _isInitializing = false;
  bool _isExecutingCommand = false;
  bool _isCloudRecording = false;
  late final AudioRecorder _recorder;

  static const _permissionErrorCode = 'error_permission';

  // Getters
  bool get isEnabled => _isEnabled;
  bool get isListening => _isListening;
  String get wakeWord => _wakeWord;
  String get speechToTextApiUrl => _speechToTextApiUrl;
  String get agentApiUrl => _agentApiUrl;
  bool get speechAvailable => _speechAvailable;
  String get recognizedText => _recognizedText;
  String get responseText => _responseText;
  String? get lastError => _lastError;
  bool get wakeWordDetected => _wakeWordDetected;
  bool get isExecutingCommand => _isExecutingCommand;

  VoiceAssistantService() {
    _speechToText = stt.SpeechToText();
    _recorder = AudioRecorder();
  }

  bool get _useCloudAsr =>
      (AppConfig.currentOrDefault.asrBaseUrl ?? '').trim().isNotEmpty;

  /// 初始化语音助手
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEnabled = prefs.getBool(_prefKeyEnabled) ?? true;
      _isEnabled = savedEnabled;
      notifyListeners();

      if (!_isEnabled) {
        return;
      }

      if (_useCloudAsr) {
        _speechAvailable = true;
        _lastError = null;
        notifyListeners();
        return;
      }

      await _initSpeech();
    } catch (e) {
      print('初始化语音助手失败: $e');
      _lastError = '初始化失败，请检查语音识别服务';
      notifyListeners();
    }
  }

  Future<void> _initSpeech() async {
    if (_isInitializing) return;
    _isInitializing = true;
    try {
      _lastError = null;
      final granted = await _ensureMicrophonePermission(requestIfNeeded: true);
      if (!granted) {
        _speechAvailable = false;
        notifyListeners();
        return;
      }

      try {
        _speechAvailable = await _speechToText.initialize(
          onError: (error) {
            print('语音识别错误: $error');
            final isPermissionError = error.errorMsg.contains(_permissionErrorCode);
            _lastError = isPermissionError
                ? '麦克风权限不可用，请在系统设置中开启麦克风权限'
                : error.errorMsg;
            if (isPermissionError) {
              _speechAvailable = false;
            }
            _isListening = false;
            notifyListeners();
          },
          onStatus: (status) {
            print('语音识别状态: $status');
            if (status == 'done' || status == 'notListening') {
              _isListening = false;
              notifyListeners();
            }
          },
        );
      } catch (e) {
        _speechAvailable = false;
        final errorText = e.toString();
        if (errorText.contains('recognizerNotAvailable')) {
          _lastError = '当前设备不支持本地语音识别，请使用下方文本输入';
        } else {
          _lastError = '语音识别初始化失败: $e';
        }
      }

      if (!_speechAvailable) {
        print('语音识别不可用');
        _lastError = '语音识别不可用，请安装语音识别服务';
      }

      notifyListeners();
    } finally {
      _isInitializing = false;
    }
  }

  /// 启用语音助手
  Future<void> enable() async {
    _isEnabled = true;
    notifyListeners();
    _saveEnabled(true);

    if (_useCloudAsr) {
      _speechAvailable = true;
      _lastError = null;
      notifyListeners();
      return;
    }

    if (!_speechAvailable) {
      await _initSpeech();
    } else {
      startListening();
    }
  }

  /// 禁用语音助手
  void disable() {
    stopListening();
    _isEnabled = false;
    _saveEnabled(false);
    notifyListeners();
  }

  Future<void> _saveEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyEnabled, enabled);
    } catch (e) {
      print('保存语音助手开关失败: $e');
    }
  }

  /// 开始监听
  void startListening() async {
    if (_isListening) return;

    try {
      if (_useCloudAsr) {
        await _startCloudRecording();
        return;
      }

      if (!_speechAvailable) {
        await _initSpeech();
        if (!_speechAvailable) {
          return;
        }
      }

      final granted = await _ensureMicrophonePermission(requestIfNeeded: true);
      if (!granted) {
        _isListening = false;
        _speechAvailable = false;
        notifyListeners();
        return;
      }

      _isListening = true;
      _partialText = '';
      notifyListeners();

      await _speechToText.listen(
        onResult: (result) {
          _partialText = result.recognizedWords;
          print('识别到文本: $_partialText');
          
          // 检查是否识别到唤醒词（去除标点符号后匹配）
          final normalizedText = _partialText.replaceAll(RegExp(r'[，。！？、,\.!\?\s]'), '');
          final normalizedWakeWord = _wakeWord.replaceAll(RegExp(r'[，。！？、,\.!\?\s]'), '');
          
          if (normalizedText.contains(normalizedWakeWord)) {
            print('检测到唤醒词: $_wakeWord (原文: $_partialText)');
            stopListening();
            onWakeWordDetected();
          } else {
            _recognizedText = _partialText;
            notifyListeners();
          }
        },
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        localeId: 'zh_CN',
      );
    } catch (e) {
      print('开始监听失败: $e');
      _isListening = false;
      notifyListeners();
    }
  }

  Future<void> _startCloudRecording() async {
    final granted = await _ensureMicrophonePermission(requestIfNeeded: true);
    if (!granted) {
      _isListening = false;
      notifyListeners();
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _lastError = '麦克风权限不可用，请检查系统设置';
      notifyListeners();
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_assistant_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    _isCloudRecording = true;
    _isListening = true;
    _lastError = null;
    notifyListeners();
  }

  Future<void> _transcribeCloudAudio(String path) async {
    final asrBaseUrl = AppConfig.currentOrDefault.asrBaseUrl?.trim();
    if (asrBaseUrl == null || asrBaseUrl.isEmpty) {
      _lastError = '未配置云端语音识别服务地址';
      notifyListeners();
      return;
    }

    try {
      _responseText = '正在识别语音...';
      notifyListeners();

      final dio = Dio(BaseOptions(
        baseUrl: asrBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
      ));

      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(path, filename: 'audio_record.mp3'),
        'language': '中文',
        'itn': 'true',
      });

      final res = await dio.post('/asr', data: form);
      if (res.statusCode == 200 && res.data is Map && res.data['text'] != null) {
        final text = res.data['text'].toString().trim();
        _recognizedText = text;
        _responseText = '';
        _lastError = null;

        final normalizedText = text.replaceAll(RegExp(r'[，。！？、,\.!\?\s]'), '');
        final normalizedWakeWord = _wakeWord.replaceAll(RegExp(r'[，。！？、,\.!\?\s]'), '');
        if (normalizedText.isNotEmpty && normalizedText.contains(normalizedWakeWord)) {
          onWakeWordDetected();
        }
      } else {
        _lastError = '云端语音识别失败：响应异常';
      }
    } catch (e) {
      _lastError = '云端语音识别失败: $e';
    } finally {
      notifyListeners();
    }
  }

  Future<void> submitCommand(String text, {required String userId}) async {
    final task = text.trim();
    if (task.isEmpty || _isExecutingCommand) return;
    if (userId.trim().isEmpty) {
      _responseText = '缺少 user_id，无法发送指令';
      notifyListeners();
      return;
    }

    _isExecutingCommand = true;
    _recognizedText = task;
    _responseText = '正在发送指令...';
    notifyListeners();

    final agent = LocalAgentService();
    String latestLog = '';

    agent.onLog = (log) {
      latestLog = log;
      _responseText = log;
      notifyListeners();
    };

    agent.onStateChange = (running) {
      _isExecutingCommand = running;
      if (!running && _responseText.trim().isEmpty) {
        _responseText = latestLog.isNotEmpty ? latestLog : '指令已发送';
      }
      notifyListeners();
    };

    try {
      await agent.runTask(task, userId: userId);
      if (_responseText == '正在发送指令...') {
        _responseText = latestLog.isNotEmpty ? latestLog : '指令已发送';
      }
    } catch (e) {
      _responseText = '发送失败: $e';
    } finally {
      _isExecutingCommand = false;
      notifyListeners();
    }
  }

  Future<bool> _ensureMicrophonePermission({required bool requestIfNeeded}) async {
    var status = await Permission.microphone.status;

    if (status.isPermanentlyDenied || status.isRestricted) {
      _lastError = '麦克风权限被永久拒绝，请前往系统设置开启权限';
      openAppSettings();
      return false;
    }

    if (status.isDenied && requestIfNeeded) {
      status = await Permission.microphone.request();
    }

    if (!status.isGranted) {
      _lastError = status.isPermanentlyDenied
          ? '麦克风权限被永久拒绝，请前往系统设置开启权限'
          : '麦克风权限未授予';
      if (status.isPermanentlyDenied || status.isRestricted) {
        openAppSettings();
      }
      return false;
    }

    _lastError = null;
    return true;
  }

  /// 停止监听
  Future<void> stopListening() async {
    try {
      if (_useCloudAsr && _isCloudRecording) {
        final path = await _recorder.stop();
        _isCloudRecording = false;
        _isListening = false;
        _partialText = '';
        notifyListeners();

        if (path != null && path.isNotEmpty) {
          await _transcribeCloudAudio(path);
        }
        return;
      }

      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
      _isListening = false;
      _partialText = '';
      notifyListeners();
    } catch (e) {
      print('停止监听失败: $e');
    }
  }

  /// 更新唤醒词
  void setWakeWord(String word) {
    _wakeWord = word;
    notifyListeners();
  }

  /// 更新语音转文字 API
  void setSpeechToTextApiUrl(String url) {
    _speechToTextApiUrl = url;
    notifyListeners();
  }

  /// 更新 Agent API
  void setAgentApiUrl(String url) {
    _agentApiUrl = url;
    notifyListeners();
  }

  /// 识别到唤醒词
  void onWakeWordDetected() {
    _recognizedText = '已检测到唤醒词';
    _wakeWordDetected = true;
    notifyListeners();
  }

  /// 更新识别的文本
  void updateRecognizedText(String text) {
    _recognizedText = text;
    notifyListeners();
  }

  /// 更新响应文本
  void updateResponseText(String text) {
    _responseText = text;
    notifyListeners();
  }

  /// 清除识别文本
  void clearRecognizedText() {
    _recognizedText = '';
    _wakeWordDetected = false;
    notifyListeners();
  }

  /// 清除响应文本
  void clearResponseText() {
    _responseText = '';
    notifyListeners();
  }

  @override
  void dispose() {
    if (_isCloudRecording) {
      _recorder.stop();
      _isCloudRecording = false;
    }
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
    _isListening = false;
    _recorder.dispose();
    super.dispose();
  }
}
