/// El saldo, donde se ve sin chocar antes con un limite.
///
/// Hasta la 1.0.6 la tienda solo se abria tras un 402: habia que quedarse sin
/// cupo para poder comprar, y el saldo aparecia un instante en un SnackBar. Dos
/// piezas lo arreglan, y las dos llevan a `/paywall`:
///
///   [BloqueSaldoCajon]   el bloque del cajon, lo primero que se ve al abrirlo
///   [BloqueSaldoOraculo] el de antes de tirar, que ademas dice si cuesta
///
/// DICEN LA VERDAD O NO DICEN NADA. Mientras no se sabe lo que cuesta la
/// siguiente lectura no se escribe ningun numero: un "gasta 1 credito" es falso
/// mientras quede cupo, y ensenar un coste inventado es peor que callarse.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/monetization/saldo.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';

/// `push` y no `go`: la tienda es un recado del que se VUELVE a lo que estabas
/// haciendo. Es la misma regla de `shared/creditos.dart`.
void _abrirTienda(BuildContext context) => context.push('/paywall');

/// El bloque del cajon: saldo y una via a la tienda. Nada mas.
///
/// Se deja deliberadamente sin hueco reservado para lo que venga despues. Cada
/// elemento que se anade a una pantalla le quita sitio a otro, y un espacio
/// vacio guardado "para los fragmentos" seria un elemento que hoy no dice nada.
/// Cuando existan, se amplia.
class BloqueSaldoCajon extends ConsumerWidget {
  const BloqueSaldoCajon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saldo = ref.watch(saldoProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Semantics(
        button: true,
        label: saldo.value == null
            ? 'Créditos y suscripción'
            : 'Tienes ${saldo.value!.creditos} créditos. Abrir la tienda.',
        child: InkWell(
          key: const Key('saldo-cajon'),
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Scaffold.of(context).closeDrawer();
            _abrirTienda(context);
          },
          child: ExcludeSemantics(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: ArcanumColors.gold.withValues(alpha: 0.38),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ArcanumColors.burgundy.withValues(alpha: 0.34),
                    ArcanumColors.surfaceHigh.withValues(alpha: 0.5),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TU SALDO',
                    style: ArcanumText.body(
                      10,
                      color: ArcanumColors.goldLabel,
                    ).copyWith(letterSpacing: 2.2),
                  ),
                  const SizedBox(height: 6),
                  _Cifra(saldo: saldo),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'Conseguir más',
                        style: ArcanumText.body(13, color: ArcanumColors.gold),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: ArcanumColors.gold,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La cifra, o lo que se puede decir mientras no la hay.
class _Cifra extends StatelessWidget {
  const _Cifra({required this.saldo});

  final AsyncValue<EstadoSaldo> saldo;

  @override
  Widget build(BuildContext context) {
    final estado = saldo.value;
    if (estado == null) {
      // Cargando o fallo de red. No se pinta un cero: un cero es una cifra, y
      // una cifra falsa manda a comprar a quien ya tiene creditos.
      return Text(
        saldo.hasError ? 'Saldo no disponible' : 'Consultando tu saldo…',
        style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '${estado.creditos}',
          style: ArcanumText.heading(34, color: ArcanumColors.goldLight),
        ),
        const SizedBox(width: 7),
        Text(
          estado.creditos == 1 ? 'crédito' : 'créditos',
          style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
        ),
      ],
    );
  }
}

/// El de antes de tirar: saldo Y lo que cuesta ESTA lectura.
///
/// El coste sale del servidor (`siguiente_gasta_credito`), nunca de un numero
/// fijo. "Gasta 1 crédito" seria mentira mientras quede cupo diario, que es la
/// mayor parte del tiempo: la primera lectura del dia es gratis.
class BloqueSaldoOraculo extends ConsumerWidget {
  const BloqueSaldoOraculo({super.key, required this.accion});

  /// Que cupo mirar: 'tarot', 'oracle', 'cielos' u 'horoscope'.
  final String accion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saldo = ref.watch(saldoProvider);
    final estado = saldo.value;
    final cupo = estado?.cupoDe(accion);

    return Semantics(
      button: true,
      label: cupo == null
          ? 'Abrir la tienda de créditos'
          : cupo.siguienteGastaCredito
          ? 'Tienes ${estado!.creditos} créditos. Esta lectura gasta uno. '
                'Abrir la tienda.'
          : 'Tienes ${estado!.creditos} créditos. Esta lectura entra en tu '
                'cupo de hoy. Abrir la tienda.',
      child: InkWell(
        key: const Key('saldo-oraculo'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => _abrirTienda(context),
        child: ExcludeSemantics(
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: ArcanumColors.surface,
              border: Border(
                left: BorderSide(color: ArcanumColors.gold, width: 3),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'TU SALDO',
                        style: ArcanumText.body(
                          10,
                          color: ArcanumColors.goldLabel,
                        ).copyWith(letterSpacing: 2.2),
                      ),
                      const SizedBox(height: 2),
                      _Coste(estado: estado, cupo: cupo, cargando: saldo.isLoading),
                    ],
                  ),
                ),
                Text(
                  'Tienda',
                  style: ArcanumText.body(14, color: ArcanumColors.gold),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: ArcanumColors.gold,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La cifra y la frase del coste, que solo se escribe cuando se sabe.
class _Coste extends StatelessWidget {
  const _Coste({
    required this.estado,
    required this.cupo,
    required this.cargando,
  });

  final EstadoSaldo? estado;
  final CupoAccion? cupo;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    if (estado == null) {
      return Text(
        cargando ? 'Consultando tu saldo…' : 'Saldo no disponible',
        style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
      );
    }
    // Sin cupo conocido se ensena el saldo y punto. Callar el coste es correcto;
    // inventarlo, no.
    final coste = cupo == null
        ? ''
        : cupo!.siguienteGastaCredito
        ? ' · esta lectura gasta 1'
        : ' · esta lectura entra en tu cupo de hoy';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '${estado!.creditos}',
          style: ArcanumText.heading(26, color: ArcanumColors.goldLight),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${estado!.creditos == 1 ? 'crédito' : 'créditos'}$coste',
            style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
          ),
        ),
      ],
    );
  }
}
