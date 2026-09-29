import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/monetization/saldo.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';

/// Lo que cuesta interpretar una tirada, dicho ANTES de pedirla.
///
/// POR QUE. Desde el 28-sep-2026 el precio sale del numero de cartas: una de
/// tres vale 1 credito y la Cruz Celta 3. El backend ya cobraba bien y la app
/// no decia nada, asi que se elegia la Cruz Celta creyendo que valia 1 y se
/// descubria el precio con tres creditos menos o con un 402 en la cara. Cobrar
/// sin avisar es lo que no se hace.
///
/// EL PRECIO LO MANDA EL SERVIDOR (`coste_por_tirada`), no se calcula aqui.
/// La formula es una regla de negocio y escrita en dos lenguajes se separa a
/// la primera que alguien toque una sola.
///
/// SI NO SE SABE, NO SE PROMETE. Con un backend viejo el mapa viene vacio y
/// estos widgets se apagan solos en vez de inventar una cifra: un precio
/// equivocado en pantalla es peor que ninguno.

/// La etiqueta del precio junto al nombre de una tirada.
///
/// Se pinta siempre, tambien cuando la lectura va a salir del cupo: es lo que
/// CUESTA la tirada, no lo que se va a pagar hoy. Confundir las dos cosas hace
/// que manana, sin cupo, el precio parezca nuevo.
class PrecioTirada extends ConsumerWidget {
  const PrecioTirada(this.tirada, {super.key, this.seleccionada = false});

  final String tirada;
  final bool seleccionada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coste = ref.watch(saldoProvider).value?.costeDe(tirada);
    if (coste == null) return const SizedBox.shrink();
    return Text(
      coste == 1 ? '1 crédito' : '$coste créditos',
      style: ArcanumText.body(
        11,
        color: seleccionada
            ? ArcanumColors.goldLabel
            : ArcanumColors.ivoryMuted,
      ).copyWith(letterSpacing: 0.6),
    );
  }
}

/// La frase de debajo del boton de interpretar: que va a pasar al pulsarlo.
///
/// Distingue los tres casos que la persona necesita distinguir, y ninguno se
/// deduce en el cliente: entra en el cupo, gasta creditos, o no hay saldo
/// suficiente y conviene saberlo ANTES de pulsar.
class AvisoPrecioInterpretacion extends ConsumerWidget {
  const AvisoPrecioInterpretacion(this.tirada, {super.key});

  final String tirada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(saldoProvider).value;
    final coste = estado?.costeDe(tirada);
    if (estado == null || coste == null) return const SizedBox.shrink();

    final gasta = estado.gastaCredito('oracle', tirada);
    final sinSaldo = gasta && estado.creditos < coste;

    final texto = !gasta
        ? 'Esta interpretación entra en tu cupo de hoy.'
        : sinSaldo
        ? 'Cuesta ${_creditos(coste)} y tienes ${_creditos(estado.creditos)}. '
              'Puedes comprar más en la tienda.'
        : 'Esta interpretación gasta ${_creditos(coste)} de tu saldo.';

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: ArcanumText.body(
          13,
          color: sinSaldo ? ArcanumColors.gold : ArcanumColors.ivoryMuted,
        ),
      ),
    );
  }

  static String _creditos(int n) => n == 1 ? '1 crédito' : '$n créditos';
}
