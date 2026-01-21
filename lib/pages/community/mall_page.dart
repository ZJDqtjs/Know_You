import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'product_detail_page.dart';

class MallPage extends StatelessWidget {
  const MallPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          // Search Bar
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Container(
                height: 36.h,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 12.w),
                    const Icon(Icons.search, color: Colors.grey),
                    SizedBox(width: 8.w),
                    Text('搜索商品', style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
                  ],
                ),
              ),
            ),
          ),
          
          // Categories
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCategoryItem('我的订单', Icons.receipt_long, Colors.orange),
                  _buildCategoryItem('健康食品', Icons.local_dining, Colors.green),
                  _buildCategoryItem('老年用品', Icons.accessibility_new, Colors.blue),
                  _buildCategoryItem('特价优惠', Icons.local_offer, Colors.red),
                ],
              ),
            ),
          ),
          
          SliverToBoxAdapter(child: SizedBox(height: 10.h)),
          
          // Reccomended Goods Grid
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10.w,
                crossAxisSpacing: 10.w,
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _buildProductCard(index, context);
                },
                childCount: 10,
              ),
            ),
          ),
          
          SliverToBoxAdapter(child: SizedBox(height: 80.h)),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(String title, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24.sp),
        ),
        SizedBox(height: 8.h),
        Text(title, style: TextStyle(fontSize: 12.sp)),
      ],
    );
  }

  Widget _buildProductCard(int index, BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(index: index),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Placeholder
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.vertical(top: Radius.circular(8.r)),
              ),
              child: Center(
                child: Icon(Icons.image, size: 40.sp, color: Colors.grey[400]),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '商品名称示例 ${index + 1} - 适合老年人使用的生活好物',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  '¥ ${(index + 1) * 19.9}',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '已售 ${index * 100}+',
                  style: TextStyle(color: Colors.grey, fontSize: 10.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}
