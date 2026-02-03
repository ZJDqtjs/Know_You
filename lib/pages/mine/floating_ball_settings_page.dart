import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../common/floating_ball_service.dart';
import '../../common/voice_assistant_service.dart';

class FloatingBallSettingsPage extends StatelessWidget {
  const FloatingBallSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('悬浮球设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          Consumer<FloatingBallService>(
            builder: (context, service, _) {
              return SwitchListTile(
                title: const Text('屏幕朗读悬浮球'),
                subtitle: Text(service.isEnabled ? '已开启' : '已关闭'),
                value: service.isEnabled,
                onChanged: (value) {
                  if (value) {
                    service.enable(context);
                  } else {
                    service.disable();
                  }
                },
              );
            },
          ),
          const Divider(),
          Consumer<VoiceAssistantService>(
            builder: (context, service, _) {
              return SwitchListTile(
                title: const Text('语音助手悬浮球'),
                subtitle: Text(service.isEnabled ? '已开启' : '已关闭'),
                value: service.isEnabled,
                onChanged: (value) async {
                  if (value) {
                    await service.enable();
                  } else {
                    service.disable();
                  }
                },
              );
            },
          ),
          SizedBox(height: 12.h),
          Text(
            '关闭后将不再显示悬浮球按钮，可在此页面重新开启。',
            style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
