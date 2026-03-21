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
  static final CommunityApi community = CommunityApi(_http);
  static final MallApi mall = MallApi(_http);
  static final RecommendationApi recommendation = RecommendationApi(_http);
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
  Future<dynamic> sync(Map<String, dynamic> payload) => _http.post('/health/sync', data: payload);
}

class WeatherApi {
  final HttpService _http;
  WeatherApi(this._http);

  Future<dynamic> get(int userId) => _http.get('/weather/$userId');
  Future<dynamic> sync(Map<String, dynamic> payload) => _http.post('/weather/sync', data: payload);
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

class CommunityApi {
  final HttpService _http;
  CommunityApi(this._http);

  Future<dynamic> listPosts({int page = 1, int pageSize = 20, String sort = 'time'}) =>
      _http.get('/community/posts', params: {'page': page, 'pageSize': pageSize, 'sort': sort});

    Future<dynamic> listMyPosts({int page = 1, int pageSize = 20, String sort = 'time'}) =>
      _http.get('/community/posts/mine', params: {'page': page, 'pageSize': pageSize, 'sort': sort});

  Future<dynamic> getPost(int postId) => _http.get('/community/posts/$postId');

  Future<dynamic> createPost({String? title, String? content, String? voiceUrl, int? voiceDuration, List<String>? imageUrls}) =>
      _http.post('/community/posts', data: {
        'title': title,
        'content': content,
        'voiceUrl': voiceUrl,
        'voiceDuration': voiceDuration,
        'imageUrls': imageUrls,
      });

  Future<dynamic> deletePost(int postId) => _http.delete('/community/posts/$postId');

  Future<dynamic> toggleLike(int postId) => _http.post('/community/posts/$postId/like', data: {});

  Future<dynamic> listComments(int postId, {int page = 1, int pageSize = 20}) =>
      _http.get('/community/posts/$postId/comments', params: {'page': page, 'pageSize': pageSize});

  Future<dynamic> addComment(int postId, {String? content, String? voiceUrl, int? voiceDuration}) =>
      _http.post('/community/posts/$postId/comments', data: {
        'content': content,
        'voiceUrl': voiceUrl,
        'voiceDuration': voiceDuration,
      });
}

class MallApi {
  final HttpService _http;
  MallApi(this._http);

  Future<dynamic> listCategories() => _http.get('/mall/categories');

  Future<dynamic> listProducts({int page = 1, int pageSize = 20, String? keyword, int? categoryId}) =>
      _http.get('/mall/products', params: {
        'page': page,
        'pageSize': pageSize,
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        if (categoryId != null) 'categoryId': categoryId,
      });

  Future<dynamic> createProduct(Map<String, dynamic> data) => _http.post('/mall/products', data: data);

  Future<dynamic> getProduct(int productId) => _http.get('/mall/products/$productId');

  Future<dynamic> listOrders({int page = 1, int pageSize = 20, String? status}) =>
      _http.get('/mall/orders', params: {
        'page': page,
        'pageSize': pageSize,
        if (status != null && status.isNotEmpty) 'status': status,
      });
}

class RecommendationApi {
  final HttpService _http;
  RecommendationApi(this._http);

  Future<dynamic> listRecommendedPosts({int page = 1, int pageSize = 20}) =>
      _http.get('/recommendations/posts', params: {
        'page': page,
        'pageSize': pageSize,
      });

  Future<dynamic> listRecommendedProducts({int page = 1, int pageSize = 20}) =>
      _http.get('/recommendations/products', params: {
        'page': page,
        'pageSize': pageSize,
      });
}
