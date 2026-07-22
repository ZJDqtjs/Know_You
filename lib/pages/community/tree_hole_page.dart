import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:file_picker/file_picker.dart'; // Keep for file safety if needed, or remove
import 'package:dio/dio.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../common/api.dart';
import '../../common/app_config.dart';
import 'post_detail_page.dart';

class TreeHolePage extends StatefulWidget {
  const TreeHolePage({super.key});

  @override
  State<TreeHolePage> createState() => _TreeHolePageState();
}

class _TreeHolePageState extends State<TreeHolePage> {
  final List<Map<String, dynamic>> _posts = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  final int _pageSize = 20;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPosts(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _fetchPosts();
    }
  }

  Future<void> _fetchPosts({bool refresh = false}) async {
    if (_isLoading || _isLoadingMore) return;
    if (refresh) {
      setState(() {
        _isLoading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      dynamic res;
      try {
        res = await Api.recommendation.listRecommendedPosts(page: _page, pageSize: _pageSize);
      } catch (_) {
        // 推荐接口不可用时降级到时间流，保证页面可用。
        res = await Api.community.listPosts(page: _page, pageSize: _pageSize);
      }
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
      Fluttertoast.showToast(msg: '加载帖子失败');
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _isLoading && _posts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _fetchPosts(refresh: true),
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.only(bottom: 80.h),
                itemCount: _posts.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _posts.length) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }
                  final post = _posts[index];
                  return _buildPostItem(post);
                },
              ),
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
    final username = post['username'] ?? post['user']?['username'] ?? '匿名用户';
    final avatar = post['avatar'] ?? post['user']?['avatar'];
    final timeText = _formatTime(post['time']);
    final titleRaw = post['title']?.toString().trim();
    final title = (titleRaw != null && titleRaw.isNotEmpty)
        ? titleRaw
        : (() {
            final c = post['content']?.toString().trim() ?? '';
            if (c.isNotEmpty) return c.length > 20 ? '${c.substring(0, 20)}...' : c;
            if (post['has_voice'] == true || post['hasVoice'] == true) return '语音动态';
            return '';
          })();
    final postImages = post['images'] ?? post['image_urls'] ?? [];
    return GestureDetector(
      onTap: () async {
        final postId = post['id'];
        if (postId is int) {
          // 点击帖子时回传行为，驱动后端画像增量更新。
          Api.recommendation.trackEvent(
            scene: 'community',
            action: 'click',
            targetType: 'post',
            targetId: postId,
          ).catchError((_) {});
        }
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
                backgroundColor: const Color(0xFFE1BEE7),
                backgroundImage: avatar is String && avatar.isNotEmpty
                    ? NetworkImage(_resolveUrl(avatar))
                    : null,
                child: avatar == null || !(avatar is String && avatar.isNotEmpty)
                    ? Text(
                        (username.isNotEmpty ? username : 'U')[0].toUpperCase(),
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.white),
                      )
                    : null,
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    timeText,
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
          if (title.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          
          if (postImages is List && postImages.isNotEmpty) ...[
            SizedBox(height: 8.h),
            _buildImageGrid(postImages.cast<String>()),
          ],

          // Voice Player Placeholder
          if (post['has_voice'] == true || post['hasVoice'] == true) ...[
            SizedBox(height: 12.h),
            _VoicePlayer(
              voiceUrl: _resolveUrl(post['voice_url'] ?? post['voiceUrl']),
              duration: post['voice_duration'] ?? post['voiceDuration'],
            ),
          ],
          
          SizedBox(height: 16.h),
          
          // Footer Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInteractionButton(Icons.favorite_border, (post['likes'] ?? 0).toString()),
              _buildInteractionButton(Icons.chat_bubble_outline, (post['comments'] ?? 0).toString()),
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

  Widget _buildImageGrid(List<String> images) {
    if (images.isEmpty) return const SizedBox.shrink();
    int count = images.length > 3 ? 3 : images.length;
    return Row(
      children: List.generate(count, (index) {
        return Padding(
          padding: EdgeInsets.only(right: 8.w),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: Image.network(
              _resolveUrl(images[index]),
              width: 80.w,
              height: 80.w,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 80.w,
                height: 80.w,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        );
      }),
    );
  }

  void _showVoicePostDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreatePostSheet(
        onPostCreated: () => _fetchPosts(refresh: true),
      ),
    );
  }

  String _resolveUrl(String? path) {
    return AppConfig.currentOrDefault.resolveHttpUrl(path);
  }

  String _formatTime(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) {
      return '${value.year}-${_two(value.month)}-${_two(value.day)} ${_two(value.hour)}:${_two(value.minute)}';
    }
    if (value is String) {
      final dt = DateTime.tryParse(value);
      if (dt != null) {
        return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}';
      }
      return value;
    }
    return value.toString();
  }

  String _formatVoiceDuration(dynamic value) {
    if (value == null) return '';
    if (value is num) return '${value.toInt()}"';
    return value.toString();
  }

  String _two(int v) => v < 10 ? '0$v' : '$v';
}

