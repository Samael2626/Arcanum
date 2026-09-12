@Tags(['capturas'])
library;

/// BOCETO: cuatro maneras del selector de intérprete, retratadas a 360 px.
///
/// No toca código de producción: cada variante se dibuja aquí para poder
/// mirarlas juntas antes de fijar una. Se borra cuando se elija.
import 'dart:io';

import 'package:arcanum_app/core/theme/arcanum_colors.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _ancho = 360.0;
const _escala = 3.0;

/// La fuente de iconos vive en la cache del SDK, no en el proyecto. Sin ella
/// cada icono sale como un cuadro vacio y el boceto mentiria justo sobre lo
/// que hay que juzgar.
String? _iconosDeMaterial() {
  const candidatas = [
    r'D:/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    r'D:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ];
  for (final ruta in candidatas) {
    if (File(ruta).existsSync()) return ruta;
  }
  return null;
}

Future<void> _cargarFuentes() async {
  final manifiesto = <String, List<String>>{
    'Cormorant Garamond': ['assets/fonts/CormorantGaramond-600.ttf'],
    'Crimson Pro': [
      'assets/fonts/CrimsonPro-400.ttf',
      'assets/fonts/CrimsonPro-500.ttf',
      'assets/fonts/CrimsonPro-600.ttf',
    ],
    'ArcanumGlifos': ['assets/fonts/ArcanumGlifos-Regular.ttf'],
  };
  final iconos = _iconosDeMaterial();
  if (iconos != null) manifiesto['MaterialIcons'] = [iconos];
  for (final e in manifiesto.entries) {
    final c = FontLoader(e.key);
    for (final r in e.value) {
      c.addFont(File(r).readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
    await c.load();
  }
}

/// A · Segmentado igual que Consultar|Aprender. Sin descripciones: el porqué
/// va en UNA línea debajo, que cambia con lo elegido.
class _VarianteA extends StatelessWidget {
  const _VarianteA({required this.tradicion});
  final bool tradicion;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool activo) => Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: activo
              ? ArcanumColors.gold.withValues(alpha: 0.16)
              : Colors.transparent,
        ),
        child: Text(
          label,
          style: ArcanumText.body(
            15,
            color: activo ? ArcanumColors.gold : ArcanumColors.ivoryMuted,
          ),
        ),
      ),
    );
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: ArcanumColors.goldMuted.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              seg('El oráculo', !tradicion),
              seg('La tradición', tradicion),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          tradicion
              ? 'Las cartas llegan con su significado del Book T. Sin IA.'
              : 'Un modelo lee tu tirada y responde tu pregunta.',
          textAlign: TextAlign.center,
          style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
        ),
      ],
    );
  }
}

/// B · Dos filas a ancho completo. La descripción cabe entera en una línea
/// porque dispone de los 312 px, no de 131.
class _VarianteB extends StatelessWidget {
  const _VarianteB({required this.tradicion});
  final bool tradicion;

  @override
  Widget build(BuildContext context) {
    Widget fila(String titulo, String pie, bool activo) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: activo
            ? ArcanumColors.gold.withValues(alpha: 0.14)
            : Colors.transparent,
        border: Border.all(
          color: activo
              ? ArcanumColors.gold
              : ArcanumColors.goldMuted.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            activo ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            size: 18,
            color: activo ? ArcanumColors.gold : ArcanumColors.goldMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  style: ArcanumText.body(
                    15,
                    color: activo
                        ? ArcanumColors.gold
                        : ArcanumColors.ivory,
                  ),
                ),
                Text(
                  pie,
                  style: ArcanumText.body(
                    12,
                    color: ArcanumColors.ivoryMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        fila('El oráculo', 'Un modelo interpreta tu tirada', !tradicion),
        fila('La tradición', 'El significado del Book T, sin IA', tradicion),
      ],
    );
  }
}

/// C · Sin control aparte: la elección va en el propio botón de tirar, como
/// dos botones. Lo que se toca es lo que pasa.
class _VarianteC extends StatelessWidget {
  const _VarianteC({required this.tradicion});
  final bool tradicion;

  @override
  Widget build(BuildContext context) {
    Widget boton(String label, String pie, bool principal) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: principal
              ? ArcanumColors.gold
              : ArcanumColors.goldMuted.withValues(alpha: 0.45),
          width: principal ? 1.4 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: ArcanumText.heading(
              19,
              color: principal ? ArcanumColors.gold : ArcanumColors.ivoryMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            pie,
            textAlign: TextAlign.center,
            style: ArcanumText.body(12, color: ArcanumColors.ivoryMuted),
          ),
        ],
      ),
    );
    return Column(
      children: [
        boton('Consultar al oráculo', 'Un modelo interpreta tu tirada', !tradicion),
        boton('Tirar por la tradición', 'El significado del Book T, sin IA', tradicion),
      ],
    );
  }
}

/// D · Una sola línea, con la alternativa como enlace. Lo mínimo que puede
/// ser: la vía por defecto manda y la otra se ofrece sin ocupar sitio.
class _VarianteD extends StatelessWidget {
  const _VarianteD({required this.tradicion});
  final bool tradicion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              tradicion ? Icons.menu_book_outlined : Icons.auto_awesome_outlined,
              size: 17,
              color: ArcanumColors.gold,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                tradicion
                    ? 'Lee la tradición: el Book T, sin IA'
                    : 'Lee el oráculo: un modelo interpreta',
                style: ArcanumText.body(14, color: ArcanumColors.ivory),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Text(
            tradicion ? 'Que lea el oráculo' : 'Que lea la tradición',
            style: ArcanumText.body(
              13,
              italic: true,
              color: ArcanumColors.gold,
            ).copyWith(decoration: TextDecoration.underline),
          ),
        ),
      ],
    );
  }
}

