import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../common/api.dart';
import '../../common/app_config.dart';

class PostManagePage extends StatefulWidget {
  const PostManagePage({super.key});

  @override
  State<PostManagePage> createState() => _PostManagePageState();
}

class _PostManagePageState extends State<PostManagePage> {
  final List<Map<String, dynamic>> _posts = [];
  bool _loading = false;
  int _page = 1;
  final int _pageSize = 20;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPosts(refresh: true);
  }

  String _resolveUrl(String? path) {
    return AppConfig.currentOrDefault.resolveHttpUrl(path);
  }

  Future<void> _fetchPosts({bool refresh = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (refresh) {
        _page = 1;
        _hasMore = true;
      }
    });
    try {
      final res = await Api.community.listMyPosts(page: _page, pageSize: _pageSize);
      final list = (res is Map && res['list'] is List) ? List<Map<String, dynamic>>.from(res['list']) : <Map<String, dynamic>>[];
      setState(() {
        if (refresh) {
          _posts
            ..clear()
            ..addAll(list);
        } else {
          _posts.addAll(list);
        }
        _hasMore = list.length >= _pageSize;
        if (_hasMore) _page += 1;
      });
    } catch (e) {
      setState(() => _error = e.toString());
      Fluttertoast.showToast(msg: '加载我的帖子失败');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    final postId = post['id'];
    if (postId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除确认'),
        content: const Text('确定要删除这条帖子吗？删除后不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.community.deletePost(postId);
      setState(() => _posts.removeWhere((p) => p['id'] == postId));
      Fluttertoast.showToast(msg: '已删除');
    } catch (e) {
      Fluttertoast.showToast(msg: '删除失败');
    }
  }

  Widget _buildImageThumb(List<String> images) {
    if (images.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: Image.network(
        _resolveUrl(images.first),
        width: 64.w,
        height: 64.w,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 64.w,
          height: 64.w,
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> post) {
    final title = post['title'] ?? '未命名';
    final content = post['content'] ?? ((post['has_voice'] == true || post['hasVoice'] == true) ? '语音内容' : '');
    final images = (post['images'] is List) ? (post['images'] as List).cast<String>() : <String>[];
    return Container(
      padding: EdgeInsets.all(12.w),
      margin: EdgeInsets.symmetric(vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageThumb(images),
          if (images.isNotEmpty) SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 4.h),
                Text(content, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _deletePost(post),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('帖子管理')),
      body: RefreshIndicator(
        onRefresh: () => _fetchPosts(refresh: true),
        child: ListView.builder(
          padding: EdgeInsets.all(12.w),
          itemCount: _posts.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _posts.length) {
              if (!_loading) _fetchPosts();
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: const Center(child: CircularProgressIndicator()),
              );
            }
            return _buildItem(_posts[index]);
          },
        ),
      ),
    );
  }
}
