import 'dart:convert';

import 'package:flutter/services.dart';

class AppConfig {
  final String apiBaseUrl;
  final String httpBaseUrl;
  final String wsUrl;
  final String? asrBaseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  const AppConfig({
    required this.apiBaseUrl,
    required this.httpBaseUrl,
    required this.wsUrl,
    required this.connectTimeout,
    required this.receiveTimeout,
    this.asrBaseUrl,
  });

  static const AppConfig _defaults = AppConfig(
    apiBaseUrl: 'http://localhost:3000/api/v1',
    httpBaseUrl: 'http://localhost:3000',
    wsUrl: 'ws://localhost:3000/ws',
    asrBaseUrl: null,
    connectTimeout: Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 10),
  );

  static AppConfig? _cached;
  static Future<AppConfig>? _loading;

  static AppConfig get currentOrDefault => _cached ?? _defaults;

  static Future<AppConfig> load({String assetPath = 'assets/config/api_config.json'}) {
    final existing = _cached;
    if (existing != null) return Future.value(existing);

    final inflight = _loading;
    if (inflight != null) return inflight;

    final future = _loadFromAsset(assetPath);
    _loading = future;
    return future;
  }

  static Future<AppConfig> _loadFromAsset(String assetPath) async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        final config = AppConfig.fromJson(decoded);
        _cached = config;
        return config;
      }
    } catch (_) {
      // Fall back to defaults
    }

    _cached = _defaults;
    return _defaults;
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final apiBaseUrl = (json['api_base_url'] ?? json['apiBaseUrl'])?.toString();
    final httpBaseUrl = (json['http_base_url'] ?? json['httpBaseUrl'])?.toString();
    final wsUrl = (json['ws_url'] ?? json['wsUrl'])?.toString();
    final asrBaseUrl = (json['asr_base_url'] ?? json['asrBaseUrl'])?.toString();

    final normalizedApiBaseUrl = apiBaseUrl?.trim();
    final derivedHttpBaseUrl = _deriveHttpBaseUrl(normalizedApiBaseUrl);
    final normalizedHttpBaseUrl = (httpBaseUrl?.trim().isNotEmpty == true)
      ? httpBaseUrl!.trim()
      : (derivedHttpBaseUrl ?? _defaults.httpBaseUrl);

    final normalizedWsUrl = (wsUrl?.trim().isNotEmpty == true)
      ? wsUrl!.trim()
      : _deriveWsUrl(normalizedHttpBaseUrl);

    final dio = (json['dio'] is Map) ? Map<String, dynamic>.from(json['dio'] as Map) : const <String, dynamic>{};
    final connectTimeoutSeconds = _tryParseInt(dio['connect_timeout_seconds'] ?? dio['connectTimeoutSeconds']);
    final receiveTimeoutSeconds = _tryParseInt(dio['receive_timeout_seconds'] ?? dio['receiveTimeoutSeconds']);

    return AppConfig(
      apiBaseUrl: normalizedApiBaseUrl?.isNotEmpty == true ? normalizedApiBaseUrl! : _defaults.apiBaseUrl,
      httpBaseUrl: normalizedHttpBaseUrl,
      wsUrl: normalizedWsUrl,
      asrBaseUrl: asrBaseUrl?.trim().isNotEmpty == true ? asrBaseUrl!.trim() : _defaults.asrBaseUrl,
      connectTimeout: Duration(seconds: connectTimeoutSeconds ?? _defaults.connectTimeout.inSeconds),
      receiveTimeout: Duration(seconds: receiveTimeoutSeconds ?? _defaults.receiveTimeout.inSeconds),
    );
  }

  static String? _deriveHttpBaseUrl(String? apiBaseUrl) {
    if (apiBaseUrl == null || apiBaseUrl.isEmpty) return null;
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || uri.host.isEmpty) return null;
    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    ).toString();
  }

  static String _deriveWsUrl(String httpBaseUrl) {
    if (httpBaseUrl.startsWith('https://')) {
      return 'wss://${httpBaseUrl.substring('https://'.length)}/ws';
    }
    if (httpBaseUrl.startsWith('http://')) {
      return 'ws://${httpBaseUrl.substring('http://'.length)}/ws';
    }
    // Fallback: if scheme is missing, assume ws
    return 'ws://$httpBaseUrl/ws';
  }

  String resolveHttpUrl(String? path) {
    if (path == null) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final baseUrl = httpBaseUrl;
    if (path.startsWith('/')) return '$baseUrl$path';
    return '$baseUrl/$path';
  }

  static int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
