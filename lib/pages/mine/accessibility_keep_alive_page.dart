import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../common/shizuku_service.dart';

/// 无障碍保活设置页面
class AccessibilityKeepAlivePage extends StatefulWidget {
  const AccessibilityKeepAlivePage({super.key});

  @override
  State<AccessibilityKeepAlivePage> createState() => _AccessibilityKeepAlivePageState();
}

class _AccessibilityKeepAlivePageState extends State<AccessibilityKeepAlivePage> {
  Map<String, String>? _wirelessDebugGuide;
  String? _adbCommand;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final service = Provider.of<ShizukuService>(context, listen: false);
    await service.refreshStatus();
    
    _wirelessDebugGuide = await service.getWirelessDebugGuide();
    _adbCommand = await service.getAdbCommand();
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('无障碍保活设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '刷新状态',
          ),
        ],
      ),
      body: Consumer<ShizukuService>(
        builder: (context, service, _) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 当前状态卡片
                _buildStatusCard(service),
                const SizedBox(height: 16),
                
                // 保活方式选择
                _buildKeepAliveMethodSection(service),
                const SizedBox(height: 16),
                
                // Shizuku 设置区域
                if (service.keepAliveMethod == KeepAliveMethod.shizuku)
                  _buildShizukuSection(service),
                
                // 无线调试区域
                if (service.keepAliveMethod == KeepAliveMethod.wirelessAdb)
                  _buildWirelessAdbSection(),
                
                const SizedBox(height: 24),
                
                // 说明
                _buildInfoSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(ShizukuService service) {
    final accessibilityColor = service.isAccessibilityEnabled ? Colors.green : Colors.red;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  service.isAccessibilityEnabled ? Icons.check_circle : Icons.error,
                  color: accessibilityColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '无障碍服务状态',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        service.isAccessibilityEnabled ? '已启用' : '未启用',
                        style: TextStyle(color: accessibilityColor),
                      ),
                    ],
                  ),
                ),
                if (!service.isAccessibilityEnabled)
                  TextButton(
                    onPressed: () => _openAccessibilitySettings(),
                    child: const Text('去启用'),
                  ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _buildStatusItem(
                  'Shizuku',
                  service.isShizukuInstalled
                      ? (service.isShizukuRunning ? '运行中' : '已停止')
                      : '未安装',
                  service.isShizukuRunning ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 24),
                _buildStatusItem(
                  'Shizuku权限',
                  service.hasShizukuPermission ? '已授权' : '未授权',
                  service.hasShizukuPermission ? Colors.green : Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _buildKeepAliveMethodSection(ShizukuService service) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '保活方式',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              '选择一种方式来防止无障碍服务被系统杀死',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            
            // 不保活
            RadioListTile<KeepAliveMethod>(
              title: const Text('不使用保活'),
              subtitle: const Text('无障碍服务可能会被系统清理'),
              value: KeepAliveMethod.none,
              groupValue: service.keepAliveMethod,
              onChanged: (value) => service.setKeepAliveMethod(value!),
            ),
            
            // Shizuku 方式
            RadioListTile<KeepAliveMethod>(
              title: Row(
                children: [
                  const Text('Shizuku 保活'),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '推荐',
                      style: TextStyle(fontSize: 10, color: Colors.green),
                    ),
                  ),
                ],
              ),
              subtitle: const Text('需要安装 Shizuku 应用'),
              value: KeepAliveMethod.shizuku,
              groupValue: service.keepAliveMethod,
              onChanged: (value) => service.setKeepAliveMethod(value!),
            ),
            
            // 无线调试方式
            RadioListTile<KeepAliveMethod>(
              title: const Text('无线调试保活'),
              subtitle: const Text('需要电脑配合执行 ADB 命令'),
              value: KeepAliveMethod.wirelessAdb,
              groupValue: service.keepAliveMethod,
              onChanged: (value) => service.setKeepAliveMethod(value!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShizukuSection(ShizukuService service) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.android, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Shizuku 设置',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (!service.isShizukuInstalled) ...[
              const Text('Shizuku 未安装，请先下载安装'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => service.openShizukuDownload(),
                icon: const Icon(Icons.download),
                label: const Text('下载 Shizuku'),
              ),
            ] else if (!service.isShizukuRunning) ...[
              const Text('Shizuku 未运行，请打开 Shizuku 应用并启动服务'),
              const SizedBox(height: 8),
              const Text(
                '提示：可通过无线调试或 ADB 命令启动 Shizuku',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => service.openShizukuApp(),
                icon: const Icon(Icons.open_in_new),
                label: const Text('打开 Shizuku'),
              ),
            ] else if (!service.hasShizukuPermission) ...[
              const Text('需要授权 Shizuku 权限才能保活无障碍服务'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => service.requestShizukuPermission(),
                icon: const Icon(Icons.security),
                label: const Text('请求权限'),
              ),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  const Text('Shizuku 已就绪'),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_fix_high, size: 16, color: Colors.blue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        service.isAccessibilityEnabled 
                          ? '自动保活已启用，每30秒检查一次'
                          : '检测到无障碍服务未启用',
                        style: const TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (!service.isAccessibilityEnabled)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : () async {
                        setState(() => _isLoading = true);
                        try {
                          final result = await service.enableAccessibilityViaShizuku();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result 
                                  ? '无障碍服务已启用' 
                                  : '启用失败，请确保 Shizuku 已正常运行'),
                                backgroundColor: result ? Colors.green : Colors.red,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isLoading = false);
                            await _loadData();
                          }
                        }
                      },
                      icon: _isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.accessibility_new),
                      label: Text(_isLoading ? '启用中...' : '通过 Shizuku 启用无障碍'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '点击按钮将通过 Shizuku 自动授权并启用无障碍服务',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              else
                const Text(
                  '无障碍服务将每 30 秒自动检查并保活',
                  style: TextStyle(color: Colors.grey),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWirelessAdbSection() {
    if (_wirelessDebugGuide == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.computer, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  '无线调试设置',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildStepItem('1', _wirelessDebugGuide!['step1'] ?? ''),
            _buildStepItem('2', _wirelessDebugGuide!['step2'] ?? ''),
            _buildStepItem('3', _wirelessDebugGuide!['step3'] ?? ''),
            _buildStepItem('4', _wirelessDebugGuide!['step4'] ?? ''),
            
            const SizedBox(height: 12),
            
            // ADB 命令
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'ADB 命令',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () {
                          if (_adbCommand != null) {
                            Clipboard.setData(ClipboardData(text: _adbCommand!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('命令已复制到剪贴板')),
                            );
                          }
                        },
                        tooltip: '复制命令',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _wirelessDebugGuide!['command'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            Text(
              '设备 IP: ${_wirelessDebugGuide!['deviceIp'] ?? '未知'}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                '说明',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• 无障碍服务用于读取屏幕文字，实现点读功能\n'
            '• 部分系统会在后台清理时关闭无障碍服务\n'
            '• Shizuku 方式可自动重新启用被关闭的无障碍服务\n'
            '• 应用会每30秒检查一次，并在前后台切换时自动检查\n'
            '• 如果检测到无障碍服务被关闭，会自动尝试重启\n'
            '• 无线调试方式需要每次重启设备后重新执行命令',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Future<void> _openAccessibilitySettings() async {
    try {
      const platform = MethodChannel('com.example.know_you/accessibility');
      await platform.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      print('Failed to open accessibility settings: $e');
    }
  }
}
