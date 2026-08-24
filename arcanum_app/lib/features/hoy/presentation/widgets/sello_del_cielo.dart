/// El sello del cielo: la rueda verdadera con el lacre del regente.
///
/// Sustituye a la tarjeta que se generaba sola al abrir la app. Aqui NO se
/// genera nada hasta que la persona rompe el lacre, y eso arregla tres cosas de
/// golpe: se acaba el gasto de quien no lee, el permiso de datos se pide cuando
/// de verdad salen del telefono, y la app deja de abrir con un muro legal.
///
/// LA FIGURA ES EL ASPECTO, no un dibujo del aspecto: los dos cuerpos van a su
/// separacion angular real. Un trigono con orbe de 3 grados NO sale equilatero,
/// y esa irregularidad es el dato. Ver `figura_aspecto.dart`.
///
/// FISICA, tomada de Balatro:
///   - el trazo se dibuja, no aparece
///   - el lacre salta ANTES que el texto: una cosa detras de otra se lee como
///     causa y efecto; todo a la vez, como un parpadeo
///   - la curva se pasa de largo y vuelve, nada se detiene en seco
///
/// LO QUE EL GUARDIAN DE RENDIMIENTO DE HOY PROHIBE, y por eso no esta aqui:
/// `ArcanumTilt`, `ArcanumFrame`, un segundo `ArcanumSurface` y
/// `TweenAnimationBuilder`. Se usa un `AnimationController` que solo corre
/// durante la apertura y un `CustomPainter` que solo repinta si cambia el
/// progreso. En reposo esto no anima nada.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/arcanum_colors.dart';
import '../../../../core/theme/arcanum_theme.dart';
import '../../../../shared/astro_symbols.dart';
import '../../domain/figura_aspecto.dart';
import 'level_three_aspects.dart';

/// Duracion de la apertura. Corta a proposito: lo bastante para que se lea el
/// gesto, no tanto como para estorbar al segundo dia.
const _apertura = Duration(milliseconds: 900);

class SelloDelCielo extends StatefulWidget {
  const SelloDelCielo({
    super.key,
    required this.today,
    required this.chapter,
    required this.overview,
    required this.regente,
    required this.onAbrir,
    this.abierto = false,
    this.cargando = false,
  });

  /// El transito rapido del dia y el lento que sostiene el capitulo.
  /// Ambos llegan del servidor; el sello no inventa ni filtra cuerpos.
  final Map<String, dynamic>? today;
  final Map<String, dynamic>? chapter;
  final Future<Map<String, dynamic>>? overview;

  /// Planeta regente del dia, para el lacre. Cambia solo cada jornada.
  final String? regente;

  /// Se llama al romper el lacre. Aqui es donde se pide permiso y se genera.
  final VoidCallback onAbrir;

  final bool abierto;
  final bool cargando;

  @override
  State<SelloDelCielo> createState() => _SelloDelCieloState();
}

