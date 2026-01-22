import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class PhonebookPage extends StatefulWidget {
  const PhonebookPage({super.key});

  @override
  State<PhonebookPage> createState() => _PhonebookPageState();
}

class _PhonebookPageState extends State<PhonebookPage> {
  final List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final String? contactsJson = prefs.getString('saved_contacts');
    
    if (contactsJson != null) {
      final List<dynamic> decoded = jsonDecode(contactsJson);
      _contacts.clear();
      _contacts.addAll(decoded.cast<Map<String, dynamic>>());
    } else {
      // Defaults
      _contacts.addAll([
        {
          'id': 1,
          'name': '龙琪曼',
          'phone': '19883306989',
          'avatar': 'assets/images/long.jpg',
          'isAsset': true
        },
        {
          'id': 2,
          'name': '王元洪',
          'phone': '19533066850',
          'avatar': 'assets/images/wang.jpg',
          'isAsset': true
        },
        {
          'id': 3,
          'name': '左浩媛',
          'phone': '15393306416',
          'avatar': 'assets/images/zuo.jpg',
          'isAsset': true
        }
      ]);
      await _saveContacts();
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_contacts', jsonEncode(_contacts));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('电话本')),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: EdgeInsets.all(18.w),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 20.w,
                mainAxisSpacing: 20.w,
                childAspectRatio: 0.72,
              ),
              itemCount: _contacts.length + 1,
              itemBuilder: (context, index) {
                if (index == _contacts.length) {
                  return _buildAddContactItem();
                }
                return _buildContactItem(_contacts[index]);
              },
            ),
    );
  }

  Widget _buildContactItem(Map<String, dynamic> contact) {
    ImageProvider avatarImage;
    if (contact['isAsset'] == true) {
      avatarImage = AssetImage(contact['avatar']);
    } else if (contact['avatar'] != null && File(contact['avatar']).existsSync()) {
      avatarImage = FileImage(File(contact['avatar']));
    } else {
       avatarImage = const AssetImage('assets/images/avatar.svg'); // Fallback
    }

    return GestureDetector(
      onTap: () => _makeCall(contact['phone']),
      onLongPress: () => _confirmRemoveContact(contact),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 20.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipOval(
              child: Image(
                image: avatarImage,
                width: 80.w,
                height: 80.w,
                fit: BoxFit.cover,
                errorBuilder: (c,e,s) => Container(width: 80.w, height: 80.w, color: Colors.grey[300], child: Icon(Icons.person, size: 40.sp)),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              contact['name'],
              style: TextStyle(fontSize: 28.sp, color: const Color(0xFF333333), fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            SizedBox(height: 8.h),
            Text(
              contact['phone'],
              style: TextStyle(fontSize: 20.sp, color: const Color(0xFF666666)),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddContactItem() {
    return GestureDetector(
      onTap: _showAddContactDialog,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: const Color(0xFF4CAF50), width: 2.w),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60.w,
              height: 60.w,
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('+', style: TextStyle(color: Colors.white, fontSize: 40.sp, fontWeight: FontWeight.w300)),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              '添加联系人',
              style: TextStyle(fontSize: 28.sp, color: const Color(0xFF4CAF50), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // --- Add Contact Logic ---

  Future<void> _showAddContactDialog() async {
    String name = '';
    String phone = '';
    String? avatarPath;
    
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    
    // ignore: use_build_context_synchronously
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BottomSheetContext) { // Use explicit type or rename to avoid shadowing
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Container(
              height: 0.85.sh,
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              ),
              child: Column(
                children: [
                  Text('添加联系人', style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.bold)),
                  SizedBox(height: 30.h),
                  
                  // Avatar Picker
                  GestureDetector(
                    onTap: () async {
                      final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
                      if (image != null) {
                         setSheetState(() {
                           avatarPath = image.path;
                         });
                      }
                    },
                    child: CircleAvatar(
                      radius: 50.r,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: avatarPath != null ? FileImage(File(avatarPath!)) : null,
                      child: avatarPath == null ? Icon(Icons.camera_alt, size: 40.sp, color: Colors.grey) : null,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  
                  // Name Field
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: '姓名',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  
                  // Phone Field with Picker
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: '电话',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.contacts),
                        onPressed: () async {
                           // Pick from contacts
                           if (await FlutterContacts.requestPermission()) {
                             final contact = await FlutterContacts.openExternalPick();
                             if (contact != null) {
                               setSheetState(() {
                                 nameController.text = contact.displayName;
                                 if (contact.phones.isNotEmpty) {
                                   phoneController.text = contact.phones.first.number;
                                 }
                                 // Note: External pick might not return photo data directly on all platforms
                                 // We stick to name/phone for simplicity or fetch full contact if needed.
                               });
                             }
                           } else {
                             Fluttertoast.showToast(msg: "需要通讯录权限");
                           }
                        },
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                          final newContact = {
                            'id': DateTime.now().millisecondsSinceEpoch,
                            'name': nameController.text,
                            'phone': phoneController.text,
                            'avatar': avatarPath,
                            'isAsset': false,
                          };
                          Navigator.pop(context, newContact);
                        } else {
                          Fluttertoast.showToast(msg: "请填写完整信息");
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                      ),
                      child: Text('保存', style: TextStyle(fontSize: 18.sp)),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    ).then((result) {
      if (result != null && result is Map<String, dynamic>) {
        setState(() {
          _contacts.add(result);
          _saveContacts();
        });
      }
    });
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        Fluttertoast.showToast(msg: "无法拨打电话");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "拨号失败: $e");
    }
  }

  void _confirmRemoveContact(Map<String, dynamic> contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除联系人'),
        content: Text('确定要删除 "${contact['name']}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeContact(contact);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _removeContact(Map<String, dynamic> contact) {
    setState(() {
      _contacts.remove(contact);
    });
    _saveContacts();
    Fluttertoast.showToast(msg: "联系人已删除");
  }
}
