import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'post_detail_page.dart';

class TreeHolePage extends StatefulWidget {
  const TreeHolePage({super.key});

  @override
  State<TreeHolePage> createState() => _TreeHolePageState();
}

class _TreeHolePageState extends State<TreeHolePage> {
  final List<Map<String, dynamic>> _posts = [
    {
      'username': '老张头',
      'avatar': 'assets/images/user.png',
      'time': '10分钟前',
      'title': '今天公园里的花开得真好',
      'content': '今天早上和老伴一起去公园散步，看到玉兰花都开了，心情特别好。',
      'hasVoice': true,
      'voiceDuration': '15"',
      'likes': 12,
      'comments': 3,
    },
    {
      'username': '李大妈',
      'avatar': 'assets/images/user.png',
      'time': '1小时前',
      'title': '求助：怎么做红烧肉不腻？',
      'content': '孙子这周末要来吃饭，点名要吃红烧肉，但我每次做都觉得太腻了，有没有什么窍门？',
      'hasVoice': false,
      'likes': 28,
      'comments': 15,
    },
    {
      'username': '王大爷',
      'avatar': 'assets/images/user.png',
      'time': '3小时前',
      'title': '书法练习打卡',
      'content': '练习书法第三年了，感觉今天写的这几个字有点进步。大家帮忙指点一下。',
      'image': 'assets/images/calligraphy_placeholder.png', // Placeholder
      'hasVoice': true,
      'voiceDuration': '30"',
      'likes': 56,
      'comments': 8,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: ListView.builder(
        padding: EdgeInsets.only(bottom: 80.h),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          return _buildPostItem(post);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showVoicePostDialog,
        backgroundColor: Colors.green,
        icon: const Icon(Icons.mic),
        label: const Text('语音发帖'),
      ),
    );
  }

  Widget _buildPostItem(Map<String, dynamic> post) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailPage(post: post),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 20.r,
                backgroundImage: AssetImage(post['avatar']),
                // Fallback icon if image fails
                onBackgroundImageError: (_, __) {},
                child: post['avatar'] == null ? const Icon(Icons.person) : null,
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post['username'],
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    post['time'],
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12.h),
          
          // Title & Content
          if (post['title'] != null)
            Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Text(
                post['title'],
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Text(
            post['content'],
            style: TextStyle(fontSize: 15.sp, height: 1.5),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          
          // Voice Player Placeholder
          if (post['hasVoice'] == true) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded, color: Colors.green, size: 24.sp),
                  SizedBox(width: 8.w),
                  // Voice waveform visual placeholder
                  SizedBox(
                    width: 100.w,
                    height: 20.h,
                    child: CustomPaint(painter: WaveformPainter()),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    post['voiceDuration'],
                    style: TextStyle(color: Colors.green, fontSize: 13.sp),
                  ),
                ],
              ),
            ),
          ],
          
          SizedBox(height: 16.h),
          
          // Footer Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInteractionButton(Icons.favorite_border, post['likes'].toString()),
              _buildInteractionButton(Icons.chat_bubble_outline, post['comments'].toString()),
              _buildInteractionButton(Icons.share_outlined, '分享'),
            ],
          ),
        ],
      ),
    ));
  }

  Widget _buildInteractionButton(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20.sp, color: Colors.grey[600]),
        SizedBox(width: 4.w),
        Text(
          text,
          style: TextStyle(color: Colors.grey[600], fontSize: 13.sp),
        ),
      ],
    );
  }

  void _showVoicePostDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const VoicePostSheet(),
    );
  }
}

class VoicePostSheet extends StatefulWidget {
  const VoicePostSheet({super.key});

  @override
  State<VoicePostSheet> createState() => _VoicePostSheetState();
}

class _VoicePostSheetState extends State<VoicePostSheet> {
  bool _isRecording = false;
  String _statusText = '按住说话';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _isRecording ? '正在录音...' : '点击录音分享新鲜事',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 40.h),
          GestureDetector(
            onLongPressStart: (_) {
              setState(() {
                _isRecording = true;
                _statusText = '松开结束';
              });
              // Initial Mock recording start LOGIC here
            },
            onLongPressEnd: (_) async {
              setState(() {
                _isRecording = false;
                _statusText = '按住说话';
              });
              
              // Mock API Call Process
              _showProcessingDialog();
            },
            child: Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                color: _isRecording ? Colors.green.shade700 : Colors.green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    spreadRadius: 5,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(Icons.mic, color: Colors.white, size: 40.sp),
            ),
          ),
          SizedBox(height: 20.h),
          Text(_statusText, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
  
  void _showProcessingDialog() {
    Navigator.pop(context); // Close sheet
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              SizedBox(height: 20.h),
              const Text('正在转换语音并生成标题...'),
              SizedBox(height: 10.h),
              const Text('(模拟调用 API)', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
    
    // Fake delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        Fluttertoast.showToast(msg: "发布成功！\n标题：今天天气真不错\nAI已自动生成封面");
      }
    });
  }
}

class WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    for (double x = 0; x < size.width; x += 4) {
      double height = (x % 3 + 1) * 3.0 + (x % 5) * 2;
      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
