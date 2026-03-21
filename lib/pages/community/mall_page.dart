import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../common/api.dart';
import '../../common/app_config.dart';
import 'product_detail_page.dart';

class MallPage extends StatefulWidget {
  const MallPage({super.key});

  @override
  State<MallPage> createState() => _MallPageState();
}

class _MallPageState extends State<MallPage> {
  final List<Map<String, dynamic>> _categories = [];
  final List<Map<String, dynamic>> _products = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _keywordController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  final int _pageSize = 20;
  int? _activeCategoryId;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchProducts(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _fetchProducts();
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await Api.mall.listCategories();
      final list = res is List ? List<Map<String, dynamic>>.from(res) : <Map<String, dynamic>>[];
      setState(() {
        _categories
          ..clear()
          ..addAll(list);
      });
    } catch (e) {
      Fluttertoast.showToast(msg: '加载分类失败');
    }
  }

  Future<void> _fetchProducts({bool refresh = false}) async {
    if (_isLoading || _isLoadingMore) return;
    if (refresh) {
      setState(() {
        _isLoading = true;
        _page = 1;
        _hasMore = true;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final keyword = _keywordController.text.trim().isEmpty ? null : _keywordController.text.trim();
      dynamic res;
      if (keyword == null && _activeCategoryId == null) {
        try {
          res = await Api.recommendation.listRecommendedProducts(page: _page, pageSize: _pageSize);
        } catch (_) {
          res = await Api.mall.listProducts(page: _page, pageSize: _pageSize);
        }
      } else {
        // 用户主动搜索/筛选时使用精确检索列表。
        res = await Api.mall.listProducts(
          page: _page,
          pageSize: _pageSize,
          keyword: keyword,
          categoryId: _activeCategoryId,
        );
      }
      final list = (res is Map && res['list'] is List) ? List<Map<String, dynamic>>.from(res['list']) : <Map<String, dynamic>>[];
      setState(() {
        if (refresh) {
          _products
            ..clear()
            ..addAll(list);
        } else {
          _products.addAll(list);
        }
        _hasMore = list.length >= _pageSize;
        if (_hasMore) _page += 1;
      });
    } catch (e) {
      Fluttertoast.showToast(msg: '加载商品失败');
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _showOrders() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final res = await Api.mall.listOrders(page: 1, pageSize: 20);
      final list = (res is Map && res['list'] is List) ? List<Map<String, dynamic>>.from(res['list']) : <Map<String, dynamic>>[];
      if (mounted) Navigator.pop(context);
      if (!mounted) return;

      if (list.isEmpty) {
        Fluttertoast.showToast(msg: '暂无订单');
        return;
      }

      showModalBottomSheet(
        context: context,
        builder: (_) => ListView.separated(
          padding: EdgeInsets.all(16.w),
          itemCount: list.length,
          separatorBuilder: (_, __) => SizedBox(height: 12.h),
          itemBuilder: (_, index) {
            final order = list[index];
            return Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.r),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('订单 #${order['id']}', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6.h),
                  Text('状态：${order['status'] ?? '--'}', style: TextStyle(color: Colors.grey[700], fontSize: 12.sp)),
                  SizedBox(height: 6.h),
                  Text('总价：¥ ${order['totalPrice'] ?? '--'}', style: TextStyle(color: Colors.red, fontSize: 13.sp)),
                ],
              ),
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      Fluttertoast.showToast(msg: '加载订单失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        controller: _scrollController,
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
                    Expanded(
                      child: TextField(
                        controller: _keywordController,
                        decoration: InputDecoration(
                          hintText: '搜索商品',
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 14.sp),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (v) {
                          final keyword = v.trim();
                          if (keyword.isNotEmpty) {
                            Api.recommendation.trackEvent(
                              scene: 'search',
                              action: 'search',
                              targetType: 'keyword',
                              keyword: keyword,
                            ).catchError((_) {});
                          }
                          _fetchProducts(refresh: true);
                        },
                      ),
                    ),
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
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(width: 12.w),
                    _buildCategoryItem('我的订单', Icons.receipt_long, Colors.orange, onTap: _showOrders),
                    ..._categories.map((c) => _buildCategoryItem(
                      c['name'] ?? '分类',
                      Icons.local_offer,
                      Colors.green,
                      selected: _activeCategoryId == c['id'],
                      onTap: () {
                        setState(() => _activeCategoryId = c['id']);
                        _fetchProducts(refresh: true);
                      },
                    )),
                    SizedBox(width: 12.w),
                  ],
                ),
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
                  final product = _products[index];
                  return _buildProductCard(product, context);
                },
                childCount: _products.length,
              ),
            ),
          ),
          
          if (_isLoading || _isLoadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: 80.h)),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(String title, IconData icon, Color color, {VoidCallback? onTap, bool selected = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: selected ? color.withOpacity(0.25) : color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24.sp),
            ),
            SizedBox(height: 8.h),
            Text(title, style: TextStyle(fontSize: 12.sp)),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, BuildContext context) {
    final imageUrl = product['imageUrl'];
    return GestureDetector(
      onTap: () {
        final productId = product['id'];
        if (productId is int) {
          Api.recommendation.trackEvent(
            scene: 'mall',
            action: 'click',
            targetType: 'product',
            targetId: productId,
          ).catchError((_) {});
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(product: product),
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
          // Image
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.vertical(top: Radius.circular(8.r)),
              ),
              child: Center(
                child: imageUrl is String && imageUrl.isNotEmpty
                    ? Image.network(AppConfig.currentOrDefault.resolveHttpUrl(imageUrl), fit: BoxFit.cover)
                    : Icon(Icons.image, size: 40.sp, color: Colors.grey[400]),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] ?? '商品',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  '¥ ${product['price'] ?? '--'}',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '已售 ${product['soldCount'] ?? 0}+',
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
