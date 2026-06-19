import 'package:dio/dio.dart';

import '../auth/token_storage.dart';

const String kBaseUrl = 'http://localhost:8000';

/// Dio con interceptor que: adjunta el Bearer, y ante 401 refresca el token
/// (rotación en `/auth/refresh`) y reintenta una vez. Si el refresh falla,
/// limpia la sesión y propaga el error.
Dio buildDio(TokenStorage storage) {
  final dio = Dio(BaseOptions(
    baseUrl: kBaseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 12),
  ));
  dio.interceptors.add(_AuthInterceptor(storage));
  return dio;
}

class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor(this._storage);
  final TokenStorage _storage;
  // Dio "desnudo" para el refresh: no pasa por este interceptor (evita recursión).
  final Dio _bare = Dio(BaseOptions(baseUrl: kBaseUrl));

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra['noAuth'] != true) {
      final token = await _storage.access;
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final is401 = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['retried'] == true;
    if (!is401 || alreadyRetried) return handler.next(err);

    final refresh = await _storage.refresh;
    if (refresh == null) return handler.next(err);

    try {
      final res = await _bare.post('/auth/refresh', data: {'refresh_token': refresh});
      await _storage.save(
        access: res.data['access_token'] as String,
        refresh: res.data['refresh_token'] as String,
      );
      final req = err.requestOptions
        ..extra['retried'] = true
        ..headers['Authorization'] = 'Bearer ${res.data['access_token']}';
      final retry = await _bare.fetch(req);
      return handler.resolve(retry);
    } on DioException {
      await _storage.clear();
      return handler.next(err);
    }
  }
}