/// El riesgo de A, que solo se ve en contexto: encima vive el conmutador
/// Consultar|Aprender, que es EXACTAMENTE la misma pildora. Dos iguales
/// apiladas pueden leerse como un solo control de cuatro opciones.
class _EnContexto extends StatelessWidget {
  const _EnContexto({required this.abajo});
  final Widget abajo;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool activo) => Expanded(
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: activo
              ? ArcanumColors.gold.withValues(alpha: 0.16)
              : Colors.transparent,
        ),
        child: Text(
          label,
          style: ArcanumText.body(
            15,
            color: activo ? ArcanumColors.gold : ArcanumColors.ivoryMuted,
          ),
        ),
      ),
    );
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: ArcanumColors.goldMuted.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [seg('Consultar', true), seg('Aprender', false)],
          ),
        ),
        const SizedBox(height: 18),
        abajo,
      ],
    );
  }
}

// ── Refinamientos de D ──────────────────────────────────────────────────────
// Los tres arreglan lo mismo: el enlace no tenia area tactil, el subrayado no
// es el idioma de la app -- lo tocable se marca con el oro, sin adornos -- y
// el subjuntivo sonaba a deseo. Ninguno engorda.

/// D1 · Una sola linea: quien lee a la izquierda, el cambio a la derecha.
class _D1 extends StatelessWidget {
  const _D1({required this.tradicion});
  final bool tradicion;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tradicion ? 'Lo lee la tradición' : 'Lo lee el oráculo',
              style: ArcanumText.body(15, color: ArcanumColors.ivory),
            ),
          ),
          // El area tactil llega hasta el borde: 48 de alto y todo el ancho
          // del texto mas su respiro.
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tradicion ? 'El oráculo' : 'La tradición',
                  style: ArcanumText.body(15, color: ArcanumColors.gold),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.swap_horiz, size: 17, color: ArcanumColors.gold),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// D2 · Dos lineas, mismo borde izquierdo, sin subrayado y con la accion en
/// infinitivo. Conserva la explicacion, que es lo que ensena.
class _D2 extends StatelessWidget {
  const _D2({required this.tradicion});
  final bool tradicion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tradicion
              ? 'Lo lee la tradición: el significado del Book T, sin IA.'
              : 'Lo lee el oráculo: un modelo interpreta tu tirada.',
          style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.swap_horiz, size: 17, color: ArcanumColors.gold),
              const SizedBox(width: 8),
              Text(
                tradicion ? 'Leer con el oráculo' : 'Leer con la tradición',
                style: ArcanumText.body(15, color: ArcanumColors.gold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// D3 · Las dos vias a la vista, en la misma linea. La activa en marfil, la
/// otra en oro y tocable. Se ve que hay eleccion sin abrir nada.
class _D3 extends StatelessWidget {
  const _D3({required this.tradicion});
  final bool tradicion;

  @override
  Widget build(BuildContext context) {
    // El filete tiene que ir pegado al texto, no al alto del area tactil: con
    // el `Border` sobre la caja de 48, el Row estiraba al hijo y la linea caia
    // al fondo del bloque, despegada de la palabra.
    Widget via(String label, bool activa) => SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: ArcanumText.body(
                15,
                color: activa ? ArcanumColors.ivory : ArcanumColors.gold,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              height: 1.4,
              width: activa ? 58 : 0,
              color: ArcanumColors.gold,
            ),
          ],
        ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('LEE  ', style: ArcanumText.label()),
        via('El oráculo', !tradicion),
        via('La tradición', tradicion),
      ],
    );
  }
}

Future<void> _retratar(
  WidgetTester tester,
  String nombre,
  Widget variante,
) async {
  tester.view
    ..physicalSize = const Size(_ancho * _escala, 420 * _escala)
    ..devicePixelRatio = _escala;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildArcanumTheme(),
      home: Scaffold(
        backgroundColor: ArcanumColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: variante,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('salida/$nombre.png'),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _cargarFuentes();
  });

  testWidgets('A segmentado con una linea', (t) async {
    await _retratar(t, 'sel-a-oraculo', const _VarianteA(tradicion: false));
  });
  testWidgets('A segmentado, tradicion', (t) async {
    await _retratar(t, 'sel-a-tradicion', const _VarianteA(tradicion: true));
  });
  testWidgets('B dos filas', (t) async {
    await _retratar(t, 'sel-b', const _VarianteB(tradicion: false));
  });
  testWidgets('C dos botones', (t) async {
    await _retratar(t, 'sel-c', const _VarianteC(tradicion: false));
  });
  testWidgets('D una linea con enlace', (t) async {
    await _retratar(t, 'sel-d', const _VarianteD(tradicion: false));
  });
  testWidgets('D1 una linea, cambio a la derecha', (t) async {
    await _retratar(t, 'sel-d1', const _D1(tradicion: false));
  });
  testWidgets('D2 dos lineas limpias', (t) async {
    await _retratar(t, 'sel-d2', const _D2(tradicion: false));
  });
  testWidgets('D3 las dos vias a la vista', (t) async {
    await _retratar(t, 'sel-d3', const _D3(tradicion: false));
  });
  testWidgets('D3 elegida la tradicion', (t) async {
    await _retratar(t, 'sel-d3-trad', const _D3(tradicion: true));
  });
  testWidgets('A en contexto, bajo el conmutador', (t) async {
    await _retratar(t, 'sel-a-contexto',
        const _EnContexto(abajo: _VarianteA(tradicion: false)));
  });
  testWidgets('B en contexto, bajo el conmutador', (t) async {
    await _retratar(t, 'sel-b-contexto',
        const _EnContexto(abajo: _VarianteB(tradicion: false)));
  });
}
