/// Lo que la mesa le dice al usuario cuando el servidor falla.
///
/// Los mensajes propios de la mesa ya vienen en espanol y se muestran tal
/// cual. Los que pone el framework por su cuenta («Not authenticated»,
/// «Not Found», la lista de validacion) no: salian crudos y en ingles.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;

const String _generic = 'No se pudo completar. Inténtalo de nuevo.';

/// Textos por defecto de FastAPI/Starlette: nunca son para el usuario.
const Set<String> _frameworkDefaults = {
  'Not authenticated',
  'Not Found',
  'Method Not Allowed',
  'Forbidden',
  'Unauthorized',
  'Internal Server Error',
};

/// Sesion caida: no se arregla reintentando, hay que volver a entrar. FastAPI
/// responde 403 «Not authenticated» cuando falta el token, no solo 401.
bool isTableSessionLost(Object error) {
  if (error is! DioException) return false;
  final status = error.response?.statusCode;
  return status == 401 ||
      (status == 403 && _detail(error) == 'Not authenticated');
}

String tableErrorMessage(Object error, {bool debug = !kReleaseMode}) {
  if (isTableSessionLost(error)) return 'Tu sesión caducó. Vuelve a entrar.';
  if (error is DioException) {
    if (error.response == null) {
      return 'No hay conexión con el servidor. Inténtalo de nuevo.';
    }
    final status = error.response!.statusCode ?? 0;
    final detail = _detail(error);
    if (status < 500 &&
        detail != null &&
        !_frameworkDefaults.contains(detail)) {
      return detail;
    }
    if (status == 422 && error.response!.data is Map) {
      return 'No se pudo completar. Actualiza la app e inténtalo de nuevo.';
    }
  }
  // fuera de la version de la tienda se dice que fallo: el mensaje generico
  // no deja saber si fue la sesion, el servidor o la app
  if (!debug) return _generic;
  final what = error is DioException
      ? 'HTTP ${error.response?.statusCode ?? '-'} ${error.requestOptions.path}'
      : '${error.runtimeType}: $error';
  return '$_generic\n\n[$what]';
}

String? _detail(DioException error) {
  final data = error.response?.data;
  return data is Map && data['detail'] is String
      ? data['detail'] as String
      : null;
}