class CreatePostSheet extends StatefulWidget {
  final VoidCallback? onPostCreated;
  const CreatePostSheet({super.key, this.onPostCreated});

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final List<String> _imagePaths = [];
  String? _audioPath;
  Duration _voiceDuration = Duration.zero;
  
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isSubmitting = false;
  bool _isRecognizing = false;
  String? _asrLanguage;
  bool _languageLoading = true;

  late final AudioRecorder _recorder;
  late final AudioPlayer _player;
  
  static const String _languagePrefKey = 'asr_language';
  static const List<String> _languageOptions = [
    '中文',
    '英文',
    '日文',
    '普通话',
    '吴语',
    '粤语',
    '闽语',
    '客家话',
    '赣语',
    '湘语',
    '河南',
    '山西',
    '湖北',
    '四川',
    '重庆',
    '云南',
    '贵州',
    '广东',
    '广西',
    '山东',
    '河北',
    '江苏',
    '浙江',
    '安徽',
    '福建',
    '江西',
    '湖南',
    '陕西',
    '甘肃',
    '青海',
    '宁夏',
    '新疆',
    '内蒙古',
    '辽宁',
    '吉林',
    '黑龙江'
  ];

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
    _player = AudioPlayer();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
    _loadLanguagePreference();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString(_languagePrefKey);
    if (!mounted) return;
    setState(() {
      _asrLanguage = lang;
      _languageLoading = false;
    });
    if (lang == null) {
      Future.microtask(() => _ensureLanguageSelected());
    }
  }

  Future<bool> _ensureLanguageSelected() async {
    if (_asrLanguage != null) return true;
    final selected = await _showLanguagePicker();
    if (selected == null) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePrefKey, selected);
    if (!mounted) return true;
    setState(() => _asrLanguage = selected);
    return true;
  }

  Future<void> _changeLanguage() async {
    final selected = await _showLanguagePicker();
    if (selected == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePrefKey, selected);
    if (!mounted) return;
    setState(() => _asrLanguage = selected);
  }

  Future<String?> _showLanguagePicker() async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: EdgeInsets.all(16.w),
            height: 520.h,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('请选择语音识别语言（首次需选择）', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 12.h),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.6,
                    ),
                    itemCount: _languageOptions.length,
                    itemBuilder: (context, index) {
                      final item = _languageOptions[index];
                      final selected = item == _asrLanguage;
                      return OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: selected ? Colors.green.withOpacity(0.15) : Colors.white,
                          side: BorderSide(color: selected ? Colors.green : Colors.grey.shade300),
                        ),
                        onPressed: () => Navigator.pop(context, item),
                        child: Text(item, style: TextStyle(color: selected ? Colors.green : Colors.black87)),
                      );
                    },
                  ),
                ),
                SizedBox(height: 8.h),
                Text('后续将默认使用本次选择，可在本页更改。', style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 700.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('发布帖子', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          Divider(height: 1.h),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                   SizedBox(height: 12.h),
                   Row(
                     children: [
                       Text('识别语言：', style: TextStyle(fontSize: 14.sp, color: Colors.grey[700])),
                       Text(
                         _languageLoading ? '加载中...' : (_asrLanguage ?? '未选择'),
                         style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                       ),
                       const Spacer(),
                       TextButton(
                         onPressed: _languageLoading ? null : _changeLanguage,
                         child: const Text('更改'),
                       )
                     ],
                   ),
                   SizedBox(height: 8.h),
                   // Title Input
                   TextField(
                     controller: _titleController,
                     maxLines: 1,
                     decoration: InputDecoration(
                       hintText: '请输入标题...',
                       border: InputBorder.none,
                       filled: true,
                       fillColor: Colors.grey[50],
                     ),
                   ),
                   SizedBox(height: 10.h),
                   // Content Input (detail page text)
                   TextField(
                     controller: _contentController,
                     maxLines: 5,
                     decoration: InputDecoration(
                       hintText: '请输入详情内容（详情页展示）...',
                       border: InputBorder.none,
                       filled: true,
                       fillColor: Colors.grey[50],
                     ),
                   ),
                   if (_isRecognizing)
                     Padding(
                       padding: EdgeInsets.only(top: 8.h),
                       child: Row(
                         children: [
                           const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                           SizedBox(width: 8.w),
                           Text('正在将语音转换为文字...', style: TextStyle(fontSize: 12.sp, color: Colors.green)),
                         ],
                       ),
                     ),
                   
                   SizedBox(height: 16.h),
                   
                   // Images Grid
                   _buildImagePicker(),
                   
                   SizedBox(height: 16.h),
                   
                   // Voice Section
                   _buildVoiceSection(),
                ],
              ),
            ),
          ),
          
          // Submit Button
          ElevatedButton(
            onPressed: (_isSubmitting || _isRecording) ? null : _submitPost,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(vertical: 12.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            child: _isSubmitting 
              ? SizedBox(height: 20.h, width: 20.h, child: const CircularProgressIndicator(color: Colors.white))
              : Text('发表', style: TextStyle(fontSize: 16.sp)),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: _imagePaths.length + 1,
      itemBuilder: (context, index) {
        if (index == _imagePaths.length) {
          return GestureDetector(
            onTap: _pickImages,
            child: Container(
              color: Colors.grey[200],
              child: Icon(Icons.add_a_photo, color: Colors.grey[500]),
            ),
          );
        }
        return Stack(
          children: [
            Positioned.fill(
              child: Image.file(
                File(_imagePaths[index]),
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: GestureDetector(
                onTap: () => setState(() => _imagePaths.removeAt(index)),
                child: Container(
                  color: Colors.black54,
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVoiceSection() {
    if (_audioPath != null) {
      return Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8.r)),
        child: Row(
          children: [
             IconButton(
               icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle, color: Colors.green),
               onPressed: _togglePlay,
             ),
             Text('${_voiceDuration.inSeconds}"', style: TextStyle(fontWeight: FontWeight.bold)),
             const Spacer(),
             IconButton(
               icon: const Icon(Icons.delete, color: Colors.red),
               onPressed: () {
                 setState(() {
                   _audioPath = null;
                   _voiceDuration = Duration.zero;
                   _isPlaying = false;
                 });
                 _player.stop();
               },
             ),
          ],
        ),
      );
    }
    
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopRecording(),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 20.h),
        decoration: BoxDecoration(
          color: _isRecording ? Colors.green.withOpacity(0.2) : Colors.green[50], // Better feedback
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: Colors.green),
        ),
        child: Column(
          children: [
            Icon(Icons.mic, color: _isRecording ? Colors.red : Colors.green, size: 32.sp),
            SizedBox(height: 8.h),
            Text(_isRecording ? '松开 结束录音' : '长按 录制语音', style: TextStyle(color: Colors.green[800])),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _imagePaths.addAll(picked.map((e) => e.path));
      });
    }
  }

  Future<void> _startRecording() async {
    final ok = await _ensureLanguageSelected();
    if (!ok) return;
    if (await Permission.microphone.request().isGranted) {
      final dir = await getTemporaryDirectory();
      // Record as mp3 extension if possible, or wav. The user wants "mp3 format" for ASR.
      // Since 'record' pkg doesn't encode mp3, we use m4a/aac but rename for ASR upload.
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      setState(() => _isRecording = true);
      HapticFeedback.mediumImpact();
    } else {
      Fluttertoast.showToast(msg: '需要麦克风权限');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return; // Prevent double stop
    try {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        setState(() => _audioPath = path);
        // Get duration
        await _player.setSourceDeviceFile(path);
        final d = await _player.getDuration();
        if (d != null) setState(() => _voiceDuration = d);
        
        // Auto ASR
        _recognizeAudio(path);
      }
    } catch (e) {
      if (mounted) setState(() => _isRecording = false);
    }
  }
  
  Future<void> _togglePlay() async {
    if (_audioPath == null) return;
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.play(DeviceFileSource(_audioPath!));
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _recognizeAudio(String path) async {
    setState(() => _isRecognizing = true);
    try {
      final asrBaseUrl = AppConfig.currentOrDefault.asrBaseUrl;
      if (asrBaseUrl == null || asrBaseUrl.isEmpty) return;
      final dio = Dio(BaseOptions(baseUrl: asrBaseUrl, connectTimeout: const Duration(seconds: 30)));
      // Ensure filename ends with .mp3 as required by ASR content check or convention
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(path, filename: 'audio_record.mp3'),
        'language': _asrLanguage ?? '中文',
        'itn': 'true',
      });
      final res = await dio.post('/asr', data: form);
      if (res.statusCode == 200 && res.data is Map && res.data['text'] != null) {
        final text = res.data['text'].toString();
        if (!mounted) return;
        if (_contentController.text.trim().isEmpty) {
          _contentController.text = text; // Auto fill detail if empty
        }
        if (_titleController.text.trim().isEmpty) {
          final t = text.trim();
          if (t.isNotEmpty) {
            _titleController.text = t.length > 20 ? '${t.substring(0, 20)}...' : t;
          }
        }
      }
    } catch (e) {
      // Silent fail or toast
      // Fluttertoast.showToast(msg: '语音转文字失败');
    } finally {
      if (mounted) setState(() => _isRecognizing = false);
    }
  }

  Future<void> _submitPost() async {
    if (_contentController.text.trim().isEmpty && _audioPath == null && _imagePaths.isEmpty) {
      Fluttertoast.showToast(msg: '内容不能为空');
      return;
    }
    
    setState(() => _isSubmitting = true);
    try {
      // 1. Upload Images
      List<String> imageUrls = [];
      for (var path in _imagePaths) {
        final res = await Api.auth.uploadAvatar(path); // Reuse generic upload
        if (res is Map && res['url'] != null) {
          imageUrls.add(res['url']);
        }
      }
      
      // 2. Upload Voice
      String? voiceUrl;
      if (_audioPath != null) {
        final res = await Api.auth.uploadAvatar(_audioPath!);
        if (res is Map && res['url'] != null) {
          voiceUrl = res['url'];
        }
      }
      
      // 3. Create Post
      final content = _contentController.text.trim();
      final rawTitle = _titleController.text.trim();
      final title = rawTitle.isNotEmpty
          ? rawTitle
          : (content.isNotEmpty
              ? (content.length > 20 ? '${content.substring(0, 20)}...' : content)
              : '语音动态');
      
      await Api.community.createPost(
        title: title,
        content: content,
        voiceUrl: voiceUrl,
        voiceDuration: _voiceDuration.inSeconds,
        imageUrls: imageUrls
      );
      
      if (mounted) {
        Navigator.pop(context);
        Fluttertoast.showToast(msg: '发布成功');
        widget.onPostCreated?.call();
      }
    } catch (e) {
      if (mounted) Fluttertoast.showToast(msg: '发布失败: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _VoicePlayer extends StatefulWidget {
  final String voiceUrl;
  final dynamic duration;

  const _VoicePlayer({required this.voiceUrl, this.duration});

  @override
  State<_VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<_VoicePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  String? _cachedPath;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      try {
        if (widget.voiceUrl.isEmpty) {
          Fluttertoast.showToast(msg: '音频地址为空');
          return;
        }
        await _player.play(UrlSource(widget.voiceUrl));
        setState(() => _isPlaying = true);
      } catch (e) {
        try {
          final path = await _downloadToTemp(widget.voiceUrl);
          if (path == null) {
            Fluttertoast.showToast(msg: '音频下载失败');
            return;
          }
          await _player.play(DeviceFileSource(path));
          setState(() => _isPlaying = true);
        } catch (_) {
          Fluttertoast.showToast(msg: '音频播放失败');
        }
      }
    }
  }

  Future<String?> _downloadToTemp(String url) async {
    if (_cachedPath != null && File(_cachedPath!).existsSync()) return _cachedPath;
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/voice_cache_${url.hashCode}.m4a';
    final dio = Dio();
    await dio.download(url, filePath);
    _cachedPath = filePath;
    return filePath;
  }

  String _formatDuration(dynamic value) {
    if (value == null) return '';
    if (value is num) return '${value.toInt()}"';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: Colors.green,
              size: 28.sp,
            ),
            SizedBox(width: 8.w),
            SizedBox(
              width: 100.w,
              height: 20.h,
              child: CustomPaint(painter: WaveformPainter()),
            ),
            SizedBox(width: 8.w),
            Text(
              _formatDuration(widget.duration),
              style: TextStyle(color: Colors.green, fontSize: 13.sp),
            ),
          ],
        ),
      ),
    );
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
