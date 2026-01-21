import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailPage({super.key, required this.post});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late bool _isLiked;
  late int _likeCount;
  final TextEditingController _commentController = TextEditingController();
  final List<Map<String, dynamic>> _comments = [
    {
      'username': '张阿姨',
      'avatar': 'assets/images/user.png',
      'content': '说得太好了，我也经常去那个公园。',
      'time': '5分钟前',
      'isVoice': false,
    },
    {
      'username': '刘大爷',
      'avatar': 'assets/images/user.png',
      'content': 'voice_placeholder',
      'time': '10分钟前',
      'isVoice': true,
      'voiceDuration': '8"',
    },
  ];

  @override
  void initState() {
    super.initState();
    _isLiked = false; // Initial state
    _likeCount = widget.post['likes'] ?? 0;
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likeCount++;
      } else {
        _likeCount--;
      }
    });
  }

  void _addComment() {
    if (_commentController.text.isNotEmpty) {
      setState(() {
        _comments.add({
          'username': '我',
          'avatar': 'assets/images/user.png',
          'content': _commentController.text,
          'time': '刚刚',
          'isVoice': false,
        });
        _commentController.clear();
      });
      FocusScope.of(context).unfocus(); // Close keyboard
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('帖子详情'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                _buildPostContent(),
                Divider(height: 32.h),
                _buildCommentsSection(),
              ],
            ),
          ),
          _buildBottomInputArea(),
        ],
      ),
    );
  }

  Widget _buildPostContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24.r,
              backgroundImage: AssetImage(widget.post['avatar'] ?? 'assets/images/user.png'),
              onBackgroundImageError: (_, __) {},
              child: widget.post['avatar'] == null ? const Icon(Icons.person) : null,
            ),
            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post['username'] ?? '匿名用户',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.post['time'] ?? '',
                  style: TextStyle(color: Colors.grey, fontSize: 13.sp),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 16.h),
        if (widget.post['title'] != null)
          Text(
            widget.post['title'],
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
          ),
        SizedBox(height: 12.h),
        Text(
          widget.post['content'] ?? '',
          style: TextStyle(fontSize: 16.sp, height: 1.6),
        ),
        if (widget.post['hasVoice'] == true) ...[
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow_rounded, color: Colors.green, size: 30.sp),
                SizedBox(width: 12.w),
                Container(
                  width: 120.w,
                  height: 4.h,
                  color: Colors.green.withOpacity(0.3),
                ),
                SizedBox(width: 12.w),
                Text(
                  widget.post['voiceDuration'] ?? '',
                  style: TextStyle(color: Colors.green, fontSize: 14.sp),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: 24.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: _toggleLike,
              child: Row(
                children: [
                  Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.red : Colors.grey,
                    size: 24.sp,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    _likeCount.toString(),
                    style: TextStyle(
                      color: _isLiked ? Colors.red : Colors.grey,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '评论 (${_comments.length})',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16.h),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _comments.length,
          separatorBuilder: (context, index) => SizedBox(height: 16.h),
          itemBuilder: (context, index) {
            final comment = _comments[index];
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18.r,
                  backgroundImage: AssetImage(comment['avatar']),
                  child: const Icon(Icons.person, size: 20),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment['username'],
                        style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                      ),
                      SizedBox(height: 4.h),
                      if (comment['isVoice'] == true)
                        Container(
                          width: 100.w,
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.mic, size: 16.sp, color: Colors.green),
                              SizedBox(width: 4.w),
                              Text(
                                comment['voiceDuration'] ?? '10"',
                                style: TextStyle(color: Colors.green, fontSize: 12.sp),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          comment['content'],
                          style: TextStyle(fontSize: 15.sp),
                        ),
                      SizedBox(height: 4.h),
                      Text(
                        comment['time'],
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomInputArea() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mic, color: Colors.grey[600]),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  hintText: '说点什么...',
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _addComment(),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          GestureDetector(
            onTap: _addComment,
            child: Icon(Icons.send, color: Colors.green, size: 28.sp),
          ),
        ],
      ),
    );
  }
}
