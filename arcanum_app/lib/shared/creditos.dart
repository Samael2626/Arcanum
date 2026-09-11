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
