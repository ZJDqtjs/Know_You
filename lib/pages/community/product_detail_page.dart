import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../common/api.dart';

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  Map<String, dynamic>? _product;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _product = Map<String, dynamic>.from(widget.product);
    _fetchProduct();
  }

  int? get _productId {
    final id = _product?['id'] ?? widget.product['id'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id);
    return null;
  }

  Future<void> _fetchProduct() async {
    final productId = _productId;
    if (productId == null) return;
    setState(() => _isLoading = true);
    try {
      final res = await Api.mall.getProduct(productId);
      if (res is Map) {
        setState(() => _product = Map<String, dynamic>.from(res));
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '加载商品失败');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _product ?? widget.product;
    final imageUrl = product['imageUrl'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('商品详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image
                  Container(
                    height: 300.h,
                    color: Colors.grey[200],
                    child: Center(
                      child: imageUrl is String && imageUrl.isNotEmpty
                          ? Image.network(imageUrl, fit: BoxFit.cover)
                          : Icon(Icons.image, size: 100.sp, color: Colors.grey[400]),
                    ),
                  ),
                  
                  Container(
                    color: Colors.white,
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Price
                        Row(
                          children: [
                            Text(
                              '¥',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${product['price'] ?? '--'}',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 28.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                '活动价',
                                style: TextStyle(color: Colors.red, fontSize: 10.sp),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        
                        // Title
                        Text(
                          product['name'] ?? '商品',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        
                        // Sales info
                        Row(
                          children: [
                            Text(
                              '已售 ${product['soldCount'] ?? 0}+',
                              style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                            ),
                            const Spacer(),
                            Text(
                              '广东广州',
                              style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 10.h),
                  
                  // Details Section
                  Container(
                    color: Colors.white,
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '商品详情',
                          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 16.h),
                        Container(
                          height: 200.h,
                          width: double.infinity,
                          color: Colors.grey[100],
                          child: Center(
                            child: Text(
                              product['desc'] ?? '暂无详情描述',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const LinearProgressIndicator(minHeight: 2),
          
          // Bottom Action Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 5,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  _buildBottomIcon(Icons.store, '店铺'),
                  _buildBottomIcon(Icons.chat_bubble_outline, '客服'),
                  _buildBottomIcon(Icons.star_border, '收藏'),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      child: Text('加入购物车', style: TextStyle(fontSize: 16.sp)),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      child: Text('立即购买', style: TextStyle(fontSize: 16.sp)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomIcon(IconData icon, String label) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24.sp, color: Colors.grey[700]),
          Text(label, style: TextStyle(fontSize: 10.sp, color: Colors.grey[700])),
        ],
      ),
    );
  }
}
