import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../common/voice_assistant_service.dart';
import '../common/auth_provider.dart';

class VoiceAssistantDialog extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onTaskStarted;

  const VoiceAssistantDialog({
    super.key,
    required this.onClose,
    this.onTaskStarted,
  });

  @override
  State<VoiceAssistantDialog> createState() => _VoiceAssistantDialogState();
}

class _VoiceAssistantDialogState extends State<VoiceAssistantDialog>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _overlayPulseController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _overlayPulseAnimation;
  final TextEditingController _textController = TextEditingController();
  VoiceAssistantService? _service;
  bool _serviceListenerAttached = false;
  bool _isTextInputMode = false;
  double _longPressStartY = 0;
  bool _voiceCanceledBySlide = false;
  bool _isVoicePressing = false;
  static const double _slideCancelThreshold = 12;
  static const double _slideRestoreThreshold = 6;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _overlayPulseController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _overlayPulseAnimation = Tween<double>(begin: 0.88, end: 1.12).animate(
      CurvedAnimation(parent: _overlayPulseController, curve: Curves.easeInOut),
    );

    _slideController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _service ??= Provider.of<VoiceAssistantService>(context, listen: false);
    if (!_serviceListenerAttached) {
      _service!.addListener(_onServiceUpdate);
      _serviceListenerAttached = true;
    }
  }

  void _onServiceUpdate() {
    if (!mounted) return;
    final service = Provider.of<VoiceAssistantService>(context, listen: false);
    if (service.recognizedText.isNotEmpty) {
      if (_textController.text != service.recognizedText) {
        _textController.value = TextEditingValue(
          text: service.recognizedText,
          selection: TextSelection.collapsed(offset: service.recognizedText.length),
        );
      }
    }
  }

  Future<String> _resolveUserId() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dynamic rawId = auth.user?['id'] ?? auth.user?['userId'];
    var userId = rawId?.toString() ?? '';
    if (userId.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString('auth_user_id') ?? '';
    }
    return userId;
  }

  Future<void> _submitText(VoiceAssistantService service) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final userId = await _resolveUserId();
    widget.onTaskStarted?.call();
    unawaited(service.submitCommand(text, userId: userId));
    if (!mounted) return;
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    if (_serviceListenerAttached) {
      _service?.removeListener(_onServiceUpdate);
    }
    _textController.dispose();
    _slideController.dispose();
    _overlayPulseController.dispose();
    super.dispose();
  }

  void _closeDialog() {
    _slideController.reverse().then((_) {
      widget.onClose();
    });
  }

  Widget _buildVoicePressOverlay() {
    final canceling = _voiceCanceledBySlide;
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 90),
            opacity: _isVoicePressing ? 1 : 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: canceling
                      ? const AlwaysStoppedAnimation(1.0)
                      : _overlayPulseAnimation,
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: canceling ? const Color(0x33FF5252) : const Color(0x332F8A3C),
                      border: Border.all(
                        color: canceling ? const Color(0xFFFF8A80) : const Color(0xFF68D9A8),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      canceling ? Icons.cancel_rounded : Icons.mic,
                      size: 42,
                      color: canceling ? const Color(0xFFFF8A80) : const Color(0xFF5DE0B6),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: canceling ? const Color(0xCC8B1C1C) : const Color(0xCC1C4F42),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    canceling ? '松开手指，取消识别' : '上滑取消，下滑恢复',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width;
    final dialogHeight = screenSize.height * 0.36;

    return SlideTransition(
      position: _slideAnimation,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: dialogWidth,
            height: dialogHeight,
            decoration: const BoxDecoration(
              color: Color(0xFF121212),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 16,
                  offset: Offset(0, -6),
                ),
              ],
            ),
            child: Consumer<VoiceAssistantService>(
            builder: (context, service, _) {
              return Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '语音助手',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: _closeDialog,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (service.responseText.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          service.responseText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '识别文字',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            service.recognizedText.isNotEmpty
                                ? service.recognizedText
                                : '识别完成后的文字会显示在这里',
                            style: TextStyle(
                              fontSize: 20,
                              height: 1.35,
                              color: service.recognizedText.isNotEmpty
                                  ? Colors.white
                                  : Colors.white54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: () {
                              setState(() {
                                _isTextInputMode = !_isTextInputMode;
                              });
                            },
                            icon: Icon(
                              _isTextInputMode ? Icons.mic_none : Icons.keyboard,
                              color: Colors.white,
                              size: 24,
                            ),
                            tooltip: _isTextInputMode ? '切换到按住说话' : '切换到键盘输入',
                            splashRadius: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: _isTextInputMode
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: TextField(
                                        controller: _textController,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          color: Colors.white70,
                                        ),
                                        decoration: const InputDecoration(
                                          hintText: '输入指令后点击发送',
                                          hintStyle: TextStyle(color: Colors.white38, fontSize: 16),
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                        onChanged: (value) {
                                          service.updateRecognizedText(value);
                                        },
                                        onSubmitted: (value) {
                                          _submitText(service);
                                        },
                                      ),
                                    ),
                                  )
                                : GestureDetector(
                                    onLongPressStart: (details) {
                                      setState(() {
                                        _longPressStartY = details.globalPosition.dy;
                                        _voiceCanceledBySlide = false;
                                        _isVoicePressing = true;
                                      });
                                      _overlayPulseController.repeat(reverse: true);
                                      service.startListening();
                                    },
                                    onLongPressMoveUpdate: (details) {
                                      final delta = _longPressStartY - details.globalPosition.dy;
                                      final nextCanceled = _voiceCanceledBySlide
                                          ? delta > _slideRestoreThreshold
                                          : delta > _slideCancelThreshold;
                                      if (nextCanceled != _voiceCanceledBySlide) {
                                        setState(() {
                                          _voiceCanceledBySlide = nextCanceled;
                                        });
                                      }
                                    },
                                    onLongPressEnd: (_) {
                                      service.stopListening(cancelRecognition: _voiceCanceledBySlide);
                                      _overlayPulseController.stop();
                                      setState(() {
                                        _voiceCanceledBySlide = false;
                                        _isVoicePressing = false;
                                      });
                                    },
                                    child: Container(
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _voiceCanceledBySlide
                                            ? const Color(0x33FF5252)
                                            : (service.isListening
                                                ? const Color(0x332F8A3C)
                                                : Colors.white.withOpacity(0.06)),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _voiceCanceledBySlide
                                              ? const Color(0xFFFF8A80)
                                              : (service.isListening
                                                  ? const Color(0xFF3BE8FF)
                                                  : Colors.white24),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            service.isListening
                                                ? (_voiceCanceledBySlide ? '松开取消，下滑恢复' : '松开结束说话')
                                                : '按住说话',
                                            maxLines: 1,
                                            softWrap: false,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: _voiceCanceledBySlide
                                                  ? const Color(0xFFFF8A80)
                                                  : (service.isListening
                                                      ? const Color(0xFF62E3FF)
                                                      : Colors.white70),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2F8A3C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: service.isExecutingCommand
                                ? null
                                : () => _submitText(service),
                            icon: const Icon(Icons.send, color: Colors.white, size: 22),
                            tooltip: '发送',
                            splashRadius: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                  ),
                  if (_isVoicePressing && !_isTextInputMode) _buildVoicePressOverlay(),
                ],
              );
            },
          ),
        ),
        ),
      ),
    );
  }
}
