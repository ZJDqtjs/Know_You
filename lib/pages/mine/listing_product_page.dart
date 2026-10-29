import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../common/api.dart';
import '../../common/app_config.dart';
import '../../widgets/common_card.dart';

class ListingProductPage extends StatefulWidget {
  const ListingProductPage({super.key});

  @override
  State<ListingProductPage> createState() => _ListingProductPageState();
}

class _ListingProductPageState extends State<ListingProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  final _stockController = TextEditingController();
  
  String? _imageUrl;
  File? _imageFile;
  bool _isUploading = false;
  bool _isSubmitting = false;

  List<dynamic> _categories = [];
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await Api.mall.listCategories();
      if (res is List) {
        setState(() {
          _categories = res;
          if (_categories.isNotEmpty) {
            _selectedCategoryId = _categories[0]['id'];
          }
        });
      }
    } catch (e) {
      print('Fetch categories error: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _isUploading = true;
      });

      try {
        final res = await Api.auth.uploadAvatar(pickedFile.path); // Function name is uploadAvatar but it's generic file upload
        setState(() {
          _imageUrl = res['url'];
        });
        Fluttertoast.showToast(msg: '图片上传成功');
      } catch (e) {
        Fluttertoast.showToast(msg: '图片上传失败: $e');
        setState(() {
            _imageFile = null;
        });
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
        Fluttertoast.showToast(msg: '请填写完整信息');
        return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
        await Api.mall.createProduct({
            'name': _nameController.text,
            'price': double.tryParse(_priceController.text) ?? 0,
            'desc': _descController.text,
            'stock': int.tryParse(_stockController.text) ?? 0,
            'image_url': _imageUrl,
            'category_id': _selectedCategoryId,
        });
        Fluttertoast.showToast(msg: '发布成功');
        if (mounted) Navigator.pop(context);
    } catch(e) {
        Fluttertoast.showToast(msg: '发布失败: $e');
    } finally {
        if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('商品上架'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 50.h),
        child: Column(
          children: [
            SizedBox(height: 10.h),
            
            // Image Upload
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 150.w,
                height: 150.w,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: Colors.grey[400]!),
                  image: _imageFile != null
                    ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                    : (_imageUrl != null ? DecorationImage(image: NetworkImage(AppConfig.currentOrDefault.resolveHttpUrl(_imageUrl!)), fit: BoxFit.cover) : null),
                ),
                child: _isUploading
                  ? const Center(child: CircularProgressIndicator())
                  : (_imageFile == null && _imageUrl == null
                      ? Icon(Icons.add_a_photo, size: 50.w, color: Colors.grey[600])
                      : null),
              ),
            ),
            SizedBox(height: 10.h),
            const Text('点击上传商品图片', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 20.h),
            
            CommonCard(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: '商品名称', hintText: '请输入商品名称'),
                      validator: (v) => v == null || v.isEmpty ? '请输入商品名称' : null,
                    ),
                    SizedBox(height: 10.h),
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: '价格 (元)', hintText: '0.00'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => v == null || v.isEmpty ? '请输入价格' : null,
                    ),
                    SizedBox(height: 10.h),
                    TextFormField(
                      controller: _stockController,
                      decoration: const InputDecoration(labelText: '库存数量', hintText: '0'),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 10.h),
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: '商品分类'),
                      value: _selectedCategoryId,
                      items: _categories.map((c) {
                        return DropdownMenuItem<int>(
                          value: c['id'],
                          child: Text(c['name']),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                    ),
                    SizedBox(height: 10.h),
                    TextFormField(
                      controller: _descController,
                      decoration: const InputDecoration(labelText: '商品描述', hintText: '请输入详细描述'),
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 30.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('立即上架', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
