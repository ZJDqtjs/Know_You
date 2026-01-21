import 'dart:typed_data';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../common/programs_cache.dart';

class ProgramsPage extends StatefulWidget {
  const ProgramsPage({super.key});

  @override
  State<ProgramsPage> createState() => _ProgramsPageState();
}

class _ProgramsPageState extends State<ProgramsPage> {
  bool _isLoading = true;
  
  final List<AppInfo> _displayedApps = [];

  @override
  void initState() {
    super.initState();
    if (ProgramsCache.hasCache) {
      _displayedApps.addAll(ProgramsCache.cachedApps);
      _isLoading = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadApps();
    });
  }

  Future<void> _loadApps({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        if (_displayedApps.isEmpty) {
          _isLoading = true;
        }
      });
    }

    try {
      final loadedApps = await ProgramsCache.getApps(forceRefresh: forceRefresh);
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
    final searchController = TextEditingController();
    final availableAppsFuture = _loadAvailableApps();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: 0.85.sh,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 16.w, 16.w, 8.w),
                    child: Text('添加应用', style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.w),
                    child: TextField(
                      controller: searchController,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        hintText: '搜索应用名称',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                        contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                      ),
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<List<AppInfo>>(
                      future: availableAppsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return const Center(child: Text('加载失败，请稍后重试'));
                        }
                        final allApps = snapshot.data ?? const [];
                        final query = searchController.text.trim().toLowerCase();
                        final filteredApps = query.isEmpty
                            ? allApps
                            : allApps.where((app) {
                                final name = (app.name ?? '').toLowerCase();
                                return name.contains(query);
                              }).toList();

                        if (filteredApps.isEmpty) {
                          return const Center(child: Text('未找到匹配应用'));
                        }

                        return ListView.builder(
                          itemCount: filteredApps.length,
                          itemBuilder: (context, index) {
                            final app = filteredApps[index];
                            return ListTile(
                              leading: app.icon != null
                                  ? Image.memory(app.icon!, width: 80.w, height: 80.w)
                                  : const Icon(Icons.apps),
                              title: Text(app.name ?? '', style: TextStyle(fontSize: 28.sp)),
                              onTap: () async {
                                Navigator.pop(context);
                                await _addApp(app.packageName);
                              },
                            );
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
      },
    );
  }

  Future<List<AppInfo>> _loadAvailableApps() async {
    final allApps = await ProgramsCache.getAllAppsWithIcon();
    final savedPackages = await ProgramsCache.loadSavedPackages();
    final availableApps = allApps.where((app) => !savedPackages.contains(app.packageName)).toList();
    availableApps.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
    return availableApps;
  }

  Future<void> _addApp(String? packageName) async {
    if (packageName == null) return;
    await ProgramsCache.addPackage(packageName);
    if (mounted) {
      setState(() {
        _displayedApps
          ..clear()
          ..addAll(ProgramsCache.cachedApps);
        _isLoading = false;
      });
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
    await ProgramsCache.removePackage(packageName);
    if (mounted) {
      setState(() {
        _displayedApps.removeWhere((app) => app.packageName == packageName);
        _isLoading = false;
      });
    }
    Fluttertoast.showToast(msg: "应用已移除");
  }
}
