import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../auth/token_storage.dart';

/// La URL del backend de produccion. Es el unico destino en una app publicada
/// y no depende de ninguna variable de compilacion: si el define se olvidara,
/// se corrompiera o llegara vacio, la app sigue hablando con Railway.
const String kProductionBaseUrl =
    'https://arcanum-code-production.up.railway.app';

/// Override para pruebas fisicas contra un backend local:
///
///     flutter build apk --debug --dart-define=API_BASE_URL=http://127.0.0.1:8000
///
/// Cadena vacia cuando no se pasa el define, que es el caso normal.
const String kApiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

/// Decide contra que backend habla la app.
///
/// El override SOLO se respeta en debug. En release se ignora aunque alguien
/// pase el define: una compilacion de tienda que apunte a otro sitio por una
/// bandera de linea de comandos es una forma silenciosa de publicar la app
/// contra un servidor equivocado. Los parametros son inyectables para poder
/// probar las dos ramas sin recompilar.
String resolveBaseUrl({
  String override = kApiBaseUrlOverride,
  bool debug = kDebugMode,
}) {
  if (!debug || override.trim().isEmpty) return kProductionBaseUrl;
  return override.trim();
}

final String kBaseUrl = resolveBaseUrl();

/// Dio con interceptor que: adjunta el Bearer, y ante 401 refresca el token
/// (rotación en `/auth/refresh`) y reintenta una vez. Si el refresh falla,
/// limpia la sesión y propaga el error.
/// [refreshDio] existe como costura de prueba. El interceptor necesita un Dio
/// SIN interceptor para refrescar —si no, el refresco entraria en su propia
/// cola y se bloquearia—, y hasta ahora lo creaba dentro y en privado. Eso hacia
/// el camino del refresco imposible de probar: un adaptador de mentira nunca lo
/// veia y las peticiones se iban a la red real.
Dio buildDio(TokenStorage storage, {Dio? refreshDio}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: kBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );
  dio.interceptors.add(_AuthInterceptor(storage, refreshDio));
  return dio;
}

class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor(this._storage, [Dio? refreshDio])
      : _bare = refreshDio ?? Dio(BaseOptions(baseUrl: kBaseUrl));
  final TokenStorage _storage;
  // Dio "desnudo" para el refresh: no pasa por este interceptor (evita recursión).
  final Dio _bare;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['noAuth'] != true) {
      final token = await _storage.access;
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final is401 = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['retried'] == true;
    if (!is401 || alreadyRetried) return handler.next(err);

    final refresh = await _storage.refresh;
    if (refresh == null) return handler.next(err);

    try {
      final res = await _bare.post(
        '/auth/refresh',
        data: {'refresh_token': refresh},
      );
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
