import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';

/// 悬浮球朗读服务
class FloatingBallService extends ChangeNotifier {
  static final FloatingBallService _instance = FloatingBallService._internal();
  factory FloatingBallService() => _instance;
  FloatingBallService._internal();

  FlutterTts? _tts;
  static const platform = MethodChannel('com.example.know_you/floating_ball');
  
  bool _isEnabled = false;
  bool _isReadMode = false;  // 是否处于朗读模式（点击悬浮球后）
  bool _isSpeaking = false;
  bool _isInitialized = false;
  bool _useNativeFloatingBall = false;  // 使用Flutter悬浮球以保持统一图标
  bool _noTtsEngine = false;  // 标记是否没有TTS引擎
  
  OverlayEntry? _overlayEntry;
  Offset _position = const Offset(20, 200);
  
  bool get isEnabled => _isEnabled;
  bool get isReadMode => _isReadMode;
  bool get isSpeaking => _isSpeaking;
  bool get useNativeFloatingBall => _useNativeFloatingBall;
  bool get noTtsEngine => _noTtsEngine;
  Offset get position => _position;

  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      // 设置方法调用处理器，接收来自原生端的回调
      platform.setMethodCallHandler(_handleNativeCall);
      
      // 创建TTS实例
      _tts = FlutterTts();
      
      // 等待一段时间让TTS引擎初始化
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // 检查引擎是否存在 - 但不完全依赖这个结果
      final engines = await _tts!.getEngines;
      print('Available TTS engines: $engines');
      
      // 设置handlers
      _tts!.setStartHandler(() {
        _isSpeaking = true;
        notifyListeners();
      });
      
      _tts!.setCompletionHandler(() {
        _isSpeaking = false;
        notifyListeners();
      });
      
      _tts!.setErrorHandler((msg) {
        print('TTS Error: $msg');
        _isSpeaking = false;
        notifyListeners();
      });
      
