import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../common/api.dart';
import '../../common/auth_provider.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  String? _selectedGender;
  DateTime? _selectedBirthday;
  bool _isLoading = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user != null) {
      _nicknameController.text = user['nickname'] ?? '';
      _selectedGender = user['gender'];
      _avatarUrl = user['avatar'];
      if (user['birthday'] != null) {
        try {
          _selectedBirthday = DateTime.parse(user['birthday']);
        } catch (e) {
          print('Parse birthday error: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    try {
      final payload = <String, dynamic>{};
      
      if (_nicknameController.text.isNotEmpty) {
        payload['nickname'] = _nicknameController.text;
      }
      
      if (_selectedGender != null) {
        payload['gender'] = _selectedGender;
      }
      
      if (_selectedBirthday != null) {
        payload['birthday'] = _selectedBirthday!.toIso8601String().split('T')[0];
      }

      if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
        payload['avatar'] = _avatarUrl;
      }

      final updatedUser = await Api.auth.updateMe(payload);
      
      // Update auth provider
      if (mounted) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        auth.updateUser(updatedUser);
        
        Fluttertoast.showToast(msg: '保存成功');
        Navigator.pop(context);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '保存失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() => _selectedBirthday = picked);
    }
  }

  Future<void> _pickImage() async {
    // Show info toast
    Fluttertoast.showToast(msg: '图片上传功能需要安装 image_picker 包');
    
    // To implement full image picker functionality:
    // 1. Add image_picker to pubspec.yaml: flutter pub add image_picker
    // 2. Uncomment the following code:
    /*
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        await _uploadAvatar(image.path);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '选择图片失败: $e');
    }
    */
  }

  Future<void> _uploadAvatar(String filePath) async {
    setState(() => _isLoading = true);
    try {
      final result = await Api.auth.uploadAvatar(filePath);
      
      // Handle different response formats
      String? avatarUrl;
      if (result is Map) {
        avatarUrl = result['url'] ?? result['data'];
      } else if (result is String) {
        avatarUrl = result;
      }

      if (avatarUrl != null) {
        setState(() => _avatarUrl = avatarUrl);
        Fluttertoast.showToast(msg: '头像上传成功');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '上传失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑资料'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50.w,
                        backgroundColor: const Color(0xFFE1BEE7),
                        backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                            ? NetworkImage(_avatarUrl!)
                            : null,
                        child: _avatarUrl == null || _avatarUrl!.isEmpty
                            ? Icon(Icons.person, size: 50.w, color: Colors.white)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 18.w,
                          backgroundColor: Colors.green,
                          child: Icon(Icons.camera_alt, size: 16.w, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 30.h),
              
              // Nickname
              Text('昵称', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 10.h),
              TextFormField(
                controller: _nicknameController,
                decoration: InputDecoration(
                  hintText: '请输入昵称',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入昵称';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20.h),
              
              // Gender
              Text('性别', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 10.h),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
                ),
                hint: const Text('请选择性别'),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('男')),
                  DropdownMenuItem(value: 'female', child: Text('女')),
                  DropdownMenuItem(value: 'other', child: Text('其他')),
                ],
                onChanged: (value) => setState(() => _selectedGender = value),
              ),
              SizedBox(height: 20.h),
              
              // Birthday
              Text('生日', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 10.h),
              InkWell(
                onTap: _selectBirthday,
                child: InputDecorator(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedBirthday != null
                            ? '${_selectedBirthday!.year}-${_selectedBirthday!.month.toString().padLeft(2, '0')}-${_selectedBirthday!.day.toString().padLeft(2, '0')}'
                            : '请选择生日',
                        style: TextStyle(
                          color: _selectedBirthday != null ? Colors.black : Colors.grey,
                        ),
                      ),
                      const Icon(Icons.calendar_today, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
