import 'package:dio/dio.dart';

/// Por que no hay horoscopo, y que se puede hacer al respecto.
///
/// Son cuatro situaciones distintas con cuatro salidas distintas, y por eso son
/// cuatro casos y no un `catch` que le eche la culpa a la conexion. Un fallo
/// real disfrazado de otra cosa manda a la persona a arreglar lo que no esta
/// roto, y cuando no funciona, abandona sin reportar nada.
enum SkyTodayFailure {
  /// Aun no hay carta natal calculada. Tiene arreglo, y lo hace ella.
  sinCartaNatal,

  /// Faltan datos de nacimiento: sin ellos no hay carta que calcular.
  sinDatosDeNacimiento,

  /// La sesion caduco. Ni la red ni el cielo tienen nada que ver.
  sesionExpirada,

  /// El servidor esta, pero no pudo leer el cielo (el modelo no respondio).
  /// La carta y los transitos siguen siendo validos: la lectura local sirve.
  cieloNoLegible,

  /// No se llego al servidor. Tambien aqui la lectura local sirve.
  sinRed,
}

/// Clasifica el fallo mirando el codigo, no el texto del mensaje.
SkyTodayFailure classifySkyFailure(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    final rawDetail = error.response?.data is Map
        ? (error.response!.data as Map)['detail']
        : null;
    final detail = rawDetail is String ? rawDetail.toLowerCase() : '';

    switch (status) {
      case 401:
        return SkyTodayFailure.sesionExpirada;
      case 404:
        return SkyTodayFailure.sinCartaNatal;
      case 422:
        // El 422 de dominio dice que faltan datos de nacimiento; el de
        // validacion de FastAPI trae una lista y no dice eso. Solo el primero
        // manda a la persona al perfil.
        return detail.contains('datos de nacimiento') ||
                detail.contains('coordenadas')
            ? SkyTodayFailure.sinDatosDeNacimiento
            : SkyTodayFailure.cieloNoLegible;
      case 503:
        return SkyTodayFailure.cieloNoLegible;
    }
    if (status != null && status >= 500) return SkyTodayFailure.cieloNoLegible;
  }
  return SkyTodayFailure.sinRed;
}

/// Que se le dice a la persona. Nunca se interpola el error: filtraria URL,
/// estado y trazas.
String skyFailureMessage(SkyTodayFailure failure) {
  switch (failure) {
    case SkyTodayFailure.sinCartaNatal:
      return 'Calcula tu carta natal para leer tu cielo de hoy.';
    case SkyTodayFailure.sinDatosDeNacimiento:
      return 'Faltan tus datos de nacimiento. Complétalos en tu perfil.';
    case SkyTodayFailure.sesionExpirada:
      return 'Tu sesión expiró. Vuelve a entrar.';
    case SkyTodayFailure.cieloNoLegible:
      return 'La lectura del cielo no está disponible ahora mismo.';
    case SkyTodayFailure.sinRed:
      return 'Sin conexión: esto es lo que dice tu cielo sin ella.';
  }
}

/// Si los transitos siguen siendo validos, la lectura local (determinista y
/// sin red) es una respuesta real y no un relleno: se muestra.
///
/// Cuando falta la carta, faltan los datos o caduco la sesion no hay transitos
/// que leer, y ofrecer una lectura seria inventarla.
bool allowsLocalReading(SkyTodayFailure failure) =>
    failure == SkyTodayFailure.cieloNoLegible ||
    failure == SkyTodayFailure.sinRed;

/// A donde lleva el boton de arreglar esto, o null si no hay nada que la
/// persona pueda hacer salvo reintentar.
String? skyFailureRoute(SkyTodayFailure failure) {
  switch (failure) {
    case SkyTodayFailure.sinCartaNatal:
      return '/cielos';
    case SkyTodayFailure.sinDatosDeNacimiento:
      return '/perfil';
    case SkyTodayFailure.sesionExpirada:
      return '/login';
    case SkyTodayFailure.cieloNoLegible:
    case SkyTodayFailure.sinRed:
      return null;
  }
}
