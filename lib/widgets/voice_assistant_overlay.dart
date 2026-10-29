import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../common/voice_assistant_service.dart';
import 'voice_assistant_dialog.dart';

class VoiceAssistantOverlay extends StatefulWidget {
  final Widget child;

  const VoiceAssistantOverlay({
    super.key,
    required this.child,
  });

  @override
  State<VoiceAssistantOverlay> createState() => _VoiceAssistantOverlayState();
}

class _VoiceAssistantOverlayState extends State<VoiceAssistantOverlay> {
  OverlayEntry? _overlayEntry;
  OverlayEntry? _miniStatusEntry;
  bool _isDialogVisible = false;
  bool _isMiniStatusVisible = false;
  String _miniStatusText = '正在执行...';

  @override
  void initState() {
    super.initState();
    // 初始化语音助手服务
    Future.microtask(() {
      final service = Provider.of<VoiceAssistantService>(context, listen: false);
      service.init();
    });
  }

  void _showVoiceAssistantDialog() {
    // 先移除旧的浮窗
    _overlayEntry?.remove();
    _overlayEntry = null;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: VoiceAssistantDialog(
            onClose: _closeVoiceAssistantDialog,
            onTaskStarted: _onTaskStarted,
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    _isDialogVisible = true;
  }

  void _onTaskStarted() {
    _closeVoiceAssistantDialog();
  }

  void _showMiniStatus(String statusText) {
    _miniStatusText = statusText;
    if (_miniStatusEntry == null) {
      _miniStatusEntry = OverlayEntry(
        builder: (_) {
          return Positioned(
            right: 12,
            top: 120,
            child: IgnorePointer(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5FAFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFB9E2FF)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _miniStatusText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF205B84),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
      Overlay.of(context).insert(_miniStatusEntry!);
    }
    _miniStatusEntry!.markNeedsBuild();
    _isMiniStatusVisible = true;
  }

  void _hideMiniStatus() {
    _miniStatusEntry?.remove();
    _miniStatusEntry = null;
    _isMiniStatusVisible = false;
  }

  void _closeVoiceAssistantDialog() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isDialogVisible = false;

    final service = Provider.of<VoiceAssistantService>(context, listen: false);
    service.stopListening();
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _miniStatusEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceAssistantService>(
      builder: (context, service, _) {
        final isExecuting = service.isExecutingCommand;
        final isCapturing = service.isAgentCapturing;

        if (isExecuting && _isDialogVisible) {
          Future.microtask(() {
            if (!mounted) return;
            _closeVoiceAssistantDialog();
          });
        }

        if (isExecuting && !isCapturing) {
          final status = service.responseText.isNotEmpty ? service.responseText : '正在执行任务...';
          Future.microtask(() {
            if (!mounted) return;
            _showMiniStatus(status);
          });
        } else if (_isMiniStatusVisible) {
          Future.microtask(() {
            if (!mounted) return;
            _hideMiniStatus();
          });
        }

        // 检测唤醒词并弹出对话框
        if (service.isEnabled &&
            service.wakeWordDetected &&
            !_isDialogVisible) {
          // 使用 Future.microtask 避免在 build 中直接修改状态
          Future.microtask(() {
            if (!mounted || _isDialogVisible) return;
            service.clearRecognizedText();
            _showVoiceAssistantDialog();
          });
        }
        
        return Stack(
          children: [
            widget.child,
            if (service.isEnabled)
              // 浮窗按钮（固定在右下角）
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: FloatingActionButton(
                    onPressed: () {
                      if (!_isDialogVisible) {
                        _showVoiceAssistantDialog();
                      }
                    },
                    backgroundColor: Colors.green,
                    child: const Icon(Icons.mic),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
