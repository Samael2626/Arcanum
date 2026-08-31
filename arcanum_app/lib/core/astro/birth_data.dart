import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

/// Firma de los datos de nacimiento de la sesion actual, o null si faltan.
///
/// POR QUE EXISTE
/// --------------
/// El perfil del onboarding se encola en disco cuando su PUT falla, y se
/// reenvia en el siguiente arranque autenticado (`tryFlushPendingProfile`). Ese
/// reenvio es asincrono y CORRE CONTRA la carga inicial de las pantallas: Hoy y
/// Cielos piden sus datos antes de que el perfil llegue.
///
/// Hoy ya se recuperaba sola porque escucha `userPlaceProvider`. Cielos no
/// escuchaba nada: fijaba su future una vez y solo lo rehacia con
/// pull-to-refresh, asi que se quedaba en "Aun no hay carta que trazar" con los
/// datos ya en el servidor. El boton de ese estado vacio lleva al onboarding,
/// de modo que la pantalla mandaba a rehacer algo que ya estaba hecho.
///
/// Es una FIRMA y no un booleano a proposito: si la persona corrige su hora o su
/// lugar de nacimiento, la carta natal cambia entera. Un booleano solo veria
/// aparecer los datos, nunca cambiarlos, y dejaria en pantalla una rueda
/// calculada con la hora vieja.
///
/// NO sirve para la hora planetaria ni el regente: esos se miden desde donde la
/// persona vive HOY y los resuelve `userPlaceProvider`, que tiene su propia
/// regla. Aqui solo se mira el nacimiento, que no cambia al mudarse.
String? birthSignatureOf(Map<String, dynamic>? user) {
  if (user == null) return null;
  // Los cuatro que la carta natal necesita. Sin uno solo, el servidor responde
  // 422 y no hay rueda que dibujar: la firma es null y no "incompleta".
  const claves = ['birth_date', 'birth_time', 'birth_lat', 'birth_lon'];
  final partes = <String>[];
  for (final clave in claves) {
    final valor = user[clave];
    if (valor == null) return null;
    final texto = valor.toString().trim();
    if (texto.isEmpty) return null;
    partes.add(texto);
  }
  // El sistema de casas no es dato de nacimiento, pero cambiarlo redibuja la
  // rueda igual: entra en la firma para que la pantalla se entere.
  partes.add((user['preferred_house_system'] ?? '').toString());
  return partes.join('|');
}

/// Firma de nacimiento de la sesion, o null mientras falte algun dato.
final birthSignatureProvider = Provider<String?>(
  (ref) => birthSignatureOf(ref.watch(authProvider).user),
);
