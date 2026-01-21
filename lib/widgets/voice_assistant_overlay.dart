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
  bool _isDialogVisible = false;

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
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    _isDialogVisible = true;
  }

  void _closeVoiceAssistantDialog() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isDialogVisible = false;

    final service = Provider.of<VoiceAssistantService>(context, listen: false);
    if (service.isEnabled) {
      service.enable();
    }
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceAssistantService>(
      builder: (context, service, _) {
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
            // 浮窗按钮（固定在右下角）
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: FloatingActionButton(
                  onPressed: service.isEnabled
                      ? () {
                          if (!_isDialogVisible) {
                            _showVoiceAssistantDialog();
                          }
                        }
                      : null,
                  backgroundColor: service.isEnabled ? Colors.green : Colors.grey,
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
