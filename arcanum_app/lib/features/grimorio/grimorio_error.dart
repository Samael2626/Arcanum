/// Por qué no se pudo sellar una entrada.
///
/// Existe porque el editor tenía un `catch` que le echaba la culpa a la
/// conexión pasara lo que pasara: un 401, un 422, un fallo al cifrar o un
/// error del servidor salían todos como «Revisa tu conexión». El tester que
/// lo reportó tenía conexión perfectamente, y el mensaje mandaba a mirar
/// donde no estaba el problema.
///
/// Lo que se enseña no lleva detalles del servidor -- sus `detail` traen rutas
/// de la API -- pero el error de verdad SÍ va al log, que es donde mira quien
/// puede arreglarlo.
library;

import 'package:dio/dio.dart';

/// Si de verdad es la red, y no otra cosa disfrazada.
bool esFalloDeRed(Object error) =>
    error is DioException &&
    const {
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    }.contains(error.type);

/// Si la sesión se cayó. Se trata aparte: no se arregla reintentando.
bool esSesionCaida(Object error) =>
    error is DioException && error.response?.statusCode == 401;

String mensajeAlSellar(Object error) {
  if (esFalloDeRed(error)) {
    return 'No se pudo sellar la entrada. Revisa tu conexión.';
  }
  if (esSesionCaida(error)) return 'Sesión expirada, inicia de nuevo.';

  if (error is DioException) {
    final codigo = error.response?.statusCode ?? 0;
    if (codigo == 413) {
      return 'La entrada es demasiado larga para sellarla.';
    }
    if (codigo >= 500) {
      return 'El servidor no pudo sellarla. Inténtalo en unos minutos.';
    }
    if (codigo >= 400) {
      // 400, 422 y compañía: no es la red y reintentar no arregla nada.
      return 'No se pudo sellar la entrada: el servidor la rechazó.';
    }
  }
  // Lo que no viene del servidor: cifrado, almacenamiento, un nulo.
  return 'No se pudo sellar la entrada. Vuelve a intentarlo.';
}
