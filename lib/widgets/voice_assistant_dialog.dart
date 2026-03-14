import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../common/voice_assistant_service.dart';
import '../common/auth_provider.dart';

class VoiceAssistantDialog extends StatefulWidget {
  final VoidCallback onClose;

  const VoiceAssistantDialog({
    super.key,
    required this.onClose,
  });

  @override
  State<VoiceAssistantDialog> createState() => _VoiceAssistantDialogState();
}

class _VoiceAssistantDialogState extends State<VoiceAssistantDialog>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  final TextEditingController _textController = TextEditingController();

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

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideController.forward();
    _pulseController.repeat(reverse: true);

    // Initial logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = Provider.of<VoiceAssistantService>(context, listen: false);
      service.addListener(_onServiceUpdate);
      if (!service.isListening && service.speechAvailable) {
        service.startListening();
      }
    });
  }

  void _onServiceUpdate() {
    if (!mounted) return;
    final service = Provider.of<VoiceAssistantService>(context, listen: false);
    // If it's listening and transcribing, update text field, but put cursor at end
    if (service.isListening && service.recognizedText.isNotEmpty) {
      if (_textController.text != service.recognizedText) {
        _textController.value = TextEditingValue(
          text: service.recognizedText,
          selection: TextSelection.collapsed(offset: service.recognizedText.length),
        );
      }
    }
  }

  Future<void> _submitText(VoiceAssistantService service) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dynamic rawId = auth.user?['id'] ?? auth.user?['userId'];
    var userId = rawId?.toString() ?? '';
    if (userId.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString('auth_user_id') ?? '';
    }

    await service.submitCommand(text, userId: userId);
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    final service = Provider.of<VoiceAssistantService>(context, listen: false);
    service.removeListener(_onServiceUpdate);
    _textController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _closeDialog() {
    _pulseController.stop();
    _slideController.reverse().then((_) {
      widget.onClose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width;
    final dialogHeight = screenSize.height * 0.25; // 占屏幕1/4

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
              final statusText = service.lastError?.isNotEmpty == true
                  ? service.lastError!
                  : (service.isListening ? '正在聆听…' : '已就绪');
              return Padding(
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
                    const SizedBox(height: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 13,
                        color: service.lastError?.isNotEmpty == true
                            ? const Color(0xFFFF8A80)
                            : service.isListening
                            ? const Color(0xFF62E3FF)
                            : Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 10),
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
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: TextField(
                                  controller: _textController,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: '请说出指令或在此输入…',
                                    hintStyle: TextStyle(color: Colors.white38),
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
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2F8A3C),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              onPressed: service.isExecutingCommand
                                  ? null
                                  : () => _submitText(service),
                              icon: const Icon(Icons.send, color: Colors.white, size: 18),
                              tooltip: '发送',
                              splashRadius: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              if (service.isListening) {
                                service.stopListening();
                              } else {
                                service.startListening();
                              }
                            },
                            child: ScaleTransition(
                              scale: service.isListening 
                                  ? _pulseAnimation 
                                  : const AlwaysStoppedAnimation(1.0),
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: service.isListening
                                        ? [const Color(0xFF3BE8FF), const Color(0xFF7B61FF)]
                                        : [Colors.grey.shade600, Colors.grey.shade800],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: service.isListening
                                      ? [
                                          BoxShadow(
                                            color: Colors.blueAccent.withOpacity(0.4),
                                            blurRadius: 16,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Icon(
                                  service.isListening ? Icons.mic : Icons.mic_off,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        ),
      ),
    );
  }
}
