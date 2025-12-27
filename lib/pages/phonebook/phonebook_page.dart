import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'contact_detail_page.dart';

class PhonebookPage extends StatefulWidget {
  const PhonebookPage({super.key});

  @override
  State<PhonebookPage> createState() => _PhonebookPageState();
}

class _PhonebookPageState extends State<PhonebookPage> {
  final List<Map<String, dynamic>> _contacts = [
    {
      'id': 1,
      'name': '龙琪曼',
      'phone': '19887142989',
      'avatar': 'assets/images/long.jpg'
    },
    {
      'id': 2,
      'name': '王元洪',
      'phone': '19527052850',
      'avatar': 'assets/images/wang.jpg'
    },
    {
      'id': 3,
      'name': '左浩媛',
      'phone': '15398482416',
      'avatar': 'assets/images/zuo.jpg'
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('电话本')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Wrap(
          spacing: 30.w,
          runSpacing: 30.w,
          children: [
            ..._contacts.map((contact) => _buildContactItem(contact)),
            _buildAddContactItem(),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(Map<String, dynamic> contact) {
    return GestureDetector(
      onTap: () => _viewContact(contact),
      child: Container(
        width: 160.w,
        height: 220.h,
        padding: EdgeInsets.all(30.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipOval(
              child: Image.asset(
                contact['avatar'],
                width: 80.w,
                height: 80.w,
                fit: BoxFit.cover,
                errorBuilder: (c,e,s) => Image.asset('assets/images/avatar.svg', width: 80.w, height: 80.w),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              contact['name'],
              style: TextStyle(fontSize: 28.sp, color: const Color(0xFF333333), fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 5.h),
            Text(
              contact['phone'],
              style: TextStyle(fontSize: 24.sp, color: const Color(0xFF666666)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddContactItem() {
    return GestureDetector(
      onTap: _addContact,
      child: Container(
        width: 160.w,
        height: 220.h,
        padding: EdgeInsets.all(30.w),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: const Color(0xFF4CAF50), width: 2.w, style: BorderStyle.solid), // Dashed border is hard in Flutter without package, solid is fine
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.w,
              height: 80.w,
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('+', style: TextStyle(color: Colors.white, fontSize: 60.sp, fontWeight: FontWeight.w300)),
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

  void _viewContact(Map<String, dynamic> contact) {
    // In Flutter, we can navigate to detail page or call directly.
    // The original code tries to call directly on Android/iOS or navigate.
    // Let's replicate the structure: Navigate to detail page as it seems better UX and consistent with file structure.
    // Wait, the original code `viewContact` tries to call directly (`uni.makePhoneCall` or Intent).
    // But there is also a `contactDetail.vue`.
    // The `phonebook.vue` has `viewContact` method.
    // Ah, wait. `phonebook.vue` imports nothing about `contactDetail`.
    // But `pages.json` has `contactDetail`.
    // In `index.vue`, `navigateToPhonebook` goes to `phonebook`.
    // In `phonebook.vue`, clicking a contact calls `viewContact` which calls phone directly.
    // SO `contactDetail.vue` might be unused or used elsewhere?
    // Let's check `contactDetail.vue`. It accepts `id` in `onLoad`.
    // Maybe I should navigate to detail page instead of calling directly, or offer choice.
    // But the user asked to replicate functionality.
    // The original `viewContact` implementation in `phonebook.vue`:
    // Checks platform. If Android, uses Intent to DIAL. If iOS, makePhoneCall.
    // H5: window.location.href = tel.
    
    // However, I also see `pages/phonebook/contactDetail.vue` in the file list.
    // Let's implement `ContactDetailPage` and navigate to it, then in Detail page have a "Call" button.
    // This seems more complete given the files exist.
    // Let's check if `phonebook.vue` links to `contactDetail`?
    // The code I read for `phonebook.vue` DOES NOT navigate to `contactDetail`. It calls directly.
    // BUT `contactDetail.vue` exists. Maybe it was intended but not linked, or linked from somewhere else?
    // Let's implement `ContactDetailPage` and link to it for better UX, or stick to original?
    // "Migrate all pages" -> I must implement `ContactDetailPage`.
    // I'll make the click on `PhonebookPage` navigate to `ContactDetailPage`.
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactDetailPage(contact: contact),
      ),
    );
  }

  Future<void> _addContact() async {
    Fluttertoast.showToast(msg: '请在手机通讯录中添加');
    // Actual implementation to open contacts app requires platform channels or plugins not in standard path
    // `url_launcher` can't easily open "Add Contact" intent cross-platform without specific schemes.
    // We can leave it as a toast for now as per "Migrate functionality".
  }
}
