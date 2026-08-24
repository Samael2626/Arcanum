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
    final action = widget.regente == null
        ? 'Abrir el sello'
        : 'Abrir el sello ${_delRegente(widget.regente!)}';

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
                // Los dos papeles, con su cuerpo dentro. El nombre va AQUI y no
                // grabado en el aro: medido, sextil, cuadratura y oposicion
                // ponen un vertice justo donde caeria un rotulo abajo.
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    if (widget.today != null)
                      _ChipDePapel(
                        papel: 'hoy',
                        cuerpo: pointEs(widget.today!['transit'] as String?),
                        punteado: false,
                      ),
                    if (widget.chapter != null)
                      _ChipDePapel(
                        papel: 'capítulo',
                        cuerpo: pointEs(widget.chapter!['transit'] as String?),
                        punteado: true,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(nombre, style: ArcanumText.body(15)),
                const SizedBox(height: 3),
                Text(
                  _pieDeSeparacion(separacion, a['exact_at'] as String?),
                  textAlign: TextAlign.center,
                  style: ArcanumText.body(
                    12,
                    color: ArcanumColors.ivoryMuted,
                    italic: true,
                  ),
                ),
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
String _nombreDelAspecto(Map<String, dynamic> a) {
  final t = pointEs(a['transit'] as String?);
  final n = pointEs(a['natal'] as String?);
  final asp =
      aspectEs[a['aspect'] as String?] ?? (a['aspect'] as String? ?? '');
  return '$t $asp $n';
}

/// El grado real, que es la razón de ser de toda la pieza, y cuándo se cierra.
///
/// La fecha importa más que el grado para quien no lee grados: dice si esto
/// aprieta hoy o si aún queda semana. El motor la calcula con la velocidad
/// instantánea del planeta y devuelve `null` cuando la cifra sería ficción
/// —Saturno a 0,0018°/día tardaría años en recorrer su orbe—, y entonces aquí
/// no se dice nada en vez de inventar un día.
String _pieDeSeparacion(double? separacion, String? exactoEn) {
  final cierre = _cuandoCierra(exactoEn);
  if (separacion == null) {
    return cierre == null ? 'Separación no disponible.' : 'Cierra $cierre.';
  }
  final s = separacion.toStringAsFixed(1).replaceAll('.', ',');
  return cierre == null
      ? 'Separación real: $s°'
      : 'Separación real: $s° · cierra $cierre';
}

const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto',
  'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// «hoy», «mañana» o «el 28 de agosto».
///
/// En días, no en horas: la hora exacta de una perfección sugeriría una
/// precisión que una velocidad instantánea no tiene.
String? _cuandoCierra(String? exactoEn) {
  if (exactoEn == null) return null;
  final cuando = DateTime.tryParse(exactoEn)?.toLocal();
  if (cuando == null) return null;
  final ahora = DateTime.now();
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final dia = DateTime(cuando.year, cuando.month, cuando.day);
  final faltan = dia.difference(hoy).inDays;
  if (faltan < 0) return null;
  if (faltan == 0) return 'hoy';
  if (faltan == 1) return 'mañana';
  return 'el ${cuando.day} de ${_meses[cuando.month - 1]}';
}

/// «del Sol», «de la Luna», «de Venus».
///
/// El artículo no es adorno: «Abrir el sello de Sol» está mal escrito, y esto
/// lo lee una persona. Solo las dos luminarias lo llevan.
String _delRegente(String clave) {
  const conArticulo = {'sun': 'del Sol', 'moon': 'de la Luna'};
  return conArticulo[clave] ?? 'de ${pointEs(clave)}';
}

/// El chip de un papel: su trazo, el papel y el cuerpo que lo ocupa.
///
/// El trazo se DIBUJA, no se escribe con un carácter. El guion largo y la línea
/// punteada existen en Unicode, pero dependerían de que la fuente los traiga, y
/// esta pantalla ya tuvo un cuadrado vacío por confiar en eso.
class _ChipDePapel extends StatelessWidget {
  const _ChipDePapel({
    required this.papel,
    required this.cuerpo,
    required this.punteado,
  });

  final String papel;
  final String cuerpo;

  /// Punteado para el capítulo, continuo para hoy: lo que viene de lejos y
  /// sigue se dibuja entrecortado; lo que pasa hoy va entero.
  final bool punteado;

  @override
  Widget build(BuildContext context) {
    final color = punteado ? ArcanumColors.ivoryMuted : ArcanumColors.gold;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(16, 2),
          painter: _PintorTrazo(color: color, punteado: punteado),
        ),
        const SizedBox(width: 7),
        Text('$papel · $cuerpo', style: ArcanumText.body(12, color: color)),
      ],
    );
  }
}

