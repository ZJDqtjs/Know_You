import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';

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

  VoiceAssistantService() {
    _speechToText = stt.SpeechToText();
  }

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

      await _initSpeech();
    } catch (e) {
      print('初始化语音助手失败: $e');
      _isEnabled = false;
      _lastError = '初始化失败，请检查语音识别服务';
      notifyListeners();
    }
  }

  Future<void> _initSpeech() async {
    if (_isInitializing) return;
    _isInitializing = true;
    try {
      _lastError = null;
      // 请求麦克风权限
      final status = await Permission.microphone.request();
      if (status.isDenied) {
        _isEnabled = false;
        _lastError = '麦克风权限未授予';
        notifyListeners();
        return;
      }

      if (status.isPermanentlyDenied) {
        _isEnabled = false;
        _lastError = '麦克风权限被永久拒绝';
        openAppSettings();
        notifyListeners();
        return;
      }

      // 初始化语音识别
      _speechAvailable = await _speechToText.initialize(
        onError: (error) {
          print('语音识别错误: $error');
          _lastError = error.errorMsg;
          // 识别错误后，延迟重启监听
          if (_isEnabled && _speechAvailable) {
            Future.delayed(const Duration(seconds: 2), () {
              if (_isEnabled && _speechAvailable && !_isListening) {
                _startListening();
              }
            });
          }
          _isListening = false;
          notifyListeners();
        },
        onStatus: (status) {
          print('语音识别状态: $status');
          // 状态改变后，延迟重启监听
          if (status == 'done' || status == 'notListening') {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_isEnabled && _speechAvailable && !_isListening) {
                _startListening();
              }
            });
          }
        },
      );

      if (!_speechAvailable) {
        print('语音识别不可用');
        _isEnabled = false;
        _lastError = '语音识别不可用，请安装语音识别服务';
      } else {
        _isEnabled = true;
      }

      notifyListeners();

      if (_isEnabled && _speechAvailable) {
        _startListening();
      }
    } finally {
      _isInitializing = false;
    }
  }

  /// 启用语音助手
  Future<void> enable() async {
    _isEnabled = true;
    notifyListeners();
    _saveEnabled(true);
    if (!_speechAvailable) {
      await _initSpeech();
    } else {
      _startListening();
    }
  }

  /// 禁用语音助手
  void disable() {
    _stopListening();
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
  void _startListening() async {
    if (!_speechAvailable || _isListening) return;

    try {
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
            _stopListening();
            onWakeWordDetected();
          } else {
            _recognizedText = _partialText;
            notifyListeners();
          }
        },
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'zh_CN',
      );
    } catch (e) {
      print('开始监听失败: $e');
      _isListening = false;
      notifyListeners();
    }
  }

  /// 停止监听
  Future<void> _stopListening() async {
    try {
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
    _stopListening();
    super.dispose();
  }
}
