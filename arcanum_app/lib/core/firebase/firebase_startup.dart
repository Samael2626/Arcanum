import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

/// Devuelve la app [DEFAULT] de Firebase, creandola solo si hace falta.
///
/// En Android, `FirebaseInitProvider` ya crea [DEFAULT] durante el arranque del
/// proceso, leyendo google-services.json. Llamar despues a `initializeApp`
/// lanza `[core/duplicate-app]`, la excepcion escapa de `main` y `runApp` nunca
/// corre: pantalla negra. Por eso se comprueba primero si la app existe.
///
/// Solo se tratan dos codigos de error, y ambos con una salida concreta:
///   - `no-app`        -> no existe todavia: se inicializa con las opciones.
///   - `duplicate-app` -> otra ruta la creo en paralelo: se recupera la suya.
/// Cualquier otro fallo (opciones invalidas, plugin ausente) se relanza: son
/// errores de configuracion y deben verse, no quedar en silencio.
Future<FirebaseApp> ensureFirebaseInitialized({
  FirebaseOptions? options,
  FirebaseApp Function()? lookup,
  Future<FirebaseApp> Function({FirebaseOptions? options})? initialize,
}) async {
  final resolvedLookup = lookup ?? Firebase.app;
  final resolvedInitialize = initialize ?? Firebase.initializeApp;

  try {
    // Si el provider nativo ya la creo, esta es la unica app valida.
    return resolvedLookup();
  } on FirebaseException catch (error) {
    if (error.code != 'no-app') {
      rethrow;
    }
  }

  try {
    return await resolvedInitialize(
      options: options ?? DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (error) {
    if (error.code != 'duplicate-app') {
      rethrow;
    }
    // Carrera: alguien la creo entre la consulta y la inicializacion.
    return resolvedLookup();
  }
}
