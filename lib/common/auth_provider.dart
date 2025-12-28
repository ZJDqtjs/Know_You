import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'http.dart';
import 'notification_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  Map<String, dynamic>? _user;

  bool get isLoggedIn => _isLoggedIn;
  Map<String, dynamic>? get user => _user;

  Future<void> checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_access_token');
    if (token != null && token.isNotEmpty) {
      _isLoggedIn = true;
      notifyListeners();
      _loadUser();
      NotificationService().connect();
    } else {
      _isLoggedIn = false;
      notifyListeners();
    }
  }

  Future<void> _loadUser() async {
    try {
      final res = await Api.auth.me();
      _user = res;
      notifyListeners();
    } catch (e) {
      print('Load user failed: $e');
    }
  }

  Future<void> login(String username, String password) async {
    try {
      final res = await Api.auth.login({'username': username, 'password': password});
      final accessToken = res['accessToken'];
      final refreshToken = res['refreshToken'];
      final user = res['user'];
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_access_token', accessToken);
      await prefs.setString('auth_refresh_token', refreshToken);
      
      _isLoggedIn = true;
      _user = user;
      notifyListeners();
      
      NotificationService().connect();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> register(String username, String password, String nickname) async {
    try {
      await Api.auth.register({'username': username, 'password': password, 'nickname': nickname});
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    await HttpService().clearTokens();
    _isLoggedIn = false;
    _user = null;
    NotificationService().disconnect();
    notifyListeners();
  }

  void updateUser(Map<String, dynamic> updatedUser) {
    _user = updatedUser;
    notifyListeners();
  }
}
