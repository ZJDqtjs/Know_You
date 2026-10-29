import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../common/api.dart';
import '../../common/app_config.dart';

class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailPage({super.key, required this.post});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late bool _isLiked;
  late int _likeCount;
  Map<String, dynamic>? _post;
  bool _isLoadingPost = false;
  bool _isLoadingComments = false;
  
  // Voice Input Logic
  bool _isRecordingComment = false;
  bool _isRecognizingComment = false;
  bool _showVoiceButton = true; 
  String? _commentAudioPath;
  final ValueNotifier<int> _voiceState = ValueNotifier(0); // 0:Recording, 1:Cancel, 2:Transcribe
  OverlayEntry? _overlayEntry;

  String? _asrLanguage;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<Map<String, dynamic>> _comments = [];
  late final AudioRecorder _commentRecorder;
  late final AudioPlayer _durationProbe;
  static const String _languagePrefKey = 'asr_language';

  @override
  void initState() {
    super.initState();
    _post = Map<String, dynamic>.from(widget.post);
    _isLiked = widget.post['liked'] ?? false;
    _likeCount = widget.post['likes'] ?? 0;
    _commentRecorder = AudioRecorder();
    _durationProbe = AudioPlayer();
    _loadAsrLanguage();
    _fetchPost();
    _fetchComments();
  }

  @override
  void dispose() {
    _commentRecorder.dispose();
    _durationProbe.dispose();
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _resolveUrl(String? path) {
    return AppConfig.currentOrDefault.resolveHttpUrl(path);
  }

  int? get _postId {
    final id = _post?['id'] ?? widget.post['id'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id);
    return null;
  }

  Future<void> _fetchPost() async {
    final postId = _postId;
    if (postId == null) return;
    setState(() => _isLoadingPost = true);
    try {
      final res = await Api.community.getPost(postId);
      if (res is Map) {
        setState(() {
          _post = Map<String, dynamic>.from(res);
          _isLiked = res['liked'] ?? _isLiked;
          _likeCount = res['likes'] ?? _likeCount;
        });
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '加载帖子失败');
    } finally {
      setState(() => _isLoadingPost = false);
    }
  }

  Future<void> _fetchComments() async {
    final postId = _postId;
    if (postId == null) return;
    setState(() => _isLoadingComments = true);
    try {
      final res = await Api.community.listComments(postId, page: 1, pageSize: 50);
      final list = (res is Map && res['list'] is List) ? List<Map<String, dynamic>>.from(res['list']) : <Map<String, dynamic>>[];
      setState(() {
        _comments
          ..clear()
          ..addAll(list);
      });
    } catch (e) {
      Fluttertoast.showToast(msg: '加载评论失败');
    } finally {
      setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _loadAsrLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _asrLanguage = prefs.getString(_languagePrefKey) ?? '中文');
  }

  void _showVoiceOverlay(BuildContext context) {
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: Material(
          color: Colors.black54, // Dim background
          child: Stack(
            children: [
              // Cancel Area Trigger Visualization
              Positioned(
                bottom: 0,
                left: 0,
                child: ValueListenableBuilder<int>(
                  valueListenable: _voiceState,
                  builder: (context, state, _) {
                    final isHover = state == 1; // Cancel state
                    return Container(
                      width: 160.w, // Large trigger zone
                      height: 160.w,
                      alignment: Alignment.center,
                      // Shifted for visual balance
                      padding: EdgeInsets.only(top: 40.w, right: 20.w),
                       child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           // Circular Button
                           Container(
                             width: 80.w, // Enlarge button size
                             height: 80.w,
                             decoration: BoxDecoration(
                               shape: BoxShape.circle,
                               color: isHover ? Colors.red : Colors.grey[400], // Cancel side is red/grey
                             ),
                             child: Icon(Icons.close, color: Colors.white, size: 36.sp), // White icon
                           ),
                           SizedBox(height: 12.h),
                           // Label
                           Text('松手取消', style: TextStyle(color: Colors.white70, fontSize: 14.sp)),
                        ],
                       ),
                    );
                  },
                ),
              ),
              // Transcribe Area Trigger Visualization
              Positioned(
                bottom: 0,
                right: 0,
                child: ValueListenableBuilder<int>(
                  valueListenable: _voiceState,
                  builder: (context, state, _) {
                    final isHover = state == 2; // Transcribe state
                    return Container(
                      width: 160.w,
                      height: 160.w,
                      alignment: Alignment.center,
                      padding: EdgeInsets.only(top: 40.w, left: 20.w),
                       child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           // Circular Button
                           Container(
                             width: 80.w, // Enlarge button size
                             height: 80.w,
                             decoration: BoxDecoration(
                               shape: BoxShape.circle,
                               color: isHover ? Colors.blue : Colors.grey[400], // Transcribe side is blue/grey
                             ),
                             child: Icon(Icons.translate, color: Colors.white, size: 36.sp), // White icon
                           ),
                           SizedBox(height: 12.h),
                           // Label
                           Text('转文字', style: TextStyle(color: Colors.white70, fontSize: 14.sp)),
                        ],
                       ),
                    );
                  },
                ),
              ),
              // Central Indicator
              Center(
                child: ValueListenableBuilder<int>(
                  valueListenable: _voiceState,
                  builder: (context, state, _) {
                     Color bg = const Color(0xCC5BBE7B); // Green
                     if (state == 1) bg = const Color(0xCCFA5151); // Red
                     if (state == 2) bg = const Color(0xCC5BBE7B); // Green

                     IconData icon = Icons.mic;
                     if (state == 1) icon = Icons.close;
                     try {
                        if (state == 2) icon  = Icons.translate;
                     } catch(e) {/* ignore */}
                     
                     String text = '松开发送';
                     if (state == 1) text = '松手取消';
                     if (state == 2) text = '松手编辑文字';

                     return Container(
                       width: 160.w,
                       height: 160.w,
                       decoration: BoxDecoration(
                         color: bg,
                         borderRadius: BorderRadius.circular(20.r),
                       ),
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                             Icon(icon, color: Colors.white, size: 60.sp),
                             SizedBox(height: 16.h),
                             Text(text, style: TextStyle(color: Colors.white, fontSize: 14.sp)),
                         ],
                       ),
                     );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideVoiceOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _startCommentRecording(LongPressStartDetails details) async {
    if (await Permission.microphone.request().isGranted) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/comment_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _commentRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      _voiceState.value = 0;
      _showVoiceOverlay(context);
      setState(() {
        _isRecordingComment = true;
        _commentAudioPath = path;
      });
    } else {
      Fluttertoast.showToast(msg: '需要麦克风权限');
    }
  }

  Future<void> _stopCommentRecording(LongPressEndDetails details) async {
    if (!_isRecordingComment) return;
    _hideVoiceOverlay();
    try {
      final path = await _commentRecorder.stop();
      setState(() => _isRecordingComment = false);
      
      final state = _voiceState.value;
      if (path != null) {
        if (state == 1) { // Cancel
          return;
        }
        if (state == 2) { // Transcribe
          await _recognizeCommentAudio(path);
          setState(() {
             _showVoiceButton = false;
          });
          Future.delayed(const Duration(milliseconds: 100), () {
             FocusScope.of(context).requestFocus(_focusNode);
          });
          return;
        }
        // Send
        await _sendVoiceComment(path);
      }
    } catch (_) {
      if (mounted) setState(() => _isRecordingComment = false);
    }
  }

  void _onRecordingMove(LongPressMoveUpdateDetails details) {
    final dx = details.localOffsetFromOrigin.dx;
    final dy = details.localOffsetFromOrigin.dy;
    
    // If dragging up significantly > 50
    // Screen width usually 360-400
    // Cancel < -60, Transcribe > 60
    
    int newState = 0;
    if (dy < -20) { // Must drag up a bit to engage
        if (dx < -60) {
            newState = 1;
        } else if (dx > 60) {
            newState = 2;
        }
    }
    
    if (_voiceState.value != newState) {
      _voiceState.value = newState;
    }
  }

  Future<void> _sendVoiceComment(String path) async {
    final postId = _postId;
    if (postId == null) return;
    try {
      await _durationProbe.setSourceDeviceFile(path);
      final d = await _durationProbe.getDuration();
      int? duration = d?.inSeconds;
      final upload = await Api.auth.uploadAvatar(path);
      final voiceUrl = upload is Map ? upload['url']?.toString() : null;
      if (voiceUrl == null || voiceUrl.isEmpty) {
        Fluttertoast.showToast(msg: '语音上传失败');
        return;
      }
      final res = await Api.community.addComment(postId, voiceUrl: voiceUrl, voiceDuration: duration);
      if (res is Map) {
        setState(() {
          _comments.insert(0, Map<String, dynamic>.from(res));
        });
      }
      Fluttertoast.showToast(msg: '语音已发送');
    } catch (_) {
      Fluttertoast.showToast(msg: '发送失败');
    }
  }

  Future<void> _recognizeCommentAudio(String path) async {
    setState(() => _isRecognizingComment = true);
    try {
      final asrBaseUrl = AppConfig.currentOrDefault.asrBaseUrl;
      if (asrBaseUrl == null || asrBaseUrl.isEmpty) return;
      final dio = Dio(BaseOptions(baseUrl: asrBaseUrl, connectTimeout: const Duration(seconds: 30)));
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(path, filename: 'comment_audio.mp3'),
        'language': _asrLanguage ?? '中文',
        'itn': 'true',
      });
      final res = await dio.post('/asr', data: form);
      if (res.statusCode == 200 && res.data is Map && res.data['text'] != null) {
        final text = res.data['text'].toString();
        if (mounted) {
          if (_commentController.text.isEmpty) {
            _commentController.text = text;
          } else {
            _commentController.text = '${_commentController.text}\n$text';
          }
        }
      }
    } catch (_) {
      Fluttertoast.showToast(msg: '语音转文字失败');
    } finally {
      if (mounted) setState(() => _isRecognizingComment = false);
    }
  }

  Future<void> _toggleLike() async {
    final postId = _postId;
    if (postId == null) return;
    try {
      final res = await Api.community.toggleLike(postId);
      if (res is Map) {
        setState(() {
          _isLiked = res['liked'] ?? _isLiked;
          _likeCount = res['like_count'] ?? res['likeCount'] ?? _likeCount;
        });
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '操作失败');
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final postId = _postId;
    if (postId == null) return;

    try {
      final res = await Api.community.addComment(postId, content: text);
      if (res is Map) {
        setState(() {
          _comments.insert(0, Map<String, dynamic>.from(res));
          _commentController.clear();
        });
      }
      FocusScope.of(context).unfocus();
    } catch (e) {
      Fluttertoast.showToast(msg: '评论失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post ?? widget.post;
    return Scaffold(
      appBar: AppBar(
        title: const Text('帖子详情'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingPost && post.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: EdgeInsets.all(16.w),
                    children: [
                      _buildPostContent(post),
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

  Widget _buildPostContent(Map<String, dynamic> post) {
    final username = post['username'] ?? post['user']?['username'] ?? '匿名用户';
    final avatar = post['avatar'] ?? post['user']?['avatar'];
    final timeText = _formatTime(post['time']);
    final images = post['images'] ?? post['image_urls'] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24.r,
              backgroundColor: const Color(0xFFE1BEE7),
              backgroundImage: avatar is String && avatar.isNotEmpty
                  ? NetworkImage(_resolveUrl(avatar))
                  : null,
              child: avatar == null || !(avatar is String && avatar.isNotEmpty)
                  ? Text(
                      (username.isNotEmpty ? username : 'U')[0].toUpperCase(),
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.white),
                    )
                  : null,
            ),
            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
                Text(
                  timeText,
                  style: TextStyle(color: Colors.grey, fontSize: 13.sp),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 16.h),
        if (post['title'] != null)
          Text(
            post['title'],
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
          ),
        SizedBox(height: 12.h),
        Text(
                  post['content'] ?? ((post['has_voice'] == true || post['hasVoice'] == true) ? '语音内容' : ''),
                  style: TextStyle(fontSize: 16.sp, height: 1.6),
                ),
                if (images is List && images.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  _buildImageGrid(images.cast<String>()),
                ],
                if (post['has_voice'] == true || post['hasVoice'] == true) ...[
                  SizedBox(height: 16.h),
                  _VoicePlayer(
                    voiceUrl: _resolveUrl(post['voice_url'] ?? post['voiceUrl']),
                    duration: post['voice_duration'] ?? post['voiceDuration'],
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
        if (_isLoadingComments)
          const Center(child: CircularProgressIndicator()),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _comments.length,
          separatorBuilder: (context, index) => SizedBox(height: 16.h),
          itemBuilder: (context, index) {
            final comment = _comments[index];
            final username = comment['username'] ?? comment['user']?['username'] ?? '匿名用户';
            final avatar = comment['avatar'] ?? comment['user']?['avatar'];
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18.r,
                  backgroundColor: const Color(0xFFE1BEE7),
                  backgroundImage: avatar is String && avatar.isNotEmpty
                      ? NetworkImage(_resolveUrl(avatar))
                      : null,
                  child: avatar == null || !(avatar is String && avatar.isNotEmpty)
                      ? Text(
                          (username.isNotEmpty ? username : 'U')[0].toUpperCase(),
                          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.white),
                        )
                      : null,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                      ),
                      SizedBox(height: 4.h),
                      if (comment['is_voice'] == true || comment['isVoice'] == true)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 4.h),
                          child: _VoicePlayer(
                            voiceUrl: _resolveUrl(comment['voice_url'] ?? comment['voiceUrl']),
                            duration: comment['voice_duration'] ?? comment['voiceDuration'],
                          ),
                        )
                      else
                        Text(
                          comment['content'] ?? '',
                          style: TextStyle(fontSize: 15.sp),
                        ),
                      SizedBox(height: 4.h),
                      Text(
                        _formatTime(comment['time']),
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
              width: 90.w,
              height: 90.w,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 90.w,
                height: 90.w,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBottomInputArea() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        border: Border(top: BorderSide(color: Colors.grey[300]!, width: 0.5)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _showVoiceButton = !_showVoiceButton;
                  if (_showVoiceButton) {
                    FocusScope.of(context).unfocus();
                  } else {
                    FocusScope.of(context).requestFocus(_focusNode);
                  }
                });
              },
              child: Container(
                padding: EdgeInsets.all(8.w),
                child: Icon(
                  _showVoiceButton ? Icons.keyboard : Icons.keyboard_voice,
                  color: Colors.black87,
                  size: 28.sp,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _showVoiceButton
                  ? GestureDetector(
                      onLongPressStart: _startCommentRecording,
                      onLongPressMoveUpdate: _onRecordingMove,
                      onLongPressEnd: _stopCommentRecording,
                      child: Container(
                        height: 40.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4.r),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '按住 说话',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, color: Colors.black87),
                        ),
                      ),
                    )
                  : Container(
                      height: 40.h,
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: TextField(
                        controller: _commentController,
                        focusNode: _focusNode,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.only(bottom: 10),
                        ),
                        onSubmitted: (_) => _addComment(),
                      ),
                    ),
            ),
            SizedBox(width: 8.w),
            if (_isRecognizingComment) ...[
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8.w),
            ],
            GestureDetector(
              onTap: _addComment,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4.r)
                ),
                child: Text('发送', style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
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
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: Colors.green,
              size: 30.sp,
            ),
            SizedBox(width: 12.w),
            SizedBox(
              width: 120.w,
              height: 20.h,
              child: CustomPaint(painter: WaveformPainter()),
            ),
            SizedBox(width: 12.w),
            Text(
              _formatDuration(widget.duration),
              style: TextStyle(color: Colors.green, fontSize: 14.sp),
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
