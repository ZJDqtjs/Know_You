import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../common/voice_assistant_service.dart';

class VoiceAssistantSettingsPage extends StatefulWidget {
  const VoiceAssistantSettingsPage({super.key});

  @override
  State<VoiceAssistantSettingsPage> createState() =>
      _VoiceAssistantSettingsPageState();
}

class _VoiceAssistantSettingsPageState
    extends State<VoiceAssistantSettingsPage> {
  late TextEditingController _wakeWordController;
  late TextEditingController _speechApiController;
  late TextEditingController _agentApiController;

  @override
  void initState() {
    super.initState();
    final service = Provider.of<VoiceAssistantService>(context, listen: false);
    _wakeWordController = TextEditingController(text: service.wakeWord);
    _speechApiController =
        TextEditingController(text: service.speechToTextApiUrl);
    _agentApiController = TextEditingController(text: service.agentApiUrl);
  }

  @override
  void dispose() {
    _wakeWordController.dispose();
    _speechApiController.dispose();
    _agentApiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('语音助手设置'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 启用/禁用开关
            Consumer<VoiceAssistantService>(
              builder: (context, service, _) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '语音助手',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              service.speechAvailable
                                  ? '开启或关闭语音助手功能'
                                  : '语音识别不可用',
                              style: TextStyle(
                                fontSize: 12,
                                color: service.speechAvailable
                                    ? Colors.grey
                                    : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: service.isEnabled,
                          onChanged: (value) {
                            if (value) {
                              service.init().then((_) {
                                if (mounted) {
                                  service.enable();
                                }
                              });
                            } else {
                              service.disable();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Consumer<VoiceAssistantService>(
              builder: (context, service, _) {
                if (service.lastError == null || service.lastError!.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          service.lastError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // 唤醒词设置
            const Text(
              '自定义唤醒词',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _wakeWordController,
              decoration: InputDecoration(
                hintText: '默认: 你好，牛肉',
                prefixIcon: const Icon(Icons.mic),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                Provider.of<VoiceAssistantService>(context, listen: false)
                    .setWakeWord(value.isEmpty ? '你好，牛肉' : value);
              },
            ),
            const SizedBox(height: 20),

            // 语音转文字 API 设置
            const Text(
              '语音转文字 API',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _speechApiController,
              decoration: InputDecoration(
                hintText: '输入 API 链接（留空使用默认）',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                Provider.of<VoiceAssistantService>(context, listen: false)
                    .setSpeechToTextApiUrl(value);
              },
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '提示: 语音转文字 API 还未配置，将在后续添加',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Agent 智能体 API 设置
            const Text(
              'Agent 智能体 API',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _agentApiController,
              decoration: InputDecoration(
                hintText: '输入 API 链接（留空使用默认）',
                prefixIcon: const Icon(Icons.smart_toy),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                Provider.of<VoiceAssistantService>(context, listen: false)
                    .setAgentApiUrl(value);
              },
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '提示: Agent API 还未配置，将在后续添加',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 重置按钮
            ElevatedButton(
              onPressed: () {
                _wakeWordController.text = '你好，牛肉';
                _speechApiController.text = '';
                _agentApiController.text = '';
                final service =
                    Provider.of<VoiceAssistantService>(context, listen: false);
                service.setWakeWord('你好，牛肉');
                service.setSpeechToTextApiUrl('');
                service.setAgentApiUrl('');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const SizedBox(
                width: double.infinity,
                child: Center(
                  child: Text(
                    '恢复默认设置',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
