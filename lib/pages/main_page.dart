import 'package:flutter/material.dart';
import 'index/index_page.dart';
import 'familyGuard/family_guard_page.dart';
import 'mine/mine_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  final List<Widget> _pages = const [
    IndexPage(),
    FamilyGuardPage(),
    MinePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: Image.asset('assets/static/images/home.png', width: 24, height: 24, errorBuilder: (c,e,s) => const Icon(Icons.home)),
            activeIcon: Image.asset('assets/static/images/home-active.png', width: 24, height: 24, errorBuilder: (c,e,s) => const Icon(Icons.home, color: Colors.green)),
            label: '主页',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/static/images/family.png', width: 24, height: 24, errorBuilder: (c,e,s) => const Icon(Icons.favorite)),
            activeIcon: Image.asset('assets/static/images/family-active.png', width: 24, height: 24, errorBuilder: (c,e,s) => const Icon(Icons.favorite, color: Colors.green)),
            label: '亲情守护',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/static/images/user.png', width: 24, height: 24, errorBuilder: (c,e,s) => const Icon(Icons.person)),
            activeIcon: Image.asset('assets/static/images/user-active.png', width: 24, height: 24, errorBuilder: (c,e,s) => const Icon(Icons.person, color: Colors.green)),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
