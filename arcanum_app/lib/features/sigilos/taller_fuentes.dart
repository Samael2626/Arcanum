// «Fuentes»: de donde sale cada decision del sigilo, con la procedencia en
// lenguaje llano (fuente historica, ocultismo moderno, reconstruccion,
// decision de ARCANUM). Titulos y citas traducidos; el original queda en la
// nota que aparece al mantener pulsado.
import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import 'taller_panels.dart';

enum Procedencia {
  hp(
    'Fuente histórica',
    'Documentado en manuscritos, monedas o ediciones antiguas.',
    Color(0xFFC9A84C),
  ),
  om(
    'Ocultismo moderno',
    'Autor moderno identificable (siglos XIX y XX).',
    Color(0xFFA9B2E0),
  ),
  rc(
    'Reconstrucción',
    'Reconstrucción actual: útil, pero sin una fuente directa.',
    Color(0xFFD9A0A0),
  ),
  ar(
    'Decisión de ARCANUM',
    'Elección de diseño de la app, no de una fuente.',
    Color(0xFF9FCFB0),
  );

  final String label, meaning;
  final Color color;
  const Procedencia(this.label, this.meaning, this.color);
}

Widget etiqueta(Procedencia p) => Tooltip(
  message: p.meaning,
  child: Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
    decoration: BoxDecoration(
      border: Border.all(color: p.color.withValues(alpha: .7)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(p.label, style: TextStyle(color: p.color, fontSize: 11)),
  ),
);

const _handSteps = {
  ComposeMode.fusion: [
    'Dibuja un cuadrado de guía.',
    'Escribe la primera letra ocupando todo el cuadrado.',
    'Escribe encima cada letra siguiente, en el mismo cuadrado, reutilizando los trazos que ya existen.',
    'Si una letra es giro o reflejo de otra ya dibujada, ya está dentro: no la repitas.',
    'Si el conjunto se amontona, gira, refleja o escala una letra.',
    'Borra la guía y redibuja el signo de memoria.',
  ],
  ComposeMode.block: [
    'Dibuja una rejilla de celdas cuadradas, tantas como letras.',
    'Escribe una letra por celda, en el orden de la reducción.',
    'Donde dos letras tocan el mismo borde, deja un solo trazo.',
    'Borra la rejilla y redibuja el signo de memoria.',
  ],
  ComposeMode.cross: [
    'Funde las vocales en un cuadrado central (si no hay, usa la primera letra).',
    'Traza una cruz desde el centro.',
    'Coloca las consonantes como en KAROLVS: la primera a la izquierda, la segunda arriba, la tercera abajo y la cuarta a la derecha.',
    'Si sobran consonantes, añade una segunda letra más afuera en cada brazo.',
  ],
};

Future<void> showTallerFuentes(BuildContext context, SigilDoc doc) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ArcanumColors.surface,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .75,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: _fuentes(doc),
        ),
      ),
    );

List<Widget> _fuentes(SigilDoc doc) {
  final sg = doc.sigil, r = sg.reduction;
  final body = ArcanumText.body(15),
      muted = ArcanumText.body(14, color: ArcanumColors.ivoryMuted);
  Widget line(String text, [List<Procedencia> p = const []]) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(text, style: body),
        ...p.map(etiqueta),
      ],
    ),
  );
  final mode = kModeInfo[sg.mode]!;
  return [
    Text('Fuentes del sigilo', style: ArcanumText.heading(24)),
    if (r == null)
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text('Forja primero un sigilo.', style: muted),
      ),
    if (r != null) ...[
      sectionTitle('Reducción'),
      line(r.label, const [Procedencia.om]),
      Text(
        r.rule.replaceAll(
          ' [AR]',
          ' (completar con letras únicas es decisión de ARCANUM)',
        ),
        style: muted,
      ),
      Text('${r.cleaned}  →  ${r.units.join(' ')}', style: muted),
      sectionTitle('Letras'),
      for (final l in sg.letters)
        Text(
          l.twin != null
              ? '${l.ch}: no se dibuja; está dentro de ${l.twin!.by} (${l.twin!.how}).'
              : '${l.ch}: ${(l.legible * 100).round()} % visible${l.shares.isEmpty ? '' : '; comparte trazos con ${l.shares.join(', ')}'}.',
          style: muted,
        ),
      Text(
        '${sg.prims.length} trazos; ${sg.prims.where((p) => p.units.length > 1).length} compartidos entre letras; ${sg.hidden.length} ocultos por decisión tuya.',
        style: muted,
      ),
      sectionTitle('Composición: ${mode.$1}'),
      Text(mode.$3, style: muted),
      sectionTitle('Cómo trazarlo a mano'),
      for (var i = 0; i < _handSteps[sg.mode]!.length; i++)
        Text('${i + 1}. ${_handSteps[sg.mode]![i]}', style: muted),
    ],
    sectionTitle('Fuentes'),
    Tooltip(
      message: 'Título original: The Book of Pleasure',
      child: line(
        'Austin Osman Spare, El libro del placer (1913): el sigilo nace de fundir letras.',
        [Procedencia.om],
      ),
    ),
    Tooltip(
      message:
          'Original en inglés: as simple as possible with the various letters recognizable (even with slight difficulty)',
      child: line(
        'Frater U∴D∴, Magia práctica de sigilos, cap. 2: se tachan las letras repetidas y las que quedan se funden «tan simple como sea posible, con las distintas letras reconocibles (aunque cueste un poco)».',
        [Procedencia.om],
      ),
    ),
    line(
      'Phillip Cooper, Magia básica de sigilos: iniciales únicas, superposición y borde opcional.',
      [Procedencia.om],
    ),
    line(
      'Monograma KAROLVS de Carlomagno (desde 769): consonantes en la cruz y vocales en el centro. Es el modelo de la composición en cruz.',
      [Procedencia.hp],
    ),
    line(
      'Remates: el anillo es el rasgo más común de los sellos de la Goetia; la cruz y la cruz patada, el 17 % de sus terminales. El resto es repertorio del taller.',
      [Procedencia.hp, Procedencia.ar],
    ),
    line(
      'Relampagueantes: Flying Roll XIV, «una tabla relampagueante es la que se hace en los colores complementarios».',
      [Procedencia.om],
    ),
    line('Metales de los planetas: Goetia, p. 48.', [Procedencia.hp]),
    line(
      'Tintas, soportes, efectos y el paso del latín al hebreo de los anillos: del taller.',
      [Procedencia.ar, Procedencia.rc],
    ),
    Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        'Mantén pulsado un título traducido para ver el original. La procedencia nunca se guarda dentro del dibujo.',
        style: ArcanumText.body(
          12,
          color: ArcanumColors.goldMuted,
          italic: true,
        ),
      ),
    ),
  ];
}
