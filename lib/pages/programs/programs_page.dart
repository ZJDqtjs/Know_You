import 'dart:typed_data';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgramsPage extends StatefulWidget {
  const ProgramsPage({super.key});

  @override
  State<ProgramsPage> createState() => _ProgramsPageState();
}

class _ProgramsPageState extends State<ProgramsPage> {
  bool _isLoading = true;
  
  // Default configured apps
  final List<String> _savedPackageNames = [];
  final List<AppInfo> _displayedApps = [];

  @override
  void initState() {
    super.initState();
    _loadSavedApps();
  }

  Future<void> _loadSavedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final savedList = prefs.getStringList('saved_app_packages');
    
    if (savedList != null) {
      _savedPackageNames.addAll(savedList);
    } else {
      // Add defaults if first run
      _savedPackageNames.addAll([
        'com.tencent.mm', // WeChat
        'com.ss.android.ugc.aweme', // Douyin
      ]);
      await prefs.setStringList('saved_app_packages', _savedPackageNames);
    }

    await _refreshDisplayedApps();
  }

  Future<void> _refreshDisplayedApps() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // InstalledApps.getInstalledApps args are named arguments in 2.1.0 version
      final allApps = await InstalledApps.getInstalledApps(excludeSystemApps: true, withIcon: true);
      
      List<AppInfo> loadedApps = [];
      for (var savedPkg in _savedPackageNames) {
        try {
          // Find in list
          final match = allApps.where((a) => a.packageName == savedPkg).firstOrNull;
          if (match != null) {
            loadedApps.add(match);
          }
        } catch (e) {
          debugPrint('Error finding app $savedPkg: $e');
        }
      }
      
      if (mounted) {
        setState(() {
          _displayedApps.clear();
          _displayedApps.addAll(loadedApps);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAddAppDialog() async {
    // Show loading indictor first while fetching all apps
    showDialog(context: context,  barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    
    try {
      final allApps = await InstalledApps.getInstalledApps(excludeSystemApps: true, withIcon: true);
      
      if (mounted) Navigator.pop(context); // Close loading

      if (!mounted) return;

      // Filter out already added apps
      final availableApps = allApps.where((app) => !_savedPackageNames.contains(app.packageName)).toList();
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            height: 0.8.sh,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Text('添加应用', style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: availableApps.length,
                    itemBuilder: (context, index) {
                      final app = availableApps[index];
                      return ListTile(
                        leading: app.icon != null ? Image.memory(app.icon!, width: 80.w, height: 80.w) : Icon(Icons.android, size: 80.w),
                        title: Text(app.name ?? '', style: TextStyle(fontSize: 28.sp)),
                        onTap: () async {
                          Navigator.pop(context);
                          await _addApp(app.packageName);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading if error
      Fluttertoast.showToast(msg: "获取应用列表失败");
    }
  }

  Future<void> _addApp(String? packageName) async {
    if (packageName == null) return;
    if (!_savedPackageNames.contains(packageName)) {
      _savedPackageNames.add(packageName);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('saved_app_packages', _savedPackageNames);
      await _refreshDisplayedApps();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('程序')),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: EdgeInsets.all(20.w),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 20.w,
                mainAxisSpacing: 20.w,
                childAspectRatio: 0.8,
              ),
              itemCount: _displayedApps.length + 1,
              itemBuilder: (context, index) {
                 if (index == _displayedApps.length) {
                   return _buildAddAppItem();
                 }
                 return _buildAppItem(_displayedApps[index]);
              },
            ),
    );
  }

  Widget _buildAppItem(AppInfo app) {
    return GestureDetector(
      onTap: () => _launchApp(app.packageName),
      onLongPress: () => _confirmRemoveApp(app),
      child: Container(
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
            ClipRRect(
              borderRadius: BorderRadius.circular(20.r),
              child: app.icon != null 
                ? Image.memory(
                    app.icon!,
                    width: 120.w,
                    height: 120.w,
                    fit: BoxFit.cover,
                  )
                : Icon(Icons.android, size: 120.w, color: Colors.green),
            ),
            SizedBox(height: 16.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Text(
                app.name ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28.sp,
                  color: const Color(0xFF333333),
                  fontWeight: FontWeight.w500
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddAppItem() {
    return GestureDetector(
      onTap: _showAddAppDialog,
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
              '添加应用',
              style: TextStyle(fontSize: 28.sp, color: const Color(0xFF4CAF50), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchApp(String packageName) async {
    try {
      await InstalledApps.startApp(packageName);
    } catch (e) {
      Fluttertoast.showToast(msg: "无法打开应用: $e");
    }
  }

  void _confirmRemoveApp(AppInfo app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除应用'),
        content: Text('确定要移除 "${app.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeApp(app.packageName);
            },
            child: const Text('移除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _removeApp(String packageName) async {
    if (_savedPackageNames.contains(packageName)) {
      _savedPackageNames.remove(packageName);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('saved_app_packages', _savedPackageNames);
      await _refreshDisplayedApps();
      Fluttertoast.showToast(msg: "应用已移除");
    }
  }
}
