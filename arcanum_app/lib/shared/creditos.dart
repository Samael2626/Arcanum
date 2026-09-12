/// El paso a la tienda cuando el servidor dice que no queda saldo.
///
/// Vivia copiado tres veces -- Oraculo, Cielos y la vieja pantalla de tarot --
/// con el mismo cuerpo y el mismo mensaje. Un cuarto sitio (la tirada por la
/// tradicion) era la ocasion de dejar UNO.
///
/// EL RACIONADO ES DEL SERVIDOR, y solo del servidor: un 402, que `isCreditsRequired`
/// reconoce. `QuotaService` no niega nada desde que se vacio -- contar en el
/// dispositivo bloqueaba a quien habia comprado creditos, porque el contador
/// local decia que no antes de que el servidor pudiera decir que si.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api/arcanum_api.dart';

/// SE APILA, NO SE REEMPLAZA, y esa es la regla de toda la app:
///
///   `push`  un recado del que se VUELVE a lo que estabas haciendo -- la
///           tienda, el perfil, los ajustes, la politica.
///   `go`    el sitio de partida ya no vale -- la sesion se cayo, o el destino
///           es la otra cara de la pestana en la que ya estas.
///
/// La tienda es lo primero: nadie compra creditos como fin en si mismo, sino
/// para seguir con la tirada que se quedo a medias. Con `go` esa tirada
/// desaparece de la pila y volver es imposible salvo por la barra de abajo,
/// que ademas te deja en la raiz de la seccion.
///
/// Ensena el saldo que queda y abre la tienda.
///
/// Devuelve `null` si todo fue bien, o el mensaje a mostrar si ni siquiera se
/// pudo leer el saldo: quien llama decide donde ponerlo, que es lo unico que
/// cambiaba entre las tres copias.
Future<String?> abrirPaywallDeCreditos(
  BuildContext context,
  ArcanumApi api,
) async {
  try {
    final saldo = await api.creditsBalance();
    if (!context.mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saldo actual: ${saldo['balance'] ?? 0} créditos.')),
    );
    context.push('/paywall');
    return null;
  } catch (_) {
    return 'No se pudo actualizar tu saldo. Inténtalo de nuevo.';
  }
}
