/// El saldo y el cupo del dia, en UN sitio y observable.
///
/// Hasta la 1.0.6 no existia: `api.creditsBalance()` se llamaba en un unico
/// punto, se pintaba en un SnackBar y se tiraba. Nada en la app sabia cuantos
/// creditos tenia la persona, asi que no habia como ensenarlo en el cajon ni en
/// el Oraculo, ni como refrescarlo despues de comprar.
///
/// EL RACIONADO SIGUE SIENDO DEL SERVIDOR. Esto no cuenta nada ni decide nada:
/// es una copia de lectura de lo que dijo `/credits/usage/today`, para poder
/// pintarlo. Quien niega una lectura sigue siendo el backend con un 402, igual
/// que antes; un contador local volveria a bloquear a quien acaba de comprar.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/arcanum_api.dart';

/// Lo que queda hoy de una accion, tal como lo cuenta el servidor.
@immutable
class CupoAccion {
  const CupoAccion({
    required this.limiteDiario,
    required this.usado,
    required this.restante,
    required this.siguienteGastaCredito,
  });

  final int limiteDiario;
  final int usado;
  final int restante;

  /// Si la proxima llamada descuenta un credito en vez de salir del cupo.
  ///
  /// Es LA respuesta a "¿esta tirada me cuesta?". No se deduce en el cliente
  /// comparando `restante` con cero: lo dice el servidor, que es quien cobra.
  final bool siguienteGastaCredito;

  factory CupoAccion.deJson(Map<String, dynamic> json) => CupoAccion(
    limiteDiario: (json['limite_diario'] as num?)?.toInt() ?? 0,
    usado: (json['usado'] as num?)?.toInt() ?? 0,
    restante: (json['restante'] as num?)?.toInt() ?? 0,
    siguienteGastaCredito: json['siguiente_gasta_credito'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      other is CupoAccion &&
      other.limiteDiario == limiteDiario &&
      other.usado == usado &&
      other.restante == restante &&
      other.siguienteGastaCredito == siguienteGastaCredito;

  @override
  int get hashCode =>
      Object.hash(limiteDiario, usado, restante, siguienteGastaCredito);
}

/// El saldo y el cupo de todas las acciones.
@immutable
class EstadoSaldo {
  const EstadoSaldo({required this.creditos, required this.acciones});

  final int creditos;
  final Map<String, CupoAccion> acciones;

  CupoAccion? cupoDe(String accion) => acciones[accion];

  factory EstadoSaldo.deJson(Map<String, dynamic> json) {
    final crudas = (json['acciones'] as Map?)?.cast<String, dynamic>() ?? {};
    return EstadoSaldo(
      creditos: (json['balance'] as num?)?.toInt() ?? 0,
      acciones: {
        for (final e in crudas.entries)
          e.key: CupoAccion.deJson((e.value as Map).cast<String, dynamic>()),
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EstadoSaldo &&
      other.creditos == creditos &&
      mapEquals(other.acciones, acciones);

  @override
  int get hashCode => Object.hash(creditos, Object.hashAll(acciones.entries));
}

/// Pide el estado al servidor y lo deja observable.
///
/// `AsyncNotifier` y no `FutureProvider` por [tras Comprar]: hace falta poder
/// reintentar desde fuera manteniendo el valor anterior en pantalla.
class SaldoNotifier extends AsyncNotifier<EstadoSaldo> {
  /// Esperas entre reintentos tras una compra. Suman ~30 s.
  ///
  /// EL WEBHOOK TARDA. Los creditos los concede el backend cuando RevenueCat le
  /// avisa, no cuando la tienda de Google dice que la compra fue bien, asi que
  /// preguntar una sola vez al volver lee el saldo VIEJO y parece que la compra
  /// no entro. Quien acaba de pagar y ve el mismo numero da por hecho que
  /// perdio el dinero.
  ///
  /// LOS 30 s NO ESTAN MEDIDOS. Se busco el retardo real en la base de
  /// produccion el 25-sep-2026 y **no hay ni un evento**: `revenuecat_events`
  /// esta vacia, nadie ha comprado todavia. Asi que este reparto es un techo
  /// prudente, no un dato.
  ///
  /// Cuando haya compras de verdad, la consulta que lo mide es
  /// `received_at - occurred_at_ms` sobre `revenuecat_events`, y entonces esto
  /// se ajusta al p90 observado en vez de a una suposicion.
  ///
  /// Creciente: los primeros reintentos son baratos y cubren el caso rapido;
  /// los ultimos espacian para no castigar la bateria ni el servidor si el
  /// webhook se esta demorando de verdad.
  static const esperas = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 15),
  ];

  @override
  Future<EstadoSaldo> build() => _leer();

  /// Pide el estado, y si el endpoint del cupo falla se conforma con el saldo.
  ///
  /// DEGRADA, NO SE APAGA. `/credits/usage/today` es nuevo: un backend mas viejo
  /// que esta app responde 404, y entonces quedarse en "Saldo no disponible"
  /// esconderia un saldo que `/credits/balance` sabe perfectamente. Se pierde
  /// solo lo que de verdad no se puede saber -- cuanto cupo queda --, y el
  /// bloque lo nota porque `acciones` viene vacio: entonces explica la regla en
  /// general en vez de afirmar lo que cuesta esta lectura.
  ///
  /// Si tambien falla el saldo, ahi si se propaga el error: no hay nada que
  /// ensenar y inventarlo seria peor.
  Future<EstadoSaldo> _leer() async {
    final api = ref.read(arcanumApiProvider);
    try {
      return EstadoSaldo.deJson(await api.usageToday());
    } catch (_) {
      final soloSaldo = await api.creditsBalance();
      return EstadoSaldo(
        creditos: (soloSaldo['balance'] as num?)?.toInt() ?? 0,
        acciones: const {},
      );
    }
  }

  /// Vuelve a preguntar, dejando a la vista lo que ya habia.
  Future<void> refrescar() async {
    state = await AsyncValue.guard(_leer);
  }

  /// Reintenta hasta que el saldo SUBA respecto al que habia antes de pagar.
  ///
  /// Devuelve true si subio. False significa "todavia no", no "fallo": la
  /// compra puede seguir en camino, y quien llama debe decirlo asi en vez de
  /// dar la compra por perdida.
  Future<bool> trasComprar() async {
    final previo = state.value?.creditos;
    for (final espera in esperas) {
      await Future<void>.delayed(espera);
      final leido = await AsyncValue.guard(_leer);
      state = leido;
      final ahora = leido.value?.creditos;
      if (previo == null || ahora == null) continue;
      if (ahora > previo) return true;
    }
    return false;
  }
}

final saldoProvider = AsyncNotifierProvider<SaldoNotifier, EstadoSaldo>(
  SaldoNotifier.new,
);