class _SelloDelCieloState extends State<SelloDelCielo>
    with SingleTickerProviderStateMixin {
  // Se crea en initState y NO con un inicializador perezoso: el camino de
  // "cielo en calma" sale de `build` antes de tocarlo, y entonces `dispose()`
  // seria quien lo instanciara — creando un Ticker mientras se destruye el
  // widget, que es un fallo de assert. Lo cazo un test.
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _apertura);
    if (widget.abierto) _c.value = 1;
  }

  @override
  void didUpdateWidget(SelloDelCielo viejo) {
    super.didUpdateWidget(viejo);
    if (widget.abierto && !viejo.abierto) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.today ?? widget.chapter;
    // Sin transito no hay figura que sellar, y no se inventa una: el cielo
    // puede estar en calma sobre una carta y decirlo es la respuesta correcta.
    if (a == null) return const _CieloEnCalma();

    final angulo = (a['angle'] as num?)?.toInt() ?? 0;
    final separacion = (a['separation'] as num?)?.toDouble();
    final nombre = _nombreDelAspecto(a);
    final chapterName = widget.today == null || widget.chapter == null
        ? null
        : _nombreDelAspecto(widget.chapter!);
    final rulerName = _es(widget.regente).toUpperCase();
    final action = widget.regente == null
        ? 'ROMPER EL LACRE'
        : 'ROMPER EL LACRE DEL $rulerName';

    return Semantics(
      button: !widget.abierto,
      label: widget.abierto
          ? 'Cielo abierto'
          : 'Romper el lacre y leer tu cielo',
      child: GestureDetector(
        onTap: widget.abierto || widget.cargando ? null : widget.onAbrir,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(_c.value);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 168,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(168, 168),
                        painter: _PintorRueda(
                          anguloNominal: angulo,
                          separacion: separacion,
                          progreso: t,
                        ),
                      ),
                      // El lacre se encoge y gira al romperse. Sale ANTES que
                      // el texto: primero se rompe el sello, luego se lee.
                      Opacity(
                        opacity: (1 - t * 1.6).clamp(0.0, 1.0),
                        child: Transform.rotate(
                          angle: -t * 1.1,
                          child: Transform.scale(
                            scale: 1 - t * .75,
                            child: _Lacre(regente: widget.regente),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(nombre, style: ArcanumText.body(15)),
                const SizedBox(height: 3),
                Text(
                  _pieDeSeparacion(separacion),
                  style: ArcanumText.body(
                    12,
                    color: ArcanumColors.ivoryMuted,
                    italic: true,
                  ),
                ),
                if (chapterName != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    'Capítulo: $chapterName',
                    textAlign: TextAlign.center,
                    style: ArcanumText.body(
                      12,
                      color: ArcanumColors.ivoryMuted,
                    ),
                  ),
                ],
                if (!widget.abierto) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    key: const Key('hoy-seal-action'),
                    height: 48,
                    child: Center(
                      child: Text(
                        widget.cargando ? 'ABRIENDO…' : action,
                        style: ArcanumText.body(11, color: ArcanumColors.gold),
                      ),
                    ),
                  ),
                ],
                if (widget.abierto && widget.overview != null)
                  LevelThreeAspects(overview: widget.overview!),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// «Luna trígono Medio Cielo», con los nombres en español.
///
/// Los mapas del catálogo no cubren los ángulos —`ascendant`, `midheaven`—
/// porque no son planetas, así que se traducen aparte. Si algo no está en
/// ninguno de los dos se muestra su clave cruda: peor que en español, pero
/// mucho mejor que un hueco silencioso.
const _angulosEs = {
  'ascendant': 'Ascendente',
  'midheaven': 'Medio Cielo',
  'descendant': 'Descendente',
  'imum_coeli': 'Fondo del Cielo',
};

String _es(String? clave) {
  if (clave == null || clave.isEmpty) return '';
  return planetEs[clave] ?? _angulosEs[clave] ?? clave;
}

String _nombreDelAspecto(Map<String, dynamic> a) {
  final t = _es(a['transit'] as String?);
  final n = _es(a['natal'] as String?);
  final asp =
      aspectEs[a['aspect'] as String?] ?? (a['aspect'] as String? ?? '');
  return '$t $asp $n';
}

/// El grado real, que es la razón de ser de toda la pieza.
String _pieDeSeparacion(double? separacion) {
  if (separacion == null) return 'Separación no disponible.';
  final s = separacion.toStringAsFixed(1).replaceAll('.', ',');
  return 'Separación real: $s°';
}

class _Lacre extends StatelessWidget {
  const _Lacre({this.regente});
  final String? regente;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-.35, -.4),
          colors: [Color(0xFF7D2033), ArcanumColors.burgundy],
        ),
        border: Border.all(
          color: ArcanumColors.burgundyLight.withValues(alpha: .45),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x8C000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        planetGlyph[regente] ?? '✦',
        style: const TextStyle(fontSize: 18, color: Color(0xFFF0D7DD)),
      ),
    );
  }
}

class _CieloEnCalma extends StatelessWidget {
  const _CieloEnCalma();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Text(
        'Hoy no hay aspectos exactos sobre tu carta. El cielo está en calma.',
        textAlign: TextAlign.center,
        style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
      ),
    );
  }
}

/// Dibuja la rueda y la figura del aspecto.
///
/// `shouldRepaint` solo devuelve true cuando cambia el progreso: en reposo esto
/// no repinta nada, que es lo que el guardian de rendimiento de Hoy exige.
class _PintorRueda extends CustomPainter {
  const _PintorRueda({
    required this.anguloNominal,
    required this.separacion,
    required this.progreso,
  });

  final int anguloNominal;
  final double? separacion;
  final double progreso;

  @override
  void paint(Canvas lienzo, Size tam) {
    final centro = Offset(tam.width / 2, tam.height / 2);
    final radio = math.min(tam.width, tam.height) / 2 - 16;

    final rueda = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = ArcanumColors.gold.withValues(alpha: .16);
    lienzo.drawCircle(centro, radio, rueda);
    lienzo.drawCircle(
      centro,
      radio - 9,
      rueda..color = ArcanumColors.gold.withValues(alpha: .07),
    );

    final f = figuraDe(
      anguloNominal: anguloNominal,
      separacion: separacion,
      radio: radio,
      centro: PuntoRueda(centro.dx, centro.dy),
    );

    // El trazo se DIBUJA en vez de aparecer: se recorta el camino segun el
    // progreso, que es lo que convierte un dibujo en un gesto.
    final camino = Path()..moveTo(f.vertices.first.x, f.vertices.first.y);
    for (final v in f.vertices.skip(1)) {
      camino.lineTo(v.x, v.y);
    }
    if (f.cerrada) camino.close();

    final trazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = ArcanumColors.gold.withValues(alpha: .85);

    for (final metrica in camino.computeMetrics()) {
      lienzo.drawPath(metrica.extractPath(0, metrica.length * progreso), trazo);
    }

    // Los dos cuerpos: presentes desde el principio, pero apagados hasta que la
    // figura los une. Antes de trazar no son un aspecto, son dos puntos.
    final astro = Paint()
      ..color = ArcanumColors.gold.withValues(alpha: .45 + .55 * progreso);
    lienzo.drawCircle(Offset(f.transito.x, f.transito.y), 4.5, astro);
    lienzo.drawCircle(Offset(f.natal.x, f.natal.y), 4.5, astro);
  }

  @override
  bool shouldRepaint(_PintorRueda viejo) =>
      viejo.progreso != progreso ||
      viejo.anguloNominal != anguloNominal ||
      viejo.separacion != separacion;
}
