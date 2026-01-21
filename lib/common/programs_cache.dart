import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgramsCache {
  static const _prefsKey = 'saved_app_packages';
  static const _defaultPackages = [
    'com.tencent.mm', // WeChat
    'com.ss.android.ugc.aweme', // Douyin
  ];

  static List<String>? _savedPackages;
  static List<AppInfo>? _cachedApps;
  static Future<void>? _loadingFuture;
  static List<AppInfo>? _allAppsWithIcon;
  static Future<List<AppInfo>>? _allAppsLoadingFuture;

  static bool get hasCache => _cachedApps != null;

  static List<AppInfo> get cachedApps => List<AppInfo>.from(_cachedApps ?? const []);

  static List<String> get savedPackages => List<String>.from(_savedPackages ?? const []);

  static Future<List<String>> loadSavedPackages() async {
    final packages = await _loadSavedPackages();
    return List<String>.from(packages);
  }

  static Future<void> preload() async {
    await _ensureLoaded();
  }

  static Future<List<AppInfo>> getApps({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _cachedApps = null;
    }
    await _ensureLoaded();
    return cachedApps;
  }

  static Future<void> addPackage(String packageName) async {
    final packages = await _loadSavedPackages();
    if (!packages.contains(packageName)) {
      packages.add(packageName);
      await _savePackages(packages);
      if (_allAppsWithIcon != null) {
        _cachedApps = _buildCachedApps(packages, _allAppsWithIcon!);
      } else {
        _cachedApps = null;
        await _ensureLoaded();
      }
    }
  }

  static Future<void> removePackage(String packageName) async {
    final packages = await _loadSavedPackages();
    if (packages.remove(packageName)) {
      await _savePackages(packages);
      if (_allAppsWithIcon != null) {
        _cachedApps = _buildCachedApps(packages, _allAppsWithIcon!);
      } else if (_cachedApps != null) {
        _cachedApps!.removeWhere((app) => app.packageName == packageName);
      } else {
        _cachedApps = null;
        await _ensureLoaded();
      }
    }
  }

  static Future<void> _ensureLoaded() async {
    if (_cachedApps != null) return;
    if (_loadingFuture != null) {
      await _loadingFuture;
      return;
    }

    _loadingFuture = _loadAppsInternal();
    await _loadingFuture;
    _loadingFuture = null;
  }

  static Future<void> _loadAppsInternal() async {
    final packages = await _loadSavedPackages();

    final allApps = await InstalledApps.getInstalledApps(
      excludeSystemApps: true,
      withIcon: true,
    );

    _allAppsWithIcon = allApps;

    _cachedApps = _buildCachedApps(packages, allApps);
  }

  static List<AppInfo> _buildCachedApps(List<String> packages, List<AppInfo> allApps) {
    final map = {
      for (final app in allApps) app.packageName: app,
    };

    final loadedApps = <AppInfo>[];
    for (final pkg in packages) {
      final app = map[pkg];
      if (app != null) {
        loadedApps.add(app);
      }
    }
    return loadedApps;
  }

  static Future<List<AppInfo>> getAllAppsWithIcon({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _allAppsWithIcon = null;
    }
    if (_allAppsWithIcon != null) {
      return List<AppInfo>.from(_allAppsWithIcon!);
    }
    if (_allAppsLoadingFuture != null) {
      return _allAppsLoadingFuture!;
    }

    _allAppsLoadingFuture = InstalledApps.getInstalledApps(
      excludeSystemApps: true,
      withIcon: true,
    ).then((apps) {
      _allAppsWithIcon = apps;
      return List<AppInfo>.from(apps);
    }).whenComplete(() {
      _allAppsLoadingFuture = null;
    });

    return _allAppsLoadingFuture!;
  }

  static Future<List<String>> _loadSavedPackages() async {
    if (_savedPackages != null) return _savedPackages!;

    final prefs = await SharedPreferences.getInstance();
    final savedList = prefs.getStringList(_prefsKey);

    if (savedList == null || savedList.isEmpty) {
      _savedPackages = List<String>.from(_defaultPackages);
      await prefs.setStringList(_prefsKey, _savedPackages!);
    } else {
      _savedPackages = List<String>.from(savedList);
    }

    return _savedPackages!;
  }

  static Future<void> _savePackages(List<String> packages) async {
    _savedPackages = List<String>.from(packages);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _savedPackages!);
  }
}
