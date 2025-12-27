import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../common/auth_provider.dart';
import '../../widgets/common_card.dart';
import '../phonebook/phonebook_page.dart';
import '../programs/programs_page.dart';

class IndexPage extends StatefulWidget {
  const IndexPage({super.key});

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> {
  int _currentSwiper = 0;
  final PageController _pageController = PageController();

  final List<String> _banners = [
    'assets/static/images/lunbo1.jpg',
    'assets/static/images/lunbo2.jpg',
    'assets/static/images/lunbo3.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final userName = (user != null && (user['nickname'] != null || user['username'] != null))
        ? (user['nickname'] ?? user['username'])
        : '请登录';
    // Handle avatar URL: if relative, make absolute. But here we use local assets or network
    // The original code uses upload.toAbsoluteUrl.
    // For now, use local placeholder if null.
    // userAvatar = (user && user.avatar) ? upload.toAbsoluteUrl(user.avatar) : '/static/images/avatar.svg'

    return Scaffold(
      appBar: AppBar(
        title: const Text('主页'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            CommonCard(
              child: Row(
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/static/images/avatar.svg', // Placeholder
                      width: 55.w,
                      height: 55.w,
                      fit: BoxFit.cover,
                      errorBuilder: (c,e,s) => Container(color: Colors.grey[200], width: 55.w, height: 55.w),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(fontSize: 18.sp, color: const Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '早上好',
                        style: TextStyle(fontSize: 22.sp, color: const Color(0xFF1B5E20), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Banner
            CommonCard(
              padding: EdgeInsets.zero,
              child: SizedBox(
                height: 120.h,
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: _banners.length,
                      onPageChanged: (index) => setState(() => _currentSwiper = index),
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40.w), // To match "width: 70%" sort of
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10.r),
                            child: Image.asset(
                              _banners[index],
                              fit: BoxFit.cover,
                              errorBuilder: (c,e,s) => Container(color: Colors.grey[300], child: const Center(child: Icon(Icons.image))),
                            ),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      left: 10.w,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2E7D32)),
                          onPressed: () {
                            if (_currentSwiper > 0) {
                              _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                            }
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10.w,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, color: Color(0xFF2E7D32)),
                          onPressed: () {
                            if (_currentSwiper < _banners.length - 1) {
                              _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Health Data
            CommonCard(
              child: Column(
                children: [
                  _buildHealthItem('assets/static/images/icon-weather.svg', '今日天气', '7°C~18°C'),
                  SizedBox(height: 10.h),
                  _buildHealthItem('assets/static/images/icon-sleep.svg', '睡眠时长', '8小时48分钟'),
                  SizedBox(height: 10.h),
                  _buildHealthItem('assets/static/images/icon-bp.svg', '血压', '收缩压: 125mmHg 舒张压: 75mmHg'),
                  SizedBox(height: 10.h),
                  _buildHealthItem('assets/static/images/icon-heart.svg', '心率', '平均心率: 70次/分'),
                ],
              ),
            ),

            // Modules
            CommonCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildModuleItem('assets/static/images/icon-phonebook.png', '电话本', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PhonebookPage()),
                    );
                  }),
                  _buildModuleItem('assets/static/images/icon-programs.png', '程序', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProgramsPage()),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthItem(String iconPath, String label, String value) {
    return Container(
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFC8E6C9)),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          Image.asset(iconPath, width: 30.w, height: 30.w, errorBuilder: (c,e,s) => Icon(Icons.health_and_safety, size: 30.w, color: Colors.green)),
          SizedBox(width: 12.w),
          Text(label, style: TextStyle(fontSize: 15.sp, color: const Color(0xFF43A047), fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 14.sp, color: const Color(0xFF666666))),
        ],
      ),
    );
  }

  Widget _buildModuleItem(String iconPath, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Image.asset(iconPath, width: 90.w, height: 90.w, errorBuilder: (c,e,s) => Container(color: Colors.green[100], width: 90.w, height: 90.w)),
          SizedBox(height: 8.h),
          Text(label, style: TextStyle(fontSize: 16.sp, color: const Color(0xFF2E7D32), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