      // 尝试设置语言和参数 - 即使engines为空也尝试
      try {
        // 尝试设置中文
        var result = await _tts!.setLanguage('zh-CN');
        print('setLanguage zh-CN result: $result');
        if (result == 0) {
          result = await _tts!.setLanguage('zh');
          print('setLanguage zh result: $result');
        }
        
        await _tts!.setSpeechRate(0.5);
        await _tts!.setVolume(1.0);
        await _tts!.setPitch(1.0);
        
        // 尝试实际朗读一个测试文本来验证TTS是否工作
        // 使用静音测试
        await _tts!.setVolume(0.0);
        final testResult = await _tts!.speak(' ');  // 朗读空白
        await Future.delayed(const Duration(milliseconds: 200));
        await _tts!.stop();
        await _tts!.setVolume(1.0);  // 恢复音量
        
        print('TTS test speak result: $testResult');
        
        // 如果能执行到这里且没有抛出异常，说明TTS可用
        _isInitialized = true;
        _noTtsEngine = false;
        print('TTS initialized successfully');
      } catch (e) {
        print('TTS config/test failed: $e');
        // 即使配置失败，也标记为已初始化，让用户可以尝试使用
        _isInitialized = true;
        _noTtsEngine = false;  // 不标记为没有引擎，因为系统可能有
      }
    } catch (e) {
      print('TTS init error: $e');
      _noTtsEngine = true;
    }
  }
  
  /// 打开Google Play安装TTS引擎
  Future<void> openTtsEngineInstall() async {
    // Google TTS应用包名
    const googleTtsPackage = 'com.google.android.tts';
    final playStoreUrl = Uri.parse('market://details?id=$googleTtsPackage');
    final webUrl = Uri.parse('https://play.google.com/store/apps/details?id=$googleTtsPackage');
    
    try {
      if (await canLaunchUrl(playStoreUrl)) {
        await launchUrl(playStoreUrl);
      } else if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Failed to open TTS install page: $e');
    }
  }
  
  /// 打开系统TTS设置
  Future<void> openTtsSettings() async {
    try {
      const settingsChannel = MethodChannel('com.example.know_you/settings');
      await settingsChannel.invokeMethod('openTtsSettings');
    } catch (e) {
      print('Failed to open TTS settings: $e');
      // 尝试使用通用设置intent
      final settingsUrl = Uri.parse('package:com.android.settings');
      if (await canLaunchUrl(settingsUrl)) {
        await launchUrl(settingsUrl);
      }
    }
  }
  
  /// 处理来自原生端的方法调用
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onReadModeChanged':
        final isReadMode = call.arguments['isReadMode'] as bool;
        _isReadMode = isReadMode;
        // 不触发notifyListeners以避免页面刷新
        // notifyListeners();
        return true;
      case 'onNoTtsEngine':
        // 原生端通知没有TTS引擎
        _noTtsEngine = true;
        notifyListeners();  // 触发UI更新
        return true;
      case 'speakText':
        // 原生端请求Flutter TTS朗读
        final text = call.arguments['text'] as String?;
        if (text != null && text.isNotEmpty) {
          await speak(text);
        }
        return true;
      default:
        return null;
    }
  }

  void enable(BuildContext context) async {
    if (_isEnabled) return;
    
    try {
      // 检查是否有悬浮窗权限
      final hasPermission = await platform.invokeMethod<bool>('hasOverlayPermission') ?? false;
      
      if (_useNativeFloatingBall && hasPermission) {
        // 使用原生悬浮球
        try {
          await platform.invokeMethod('startFloatingBall');
          _isEnabled = true;
          notifyListeners();
          print('Native floating ball started successfully');
        } catch (e) {
          print('Failed to start native floating ball: $e');
          // 回退到Flutter悬浮球
          _useNativeFloatingBall = false;
          _enableFlutterFloatingBall(context);
        }
      } else if (_useNativeFloatingBall && !hasPermission) {
        // 尝试请求权限
        try {
          await platform.invokeMethod('startFloatingBall');
          _isEnabled = true;
          notifyListeners();
          print('Native floating ball started (with permission request)');
        } catch (e) {
          print('Failed to start native floating ball (no permission): $e');
          // 在Android 9上，即使没有系统级权限，也可以使用应用内悬浮球
          _useNativeFloatingBall = false;
          _enableFlutterFloatingBall(context);
        }
      } else {
        // 使用Flutter悬浮球
        _enableFlutterFloatingBall(context);
      }
    } catch (e) {
      print('Error enabling floating ball: $e');
      // 回退到Flutter悬浮球
      _useNativeFloatingBall = false;
      _enableFlutterFloatingBall(context);
    }
  }
  
  void _enableFlutterFloatingBall(BuildContext context) {
    _isEnabled = true;
    _showOverlay(context);
    notifyListeners();
  }

  void disable() async {
    if (!_isEnabled) return;
    _isEnabled = false;
    _isReadMode = false;
    
    if (_useNativeFloatingBall) {
      try {
        await platform.invokeMethod('stopFloatingBall');
      } catch (e) {
        print('Error stopping native floating ball: $e');
      }
    } else {
      _removeOverlay();
    }
    
    _tts?.stop();
    notifyListeners();
  }

  void toggleReadMode() {
    _isReadMode = !_isReadMode;
    notifyListeners();
    // 只有在使用Flutter悬浮球时才更新overlay
    if (!_useNativeFloatingBall && _overlayEntry != null) {
      _updateOverlay();
    }
  }

  void exitReadMode() {
    if (!_isReadMode) return;
    _isReadMode = false;
    // 只更新overlay，不触发全局notifyListeners
    // 只有在使用Flutter悬浮球时才更新overlay
    if (!_useNativeFloatingBall && _overlayEntry != null) {
      _updateOverlay();
    }
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    
    print('TTS speak called with: $text');
    
    // 确保已初始化
    if (!_isInitialized || _tts == null) {
      print('TTS not initialized, initializing now...');
      await init();
    }
    
    if (_tts == null) {
      print('TTS still null after init, creating new instance');
      _tts = FlutterTts();
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    try {
      // 尝试停止之前的朗读
      try {
        await _tts!.stop();
      } catch (e) {
        print('TTS stop error (ignored): $e');
      }
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 直接尝试朗读，不管之前的检测结果
      var result = await _tts!.speak(text);
      print('TTS speak result: $result');
      
      // 如果失败，重新创建TTS实例并重试
      if (result != 1) {
        print('TTS speak failed (result=$result), recreating TTS instance...');
        _tts = FlutterTts();
        await Future.delayed(const Duration(milliseconds: 800));
        
        // 设置语言
        try {
          await _tts!.setLanguage('zh-CN');
        } catch (e) {
          print('setLanguage failed: $e');
        }
        
        try {
          await _tts!.setSpeechRate(0.5);
          await _tts!.setVolume(1.0);
          await _tts!.setPitch(1.0);
        } catch (e) {
          print('TTS config failed: $e');
        }
        
        await Future.delayed(const Duration(milliseconds: 200));
        result = await _tts!.speak(text);
        print('TTS retry result: $result');
      }
    } catch (e) {
      print('TTS speak error: $e');
    }
  }
  
  Future<void> _reinitializeTts() async {
    try {
      _tts = FlutterTts();
      
      // 设置handlers
      _tts!.setStartHandler(() {
        _isSpeaking = true;
        notifyListeners();
      });
      
      _tts!.setCompletionHandler(() {
        _isSpeaking = false;
        notifyListeners();
      });
      
      _tts!.setErrorHandler((msg) {
        print('TTS Error: $msg');
        _isSpeaking = false;
        notifyListeners();
      });
      
      // 等待引擎绑定
      await Future.delayed(const Duration(milliseconds: 800));
      
      await _tts!.setLanguage('zh-CN');
      await _tts!.setSpeechRate(0.5);
      await _tts!.setVolume(1.0);
      await _tts!.setPitch(1.0);
      
      _isInitialized = true;
      print('TTS reinitialized');
    } catch (e) {
      print('TTS reinit error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (e) {
      print('TTS stop error: $e');
    }
    _isSpeaking = false;
    notifyListeners();
  }

  void updatePosition(Offset newPosition) {
    _position = newPosition;
    _updateOverlay();
  }

  void _showOverlay(BuildContext context) {
    _removeOverlay();
    
    _overlayEntry = OverlayEntry(
      builder: (context) => _FloatingBallWidget(service: this),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _tts?.stop();
    _removeOverlay();
    super.dispose();
  }
}

class _FloatingBallWidget extends StatefulWidget {
  final FloatingBallService service;
  
  const _FloatingBallWidget({required this.service});

  @override
  State<_FloatingBallWidget> createState() => _FloatingBallWidgetState();
}

class _FloatingBallWidgetState extends State<_FloatingBallWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    widget.service.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    if (widget.service.isReadMode && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.service.isReadMode && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceChanged);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final position = widget.service.position + _dragOffset;
    
    // Clamp position to screen bounds
    final clampedX = position.dx.clamp(0.0, screenSize.width - 56);
    final clampedY = position.dy.clamp(0.0, screenSize.height - 56);

    return Positioned(
      left: clampedX,
      top: clampedY,
      child: GestureDetector(
        onPanStart: (details) {
          _isDragging = true;
          _dragOffset = Offset.zero;
        },
        onPanUpdate: (details) {
          setState(() {
            _dragOffset += details.delta;
          });
        },
        onPanEnd: (details) {
          final newPosition = widget.service.position + _dragOffset;
          final clampedPos = Offset(
            newPosition.dx.clamp(0.0, screenSize.width - 56),
            newPosition.dy.clamp(0.0, screenSize.height - 56),
          );
          widget.service.updatePosition(clampedPos);
          _dragOffset = Offset.zero;
          _isDragging = false;
        },
        onTap: () {
          widget.service.toggleReadMode();
        },
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final scale = widget.service.isReadMode ? _pulseAnimation.value : 1.0;
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.service.isReadMode
                    ? [Colors.orange, Colors.deepOrange]
                    : [Colors.green, Colors.teal],
              ),
              boxShadow: [
                BoxShadow(
                  color: (widget.service.isReadMode ? Colors.orange : Colors.green).withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  widget.service.isReadMode 
                      ? Icons.touch_app 
                      : (widget.service.isSpeaking ? Icons.volume_up : Icons.record_voice_over),
                  color: Colors.white,
                  size: 28,
                ),
                if (widget.service.isReadMode)
                  Positioned(
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '点读',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 包装整个应用以支持文字点击朗读
class ReadableTextWrapper extends StatefulWidget {
  final Widget child;
  final FloatingBallService service;

  const ReadableTextWrapper({
    super.key,
    required this.child,
    required this.service,
  });

  @override
  State<ReadableTextWrapper> createState() => _ReadableTextWrapperState();
}

class _ReadableTextWrapperState extends State<ReadableTextWrapper> {
  bool _isReadMode = false;

  @override
  void initState() {
    super.initState();
    _isReadMode = widget.service.isReadMode;
    widget.service.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    // 只在readMode状态改变时才rebuild
    if (_isReadMode != widget.service.isReadMode) {
      setState(() {
        _isReadMode = widget.service.isReadMode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReadMode) {
      return widget.child;
    }
    
    return Stack(
      children: [
        widget.child,
        // 覆盖层用于捕获点击
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) {
              _handleTap(context, details.globalPosition);
            },
          ),
        ),
      ],
    );
  }

  void _handleTap(BuildContext context, Offset globalPosition) {
    // 查找点击位置的文字
    if (widget.service.useNativeFloatingBall) {
      // 使用原生accessibility服务获取文字
      _getTextFromNative(globalPosition);
    } else {
      // 使用Flutter方式获取文字
      final result = _findTextAtPosition(context, globalPosition);
      if (result != null && result.isNotEmpty) {
        widget.service.speak(result);
        widget.service.exitReadMode();
      }
    }
  }
  
  Future<void> _getTextFromNative(Offset globalPosition) async {
    try {
      // 先检查无障碍服务是否启用
      const accessibilityChannel = MethodChannel('com.example.know_you/accessibility');
      final isEnabled = await accessibilityChannel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
      
      if (!isEnabled) {
        print('Accessibility service not enabled, using Flutter text detection');
        // 直接使用Flutter方式
        final result = _findTextAtPosition(context, globalPosition);
        if (result != null && result.isNotEmpty) {
          widget.service.speak(result);
          widget.service.exitReadMode();
        }
        return;
      }
      
      final screenSize = MediaQuery.of(context).size;
      final x = globalPosition.dx / screenSize.width;
      final y = globalPosition.dy / screenSize.height;
      
      final text = await FloatingBallService.platform.invokeMethod<String>(
        'getTextAtPosition',
        {'x': x, 'y': y},
      );
      
      if (text != null && text.isNotEmpty) {
        widget.service.speak(text);
        widget.service.exitReadMode();
      } else {
        // 如果原生方式没找到文字，回退到Flutter方式
        final result = _findTextAtPosition(context, globalPosition);
        if (result != null && result.isNotEmpty) {
          widget.service.speak(result);
          widget.service.exitReadMode();
        }
      }
    } catch (e) {
      print('Error getting text from native: $e');
      // 回退到Flutter方式
      final result = _findTextAtPosition(context, globalPosition);
      if (result != null && result.isNotEmpty) {
        widget.service.speak(result);
        widget.service.exitReadMode();
      }
    }
  }

  String? _findTextAtPosition(BuildContext context, Offset globalPosition) {
    String? foundText;
    
    void visitor(Element element) {
      // 检查是否是 RenderBox
      final renderObject = element.renderObject;
      if (renderObject is RenderBox) {
        final box = renderObject;
        if (box.hasSize) {
          final localPosition = box.globalToLocal(globalPosition);
          final size = box.size;
          
          // 检查点击是否在这个元素范围内
          if (localPosition.dx >= 0 &&
              localPosition.dx <= size.width &&
              localPosition.dy >= 0 &&
              localPosition.dy <= size.height) {
            
            // 检查是否是 Text widget
            if (element.widget is Text) {
              final textWidget = element.widget as Text;
              final text = textWidget.data ?? textWidget.textSpan?.toPlainText();
              if (text != null && text.isNotEmpty) {
                foundText = text;
              }
            }
            // 检查 RichText
            else if (element.widget is RichText) {
              final richText = element.widget as RichText;
              final text = richText.text.toPlainText();
              if (text.isNotEmpty) {
                foundText = text;
              }
            }
            // 检查按钮等组件的 child
            else if (element.widget is TextButton || 
                     element.widget is ElevatedButton ||
                     element.widget is OutlinedButton) {
              // 继续遍历子元素
            }
          }
        }
      }
      
      element.visitChildren(visitor);
    }
    
    context.visitChildElements(visitor);
    return foundText;
  }
}
