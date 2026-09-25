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
  /// Esperas entre reintentos tras una compra. Suman ~7 s.
  ///
  /// EL WEBHOOK TARDA. Los creditos los concede el backend cuando RevenueCat le
  /// avisa, no cuando la tienda de Google dice que la compra fue bien, asi que
  /// preguntar una sola vez al volver lee el saldo VIEJO y parece que la compra
  /// no entro. Quien acaba de pagar y ve el mismo numero da por hecho que
  /// perdio el dinero.
  ///
  /// Creciente y corta: si a los siete segundos no ha llegado, esperar mas en
  /// una pantalla bloqueada es peor que decirlo y ofrecer actualizar.
  static const esperas = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  @override
  Future<EstadoSaldo> build() => _leer();

  Future<EstadoSaldo> _leer() async {
    final json = await ref.read(arcanumApiProvider).usageToday();
    return EstadoSaldo.deJson(json);
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
