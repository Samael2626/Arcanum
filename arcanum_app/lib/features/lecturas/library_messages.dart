import 'package:flutter/foundation.dart';

/// Mensajes de error de Lecturas.
///
/// El error tecnico (DioException, URL, status, stack) va a `debugPrint` y
/// nunca a pantalla: al lector no le sirve y expone la forma de la API.
const String libraryUnavailableMessage =
    'La biblioteca no está disponible ahora. Desliza hacia abajo para reintentar.';

const String chapterUnavailableMessage =
    'Este pasaje no está disponible ahora. Desliza hacia abajo para reintentar.';

const String workUnavailableMessage =
    'No se pudo abrir la obra. Desliza hacia abajo para reintentar.';

/// Registra el fallo con detalle en depuracion, sin devolver nada mostrable.
void logLibraryFailure(String where, Object? error) {
  debugPrint('ARCANUM lecturas: $where fallo ($error).');
}