class _PintorTrazo extends CustomPainter {
  const _PintorTrazo({required this.color, required this.punteado});

  final Color color;
  final bool punteado;

  @override
  void paint(Canvas lienzo, Size tam) {
    final pincel = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final y = tam.height / 2;
    if (!punteado) {
      lienzo.drawLine(Offset(0, y), Offset(tam.width, y), pincel);
      return;
    }
    for (var x = 0.0; x < tam.width; x += 4) {
      lienzo.drawLine(
        Offset(x, y),
        Offset(math.min(x + 2, tam.width), y),
        pincel,
      );
    }
  }

  @override
  bool shouldRepaint(_PintorTrazo viejo) =>
      viejo.color != color || viejo.punteado != punteado;
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

    // EL PLIEGUE.
    //
    // Con el sello cerrado se ve el PUENTE: la cuerda entre los dos cuerpos,
    // que es el aspecto reducido a lo minimo -- estos dos se miran. Al abrir,
    // los vertices que completan la figura se despliegan DESDE esa cuerda, y
    // el puente se convierte en el sigilo.
    //
    // Una oposicion no se pliega, y esta bien: su figura ya ES el puente. No
    // hay nada que desplegar porque dos puntos enfrentados no forman poligono.
    final vs = f.vertices;
    final desde = Offset(vs.first.x, vs.first.y);
    final hasta = Offset(vs[1].x, vs[1].y);
    final puntos = <Offset>[];
    for (var i = 0; i < vs.length; i++) {
      final destino = Offset(vs[i].x, vs[i].y);
      if (i <= 1) {
        // Los dos cuerpos no se mueven: estan en su grado real desde el
        // principio y ahi se quedan.
        puntos.add(destino);
        continue;
      }
      // Los demas nacen repartidos sobre la cuerda y viajan a su sitio.
      final reparto = (i - 1) / (vs.length - 1);
      final origen = Offset.lerp(hasta, desde, reparto)!;
      puntos.add(Offset.lerp(origen, destino, progreso)!);
    }

    final camino = Path()..moveTo(puntos.first.dx, puntos.first.dy);
    for (final punto in puntos.skip(1)) {
      camino.lineTo(punto.dx, punto.dy);
    }
    if (f.cerrada) camino.close();

    final trazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = ArcanumColors.gold.withValues(alpha: .55 + .30 * progreso);
    lienzo.drawPath(camino, trazo);

    // Los dos cuerpos, ya unidos por el puente desde el principio. Se realzan
    // al abrir, pero no nacen apagados: el aspecto existe antes de leerlo.
    final astro = Paint()
      ..color = ArcanumColors.gold.withValues(alpha: .70 + .30 * progreso);
    lienzo.drawCircle(Offset(f.transito.x, f.transito.y), 4.5, astro);
    lienzo.drawCircle(Offset(f.natal.x, f.natal.y), 4.5, astro);
  }

  @override
  bool shouldRepaint(_PintorRueda viejo) =>
      viejo.progreso != progreso ||
      viejo.anguloNominal != anguloNominal ||
      viejo.separacion != separacion;
}
