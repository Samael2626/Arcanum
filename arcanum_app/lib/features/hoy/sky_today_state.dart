import 'package:dio/dio.dart';
import '../../core/privacy/ai_consent_service.dart';

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

  /// La persona no autorizo mandar sus datos al proveedor de IA. No es un
  /// fallo: es una decision suya, y se respeta sin insistir.
  sinConsentimiento,

  /// Se acabo el cupo y no hay creditos. Tampoco es un fallo: es el limite del
  /// plan, y confundirlo con la red manda a esta persona a mirar su wifi
  /// mientras el servidor le esta diciendo exactamente que le pasa.
  ///
  /// Lo dice el 402 con `credits_required`, el mismo que ya distingue el
  /// Oraculo (`arcanum_api.dart:31`). Aqui no se podia dar mientras la clave de
  /// idempotencia cortase la segunda generacion del dia; en cuanto el
  /// horoscopo tenga cualquier limite por plan, si.
  sinCupo,
}

/// Clasifica el fallo mirando el codigo, no el texto del mensaje.
SkyTodayFailure classifySkyFailure(Object error) {
  if (error is ConsentDeclined) return SkyTodayFailure.sinConsentimiento;
  if (error is DioException) {
    final status = error.response?.statusCode;
    final rawDetail = error.response?.data is Map
        ? (error.response!.data as Map)['detail']
        : null;
    final detail = rawDetail is String ? rawDetail.toLowerCase() : '';

    switch (status) {
      case 401:
        return SkyTodayFailure.sesionExpirada;
      case 402:
        return SkyTodayFailure.sinCupo;
      case 404:
        // Un 404 de DOMINIO dice que falta la carta natal. Un 404 de RUTA dice
        // que el servidor no conoce ese endpoint — porque va por detras del
        // cliente, por ejemplo. Son cosas distintas y confundirlas manda a la
        // persona a calcular una carta que ya tiene.
        //
        // Paso de verdad: la app pedia `/astral/sky-today` contra una
        // produccion anterior a ese endpoint, y la pantalla decia "calcula tu
        // carta natal" a alguien que la tenia desde hacia meses.
        //
        // FastAPI responde "Not Found" a secas cuando no conoce la ruta; el
        // 404 de dominio trae el mensaje que escribimos nosotros.
        return detail.contains('carta natal')
            ? SkyTodayFailure.sinCartaNatal
            : SkyTodayFailure.cieloNoLegible;
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
    case SkyTodayFailure.sinConsentimiento:
      return 'No autorizaste enviar tus datos para la lectura interpretada. '
          'Esto es lo que dice tu cielo sin ella.';
    case SkyTodayFailure.sinCupo:
      return 'Ya usaste tu lectura interpretada. El cielo de abajo sigue '
          'siendo el tuyo de hoy.';
  }
}

/// Si los transitos siguen siendo validos, la lectura local (determinista y
/// sin red) es una respuesta real y no un relleno: se muestra.
///
/// Cuando falta la carta, faltan los datos o caduco la sesion no hay transitos
/// que leer, y ofrecer una lectura seria inventarla.
/// Sin consentimiento tambien: los transitos se calculan en el dispositivo y no
/// salen de el, asi que la lectura local es exactamente lo que esa persona
/// autorizo. Negarsela ademas seria castigar la decision.
bool allowsLocalReading(SkyTodayFailure failure) =>
    failure == SkyTodayFailure.cieloNoLegible ||
    failure == SkyTodayFailure.sinRed ||
    failure == SkyTodayFailure.sinConsentimiento ||
    // Sin cupo tambien: los transitos son calculo y no cuestan nada. Quitarle
    // ademas el cielo a quien agoto su cuota seria cobrarle dos veces por lo
    // mismo, y lo que se limita es la interpretacion, no el instrumento.
    failure == SkyTodayFailure.sinCupo;

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
    case SkyTodayFailure.sinCupo:
      // A la tienda, que es lo unico que cambia esta situacion. "Reintentar"
      // seria mandarla a chocar contra la misma pared.
      return '/paywall';
    case SkyTodayFailure.cieloNoLegible:
    case SkyTodayFailure.sinRed:
    case SkyTodayFailure.sinConsentimiento:
      return null;
  }
}
