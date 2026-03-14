import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import '../../common/api.dart';
import '../../common/app_config.dart';
import '../../common/auth_provider.dart';
import '../../common/programs_cache.dart';
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
  Timer? _bannerTimer;
  Timer? _syncTimer;
  Map<String, dynamic>? _latestHealth;
  Map<String, dynamic>? _localWeather;
  bool _healthLoading = false;
  bool _syncing = false;
  int? _healthUserId;
  bool _healthAuthDenied = false;
  bool _healthManualAuthInFlight = false;
  String? _weatherCity;
  String? _weatherConfigError;

  final List<String> _banners = [
    'assets/images/lunbo1.jpg',
    'assets/images/lunbo2.jpg',
    'assets/images/lunbo3.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _startBannerTimer();
    _loadHealthAuthFlag();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ProgramsCache.preload();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context);
    final userId = auth.user?['id'];
    if (userId != null && userId is int && _healthUserId != userId) {
      _healthUserId = userId;
      _startAutoSync();
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _syncTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _banners.isEmpty) return;
      final nextPage = (_currentSwiper + 1) % _banners.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  void _startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 10), (_) => _syncAll());
    _syncAll();
  }

  Future<void> _syncAll({bool allowHealthPrompt = false}) async {
    if (_healthUserId == null || _syncing) return;
    _syncing = true;
    setState(() => _healthLoading = true);
    try {
      await _syncDeviceHealth(allowPrompt: allowHealthPrompt);
      await _syncWeather();
    } finally {
      _syncing = false;
      if (mounted) setState(() => _healthLoading = false);
    }
  }

  Future<void> _syncDeviceHealth({required bool allowPrompt}) async {
    try {
      if (allowPrompt) {
        final activityStatus = await Permission.activityRecognition.request();
        if (!activityStatus.isGranted) {
          return;
        }
      }
      final now = DateTime.now();
      final startToday = DateTime(now.year, now.month, now.day);
      final startSleep = now.subtract(const Duration(hours: 24));

      final health = Health();
      await health.configure(useHealthConnectIfAvailable: true);
      final types = [HealthDataType.STEPS, HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_IN_BED];
      final permissions = [
        HealthDataAccess.READ,
        HealthDataAccess.READ,
        HealthDataAccess.READ,
      ];

      // Steps: prefer native sensor on Android
      int? steps;
      try {
        const stepChannel = MethodChannel('com.example.know_you/step_counter');
        final nativeSteps = await stepChannel.invokeMethod<dynamic>('getTodaySteps');
        if (nativeSteps != null) {
          steps = int.tryParse(nativeSteps.toString());
        }
      } catch (_) {}

      // Sleep: still use health plugin
      final authorized = await _ensureHealthPermission(health, types, permissions, allowPrompt: allowPrompt);
      if (!authorized && steps == null) return;

      final sleepData = authorized
          ? await health.getHealthDataFromTypes(
              types: [
                HealthDataType.SLEEP_ASLEEP,
                HealthDataType.SLEEP_IN_BED,
              ],
              startTime: startSleep,
              endTime: now,
            )
          : <HealthDataPoint>[];

      Duration sleepDuration = Duration.zero;
      for (final d in sleepData) {
        sleepDuration += d.dateTo.difference(d.dateFrom);
      }
      final sleepHours = sleepDuration.inMinutes / 60.0;

      _latestHealth = {
        'steps': steps ?? 0,
        'sleepHours': sleepHours.isFinite ? sleepHours : 0,
      };
      if (mounted) setState(() {});

      await Api.health.sync({
        'steps': steps ?? 0,
        'sleepHours': sleepHours.isFinite ? sleepHours : 0,
      });
    } catch (e) {
      // ignore device health fetch errors
    }
  }

  Future<void> _loadHealthAuthFlag() async {
    final prefs = await SharedPreferences.getInstance();
    _healthAuthDenied = prefs.getBool('health_auth_denied') ?? false;
  }

  Future<bool> _ensureHealthPermission(
    Health health,
    List<HealthDataType> types,
    List<HealthDataAccess> permissions, {
    required bool allowPrompt,
  }) async {
    final has = await health.hasPermissions(types, permissions: permissions);
    if (has == true) return true;

    if (!allowPrompt || _healthAuthDenied || _healthManualAuthInFlight) {
      return false;
    }

    _healthManualAuthInFlight = true;
    try {
      final ok = await health.requestAuthorization(types, permissions: permissions);
      if (!ok) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('health_auth_denied', true);
        _healthAuthDenied = true;
      }
      return ok;
    } finally {
      _healthManualAuthInFlight = false;
    }
  }

  Future<void> _syncWeather() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      final data = await Api.weather.sync({
        'lat': position.latitude,
        'lon': position.longitude,
      });
      _weatherConfigError = null;
      _localWeather = {
        'city': data?['location']?['city'],
        'temperature': data?['temperature'],
        'humidity': data?['humidity'],
        'condition': data?['condition'],
      };
      if (mounted) setState(() {});
    } catch (e) {
      _weatherConfigError = '天气同步失败';
    }
  }

  String _formatSleepHours(dynamic hours) {
    if (hours == null) return '暂无数据';
    final h = double.tryParse(hours.toString());
    if (h == null) return '暂无数据';
    return '${h.toStringAsFixed(1)}小时';
  }

  String _formatSteps(dynamic steps) {
    if (steps == null) return '暂无数据';
    final v = int.tryParse(steps.toString());
    if (v == null) return '暂无数据';
    return '${v}步';
  }

  String _formatHeartRate(dynamic hr) {
    if (hr == null) return '暂无数据';
    final v = int.tryParse(hr.toString());
    if (v == null) return '暂无数据';
    return '平均心率: ${v}次/分';
  }

  String _formatBloodPressure(dynamic bp) {
    if (bp is Map) {
      final sys = bp['systolic'];
      final dia = bp['diastolic'];
      if (sys != null || dia != null) {
        return '收缩压: ${sys ?? '--'}mmHg\n舒张压: ${dia ?? '--'}mmHg';
      }
    }
    return '暂无数据';
  }

  String _formatWeather() {
    if (_weatherConfigError != null) return _weatherConfigError!;
    final temp = _localWeather?['temperature'];
    final humidity = _localWeather?['humidity'];
    final condition = _localWeather?['condition'];
    if (temp == null && humidity == null && condition == null) return '暂无数据';
    final t = temp != null ? '${temp}°C' : '--';
    final h = humidity != null ? '湿度${humidity}%' : '湿度--';
    final c = condition ?? '未知';
    final city = _localWeather?['city'];
    return city != null ? '$city $c $t · $h' : '$c $t · $h';
  }

  String _weatherCodeToText(dynamic code) {
    final v = int.tryParse(code?.toString() ?? '');
    if (v == null) return '未知';
    if (v == 0) return '晴';
    if (v == 1 || v == 2) return '少云';
    if (v == 3) return '多云';
    if (v == 45 || v == 48) return '雾';
    if (v == 51 || v == 53 || v == 55) return '毛毛雨';
    if (v == 56 || v == 57) return '冻雨';
    if (v == 61 || v == 63 || v == 65) return '雨';
    if (v == 66 || v == 67) return '冻雨';
    if (v == 71 || v == 73 || v == 75) return '雪';
    if (v == 77) return '雪粒';
    if (v == 80 || v == 81 || v == 82) return '阵雨';
    if (v == 85 || v == 86) return '阵雪';
    if (v == 95) return '雷暴';
    if (v == 96 || v == 99) return '雷暴冰雹';
    return '未知';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final userName = (user != null && (user['nickname'] != null || user['username'] != null))
        ? (user['nickname'] ?? user['username'])
        : '请登录';
    final avatarUrl = user?['avatar'];

    String greeting = '';
    int hour = DateTime.now().hour;
    if (hour < 11) {
      greeting = '早上好';
    } else if (hour < 14) {
      greeting = '中午好';
    } else if (hour < 18) {
      greeting = '下午好';
    } else {
      greeting = '晚上好';
    }

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
                  CircleAvatar(
                    radius: 22.w,
                    backgroundColor: const Color(0xFFE1BEE7),
                    backgroundImage: avatarUrl != null && avatarUrl.toString().isNotEmpty 
                        ? NetworkImage(AppConfig.currentOrDefault.resolveHttpUrl(avatarUrl.toString())) 
                        : null,
                    child: avatarUrl == null || avatarUrl.toString().isEmpty
                        ? Icon(Icons.person, size: 24.w, color: Colors.white)
                        : null,
                  ),
                  SizedBox(width: 12.w,height: 20.h,),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(fontSize: 16.sp, color: const Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                      ),
                      Text(
                        greeting,
                        style: TextStyle(fontSize: 20.sp, color: const Color(0xFF1B5E20), fontWeight: FontWeight.bold),
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
                height: 150.h,
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: _banners.length,
                      onPageChanged: (index) => setState(() => _currentSwiper = index),
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w), // To match "width: 70%" sort of
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
                      left: 1.w,
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
                      left: 300.w,
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
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8.h,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_banners.length, (index) {
                          final isActive = index == _currentSwiper;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.symmetric(horizontal: 3.w),
                            width: isActive ? 10.w : 6.w,
                            height: isActive ? 10.w : 6.w,
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFF2E7D32) : Colors.white70,
                              shape: BoxShape.circle,
                            ),
                          );
                        }),
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
                  Row(
                    children: [
                      Text('健康数据', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32))),
                      const Spacer(),
                      if (_healthLoading)
                        SizedBox(width: 16.w, height: 16.w, child: const CircularProgressIndicator(strokeWidth: 2)),
                      TextButton.icon(
                        onPressed: _healthUserId == null ? null : () => _syncAll(allowHealthPrompt: true),
                        icon: const Icon(Icons.sync, size: 16),
                        label: const Text('同步'),
                      ),
                      IconButton(
                        onPressed: _healthUserId == null ? null : () => _syncAll(allowHealthPrompt: true),
                        icon: const Icon(Icons.refresh, size: 18),
                        tooltip: '刷新',
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  _buildHealthItem(Icons.wb_sunny, '今日天气', _formatWeather(), const Color(0xFFFFA726)),
                  SizedBox(height: 6.h),
                  _buildHealthItem(Icons.directions_walk, '今日步数', _formatSteps(_latestHealth?['steps']), const Color(0xFF43A047)),
                  SizedBox(height: 6.h),
                  _buildHealthItem(Icons.bedtime, '睡眠时长', _formatSleepHours(_latestHealth?['sleepHours']), const Color(0xFF9C27B0)),
                  SizedBox(height: 6.h),
                  _buildHealthItem(
                    Icons.favorite,
                    '血压',
                    _formatBloodPressure(_latestHealth?['bloodPressure']),
                    const Color(0xFFEF5350),
                    multilineValue: true,
                  ),
                  SizedBox(height: 6.h),
                  _buildHealthItem(Icons.favorite, '心率', _formatHeartRate(_latestHealth?['heartRate']), const Color(0xFFE91E63)),
                ],
              ),
            ),

            // Modules
            CommonCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildModuleItem('assets/images/icon-phonebook.png', '电话本', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PhonebookPage()),
                    );
                  }),
                  _buildModuleItem('assets/images/icon-programs.png', '程序', () {
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

  Widget _buildHealthItem(
    IconData icon,
    String label,
    String value,
    Color iconColor, {
    bool multilineValue = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24.w, color: iconColor),
          SizedBox(width: 12.w),
          Text(label, style: TextStyle(fontSize: 14.sp, color: const Color(0xFF333333), fontWeight: FontWeight.w500)),
          const Spacer(),
          SizedBox(
            width: 130.w,
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: multilineValue ? 2 : 1,
              overflow: multilineValue ? TextOverflow.visible : TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14.sp, color: const Color(0xFF666666)),
            ),
          ),
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
