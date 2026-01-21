import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'tree_hole_page.dart';
import 'mall_page.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('社区生活'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.green, // Selected color
          unselectedLabelColor: Colors.black, // Unselected color
          indicatorColor: Colors.green,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: '树洞广场'),
            Tab(text: '颐养商城'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          TreeHolePage(),
          MallPage(),
        ],
      ),
    );
  }
}
