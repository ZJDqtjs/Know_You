import 'http.dart';

class Api {
  static final HttpService _http = HttpService();

  static final AuthApi auth = AuthApi(_http);
  static final BindingsApi bindings = BindingsApi(_http);
  static final HealthApi health = HealthApi(_http);
  static final WeatherApi weather = WeatherApi(_http);
  static final DevicesApi devices = DevicesApi(_http);
  static final ScreenApi screen = ScreenApi(_http);
  static final SchedulesApi schedules = SchedulesApi(_http);
  static final LogsApi logs = LogsApi(_http);
}

class AuthApi {
  final HttpService _http;
  AuthApi(this._http);

  Future<dynamic> register(Map<String, dynamic> payload) => _http.post('/auth/register', data: payload);
  Future<dynamic> login(Map<String, dynamic> payload) => _http.post('/auth/login', data: payload);
  Future<dynamic> refresh(String refreshToken) => _http.post('/auth/refresh', data: {'refreshToken': refreshToken});
  Future<dynamic> me() => _http.get('/users/me');
  Future<dynamic> updateMe(Map<String, dynamic> payload) => _http.put('/users/me', data: payload);
  Future<dynamic> uploadAvatar(String filePath) => _http.uploadFile('/files/upload', filePath);
}

class BindingsApi {
  final HttpService _http;
  BindingsApi(this._http);

  Future<dynamic> list([String? role]) => _http.get('/bindings', params: role != null ? {'role': role} : null);
  Future<dynamic> createRequest(int targetUserId) => _http.post('/bindings', data: {'targetUserId': targetUserId});
  Future<dynamic> accept(int bindingId) => _http.post('/bindings/$bindingId/accept');
  Future<dynamic> reject(int bindingId) => _http.post('/bindings/$bindingId/reject');
  Future<dynamic> unlink(int bindingId) => _http.delete('/bindings/$bindingId', data: {});
  Future<dynamic> genCode() => _http.post('/bindings/link-code', data: {});
  Future<dynamic> useCode(String code) => _http.post('/bindings/link', data: {'code': code});
}

class HealthApi {
  final HttpService _http;
  HealthApi(this._http);

  Future<dynamic> latest(int userId) => _http.get('/health/$userId/latest');
  Future<dynamic> history(int userId, Map<String, dynamic> params) => _http.get('/health/$userId/history', params: params);
}

class WeatherApi {
  final HttpService _http;
  WeatherApi(this._http);

  Future<dynamic> get(int userId) => _http.get('/weather/$userId');
}

class DevicesApi {
  final HttpService _http;
  DevicesApi(this._http);

  Future<dynamic> list(int userId) => _http.get('/devices', params: {'userId': userId});
  Future<dynamic> detail(int id) => _http.get('/devices/$id');
  Future<dynamic> toggle(int id, bool state) => _http.post('/devices/$id/toggle', data: {'state': state});
  Future<dynamic> command(int id, String command, Map<String, dynamic> payload) => 
      _http.post('/devices/$id/commands', data: {'command': command, 'payload': payload});
}

class ScreenApi {
  final HttpService _http;
  ScreenApi(this._http);

  Future<dynamic> createSession(dynamic targetUserId) => 
      _http.post('/screen-sessions', data: {'targetUserId': targetUserId is String ? int.tryParse(targetUserId) : targetUserId});
  Future<dynamic> accept(String sid) => _http.post('/screen-sessions/$sid/accept');
  Future<dynamic> reject(String sid) => _http.post('/screen-sessions/$sid/reject');
  Future<dynamic> close(String sid) => _http.post('/screen-sessions/$sid/close');
  Future<dynamic> getSessionInfo(String sid) => _http.get('/screen-sessions/$sid');
  Future<dynamic> remoteStart(String sid) => _http.post('/screen-sessions/$sid/remote-start');
  Future<dynamic> remoteStop(String sid) => _http.post('/screen-sessions/$sid/remote-stop');
  Future<dynamic> command(String sid, String command, [Map<String, dynamic> payload = const {}]) => 
      _http.post('/screen-sessions/$sid/commands', data: {'command': command, 'payload': payload});
}

class SchedulesApi {
  final HttpService _http;
  SchedulesApi(this._http);

  Future<dynamic> create(Map<String, dynamic> payload) => _http.post('/schedules', data: payload);
  Future<dynamic> list(int userId) => _http.get('/schedules', params: {'userId': userId});
  Future<dynamic> update(int id, Map<String, dynamic> payload) => _http.put('/schedules/$id', data: payload);
  Future<dynamic> remove(int id) => _http.delete('/schedules/$id');
}

class LogsApi {
  final HttpService _http;
  LogsApi(this._http);

  Future<dynamic> control(int userId, {int page = 1, int pageSize = 20}) => 
      _http.get('/logs/control', params: {'userId': userId, 'page': page, 'pageSize': pageSize});
  Future<dynamic> healthAccess(int userId) => _http.get('/logs/health-access', params: {'userId': userId});
}
