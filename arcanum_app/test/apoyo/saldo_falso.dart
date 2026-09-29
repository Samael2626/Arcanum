/// Un saldo de mentira para los tests que montan pantallas con el bloque.
///
/// Desde la 1.0.6 el cajon, el Oraculo y el paywall piden `/credits/usage/today`
/// al montarse. Los tests que ya existian montan esas pantallas sin servidor, y
/// sin esto se quedan con un Timer de Dio pendiente y fallan por algo que no
/// tiene que ver con lo que prueban.
///
/// SE PISA `saldoProvider`, NO LA API. Varios de esos tests ya traen su propia
/// ArcanumApi falsa, y esas clases no implementan `usageToday()`: heredan la de
/// verdad y acaban pidiendo por red igual. Pisar el provider entero corta eso de
/// raiz y no obliga a tocar cada doble.
///
/// El override se pone, la llamada no se quita: que la pantalla pida el saldo es
/// el comportamiento correcto, y un test que lo desactivara dejaria de probar la
/// pantalla de verdad.
library;

import 'package:arcanum_app/core/monetization/saldo.dart';

class SaldoFalso extends SaldoNotifier {
  SaldoFalso({
    this.creditos = 0,
    this.gastaCredito = false,
    this.costes = const {'three_card': 1, 'celtic_cross': 3},
  });

  final int creditos;
  final bool gastaCredito;

  /// Los precios que mandaria el servidor. Por defecto los de verdad; un mapa
  /// vacio simula un backend viejo, que es cuando la UI no debe prometer
  /// ningun precio.
  final Map<String, int> costes;

  @override
  Future<EstadoSaldo> build() async => EstadoSaldo(
    creditos: creditos,
    acciones: {
      for (final accion in ['tarot', 'oracle', 'cielos', 'horoscope'])
        accion: CupoAccion(
          limiteDiario: 1,
          usado: gastaCredito ? 1 : 0,
          restante: gastaCredito ? 0 : 1,
          siguienteGastaCredito: gastaCredito,
        ),
    },
    costePorTirada: costes,
  );

  @override
  Future<void> refrescar() async {}

  @override
  Future<bool> trasComprar() async => true;
}

/// Se usa asi, porque riverpod 3 no exporta el tipo `Override` y una funcion
/// de ayuda tendria que anotarlo:
///
///     ProviderScope(
///       overrides: [saldoProvider.overrideWith(() => SaldoFalso(creditos: 3))],
///       ...
///     )
