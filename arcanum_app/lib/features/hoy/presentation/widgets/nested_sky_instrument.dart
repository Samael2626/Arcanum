import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/arcanum_colors.dart';
import '../../../../core/theme/arcanum_theme.dart';
import '../../../../shared/astro_symbols.dart';
import '../../../../shared/widgets/arcanum_card.dart';
import '../../../../shared/widgets/arcanum_mood.dart';
import '../../../../shared/widgets/moon_disc.dart';
import 'planetary_hour_dial.dart';
import 'today_card.dart';

/// Cual de los tres cuerpos del instrumento se esta mirando.
///
/// Son tres lecturas del mismo cielo y de tres relojes distintos: el regente
/// dura todo el dia, la hora ~60 min, y la Luna se mueve en semanas.
enum SkyBody {
  /// Regente del dia planetario. Empieza al orto, no a medianoche.
  ruler,

  /// Hora planetaria en curso.
  hour,

  /// La Luna. Es global: se puede leer sin lugar confirmado.
  moon,
}

/// El instrumento de Hoy: los tres relojes anidados, con un selector.
///
/// POR QUE HAY UN SELECTOR Y NO TRES BLOQUES APILADOS
/// -------------------------------------------------
/// Antes esta tarjeta enseñaba a la vez el regente, la hora y la Luna, uno
/// debajo de otro, con UNA sola fila de chips que solo servia al planeta de la
/// hora. Tres lecturas compitiendo por la misma mirada y dos de ellas sin
/// salida propia.
///
/// El prototipo (`.tmp/diseno/hoy_definitivo.html`) lo resolvio con tres
/// botones redondos bajo el aro: se elige un cuerpo y el panel entero cambia
/// —etiqueta, nombre, dato y acento— junto con sus chips. Es la forma de que
/// los tres tengan su vista sin ocupar tres veces el sitio.
///
/// El centro pinta UNA escena, la del cuerpo elegido, no los tres a la vez:
/// el anillo caldeo para el regente, el dial de 24 marcas para la hora y el
/// disco lunar para la Luna. Antes los tres se superponian en el mismo aro y no
/// cabia ninguna capa arcana encima sin chocar con las otras dos.
///
/// La escena SIGUE abriendo la hoja de lore de su cuerpo al tocarla. Son dos
/// gestos distintos y no redundantes: el selector CAMBIA lo que se lee aqui, la
/// escena LLEVA a otra pantalla. Ver la regla "si se toca, abre".
///
/// SIN LUGAR CONFIRMADO no hay selector: el regente y la hora dependen del orto
/// y el ocaso locales, asi que no existen, y lo unico que queda es la Luna. Se
/// declara la ausencia en vez de rellenarla — un dato falso con la misma
/// apariencia que uno verdadero es peor que un hueco.
class NestedSkyInstrument extends StatefulWidget {
  const NestedSkyInstrument({
    super.key,
    required this.moon,
    required this.actionsFor,
    required this.onMoonTap,
    required this.onConfirmPlace,
    this.ruler,
    this.hour,
    this.onRulerTap,
    this.onHourTap,
  });

  final String? ruler;
  final Map<String, dynamic>? hour;
  final Map<String, dynamic> moon;

  /// Los chips del cuerpo elegido. Es un constructor y no un widget fijo
  /// porque la fila entera cambia con la seleccion: los chips del Sol no
  /// sirven para la Luna.
  final Widget Function(String planet) actionsFor;

  final VoidCallback? onRulerTap;
  final VoidCallback? onHourTap;
  final VoidCallback onMoonTap;
  final VoidCallback onConfirmPlace;

  @override
  State<NestedSkyInstrument> createState() => _NestedSkyInstrumentState();
}

class _NestedSkyInstrumentState extends State<NestedSkyInstrument> {
  /// Arranca en el regente: es la lectura mas lenta de las tres y la que da
  /// marco a las otras dos. La hora cambia sola cada ~60 min y llamaria la
  /// atencion cada vez que se abre la app.
  SkyBody _elegido = SkyBody.ruler;

  String? get _hourPlanet => widget.hour?['planet'] as String?;

  bool get _hasPlace => widget.ruler != null && _hourPlanet != null;

  /// El cuerpo que se esta mirando de verdad. Sin lugar, siempre la Luna:
  /// mantener elegido un regente que no existe dejaria el panel vacio.
  SkyBody get _actual => _hasPlace ? _elegido : SkyBody.moon;

  /// Planeta al que apuntan los chips del cuerpo elegido.
  String get _planeta => switch (_actual) {
    SkyBody.ruler => widget.ruler!,
    SkyBody.hour => _hourPlanet!,
    SkyBody.moon => 'moon',
  };

  @override
  Widget build(BuildContext context) {
    final illumination = (widget.moon['illumination'] as num).toDouble();
    final waxing = widget.moon['is_waxing'] as bool;
    final phase = widget.moon['phase_name'] as String;
    final age = (widget.moon['age_days'] as num?)?.toDouble();
    final mood = ArcanumMood.forPlanet(_planeta);

    return TodayCard(
      mood: mood,
      radius: 18,
      intensity: 0.58,
      child: Column(
        children: [
          const SectionLabel('INSTRUMENTO DEL DÍA'),
          const SizedBox(height: 14),
          SizedBox.square(
            dimension: 248,
            child: switch (_actual) {
              SkyBody.ruler => _RulerScene(
                ruler: widget.ruler!,
                onTap: widget.onRulerTap!,
              ),
              SkyBody.hour => _HourScene(
                planet: _hourPlanet!,
                progress: _hourProgress(
                  widget.hour,
                  (widget.hour?['minutes_remaining'] as num?)?.toInt(),
                ),
                hourNumber:
                    (widget.hour?['hour_number'] as num?)?.toInt() ?? 0,
                isDay: widget.hour?['is_daytime'] == true,
                onTap: widget.onHourTap!,
              ),
              SkyBody.moon => _MoonScene(
                illumination: illumination,
                waxing: waxing,
                phase: phase,
                onTap: widget.onMoonTap,
              ),
            },
          ),
          if (_hasPlace) ...[
            const SizedBox(height: 14),
            _Selector(
              elegido: _actual,
              ruler: widget.ruler!,
              hourPlanet: _hourPlanet!,
              illumination: illumination,
              waxing: waxing,
              onElegir: (cuerpo) => setState(() => _elegido = cuerpo),
            ),
            const SizedBox(height: 16),
            _Panel(
              etiqueta: _etiqueta,
              nombre: _nombre(phase),
              dato: _dato(illumination, age),
            ),
          ] else ...[
            const SizedBox(height: 10),
            _Panel(
              etiqueta: 'La Luna',
              nombre: phase,
              dato: _datoLunar(illumination, age),
            ),
            const SizedBox(height: 16),
            Text(
              'No disponible sin tu lugar',
              textAlign: TextAlign.center,
              style: ArcanumText.heading(23),
            ),
            const SizedBox(height: 8),
            Text(
              'El regente y la hora dependen del amanecer y el ocaso de un '
              'lugar confirmado. La Luna permanece porque es global.',
              textAlign: TextAlign.center,
              style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: widget.onConfirmPlace,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                side: BorderSide(
                  color: ArcanumColors.gold.withValues(alpha: 0.55),
                ),
              ),
              child: Text(
                'Confirmar mi lugar',
                style: ArcanumText.body(14, color: ArcanumColors.gold),
              ),
            ),
          ],
          const SizedBox(height: 14),
          widget.actionsFor(_planeta),
        ],
      ),
    );
  }

  String get _etiqueta => switch (_actual) {
    SkyBody.ruler => 'Regente del día',
    SkyBody.hour => 'Hora planetaria',
    SkyBody.moon => 'La Luna',
  };

  String _nombre(String phase) => switch (_actual) {
    SkyBody.ruler => 'Día de ${planetEs[widget.ruler] ?? widget.ruler}',
    SkyBody.hour => 'Hora de ${planetEs[_hourPlanet] ?? _hourPlanet}',
    SkyBody.moon => phase,
  };

  String _dato(double illumination, double? age) => switch (_actual) {
    SkyBody.ruler => 'Rige la jornada entera, desde el amanecer',
    SkyBody.hour => _datoHora(),
    SkyBody.moon => _datoLunar(illumination, age),
  };

  String _datoHora() {
    final minutos = (widget.hour?['minutes_remaining'] as num?)?.toInt();
    final franja = widget.hour?['is_daytime'] == true
        ? 'Hora diurna'
        : 'Hora nocturna';
    return minutos == null ? franja : '$franja · termina en $minutos min';
  }

  String _datoLunar(double illumination, double? age) =>
      '${(illumination * 100).round()}% iluminada'
      '${age == null ? '' : ' · ${age.round()} días'}';

  static double _hourProgress(Map<String, dynamic>? hour, int? minutes) {
    final starts = DateTime.tryParse((hour?['starts_at'] as String?) ?? '');
    final ends = DateTime.tryParse((hour?['ends_at'] as String?) ?? '');
    if (starts != null && ends != null) {
      final total = ends.difference(starts).inSeconds;
      final elapsed = DateTime.now()
          .toUtc()
          .difference(starts.toUtc())
          .inSeconds;
      if (total > 0) return (elapsed / total).clamp(0.0, 1.0);
    }
    return (1 - ((minutes ?? 60) / 60)).clamp(0.0, 1.0);
  }
}

/// Los tres botones. Redondos, del tamaño de un pulgar, con el glifo del cuerpo
/// dentro y el elegido encendido con su propio acento.
class _Selector extends StatelessWidget {
  const _Selector({
    required this.elegido,
    required this.ruler,
    required this.hourPlanet,
    required this.illumination,
    required this.waxing,
    required this.onElegir,
  });

  final SkyBody elegido;
  final String ruler;
  final String hourPlanet;
  final double illumination;
  final bool waxing;
  final ValueChanged<SkyBody> onElegir;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Boton(
          key: const Key('hoy-selector-ruler'),
          semantica: 'Regente del día: ${planetEs[ruler] ?? ruler}',
          activo: elegido == SkyBody.ruler,
          acento: ArcanumMood.forPlanet(ruler).accent,
          onTap: () => onElegir(SkyBody.ruler),
          child: Text(
            planetGlyph[ruler] ?? '✦',
            style: TextStyle(
              fontSize: 20,
              height: 1,
              color: ArcanumMood.forPlanet(ruler).accent,
            ),
          ),
        ),
        const SizedBox(width: 10),
        _Boton(
          key: const Key('hoy-selector-hour'),
          semantica:
              'Hora planetaria: ${planetEs[hourPlanet] ?? hourPlanet}',
          activo: elegido == SkyBody.hour,
          acento: ArcanumMood.forPlanet(hourPlanet).accent,
          onTap: () => onElegir(SkyBody.hour),
          child: Text(
            planetGlyph[hourPlanet] ?? '✦',
            style: TextStyle(
              fontSize: 20,
              height: 1,
              color: ArcanumMood.forPlanet(hourPlanet).accent,
            ),
          ),
        ),
        const SizedBox(width: 10),
        _Boton(
          key: const Key('hoy-selector-moon'),
          semantica: 'La Luna',
          activo: elegido == SkyBody.moon,
          acento: ArcanumMood.forPlanet('moon').accent,
          onTap: () => onElegir(SkyBody.moon),
          // El disco lunar de verdad, con su fase: es mas reconocible que un
          // glifo y ya se dibuja arriba, asi que no introduce vocabulario nuevo.
          child: MoonDisc(
            illumination: illumination,
            waxing: waxing,
            size: 20,
          ),
        ),
      ],
    );
  }
}

class _Boton extends StatelessWidget {
  const _Boton({
    super.key,
    required this.semantica,
    required this.activo,
    required this.acento,
    required this.onTap,
    required this.child,
  });

  final String semantica;
  final bool activo;
  final Color acento;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activo,
      label: semantica,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onTap,
          radius: 26,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            // 48 dp: el minimo tactil del proyecto, no una cifra estetica.
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ArcanumColors.background.withValues(alpha: 0.55),
              border: Border.all(
                color: activo
                    ? acento
                    : ArcanumColors.gold.withValues(alpha: 0.2),
              ),
              boxShadow: activo
                  ? [
                      BoxShadow(
                        color: acento.withValues(alpha: 0.4),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta, nombre y dato del cuerpo elegido. Tres lineas, las mismas para los
/// tres: lo que cambia es el contenido, no la forma, para que cambiar de cuerpo
/// no mueva la tarjeta entera.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.etiqueta,
    required this.nombre,
    required this.dato,
  });

  final String etiqueta;
  final String nombre;
  final String dato;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          etiqueta,
          textAlign: TextAlign.center,
          style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
        ),
        const SizedBox(height: 4),
        Text(nombre, textAlign: TextAlign.center, style: ArcanumText.heading(26)),
        const SizedBox(height: 5),
        Text(
          dato,
          textAlign: TextAlign.center,
          style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
        ),
      ],
    );
  }
}

class _InstrumentTarget extends StatelessWidget {
  const _InstrumentTarget({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: SizedBox.square(dimension: 48, child: Center(child: child)),
        ),
      ),
    );
  }
}

/// Orden caldeo de los siete cuerpos, el mismo que calcula el servidor
/// (`planetary_hours.py`: `CHALDEAN`). No es decoracion: es la rueda de la que
/// sale el regente del dia y el de cada hora, asi que ensenarla ensena el
/// mecanismo.
const List<String> kChaldeanOrder = [
  'sun',
  'venus',
  'mercury',
  'moon',
  'saturn',
  'jupiter',
  'mars',
];

/// La escena del regente: el anillo caldeo.
///
/// De las cinco capas arcanas que se prototiparon sobre la base de cuatro
/// rombos, esta es la unica que dice algo verdadero y comprobable del dia: los
/// siete cuerpos en su orden real, con el de hoy encendido y los otros seis en
/// penumbra. Las demas (kamea, metal, orbita) anaden un sistema que la pantalla
/// no usa para nada, y apilar dos sistemas en una imagen es justo lo que la
/// guia de sigilos prohibe.
class _RulerScene extends StatelessWidget {
  const _RulerScene({required this.ruler, required this.onTap});

  final String ruler;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final acento = ArcanumMood.forPlanet(ruler).accent;
    return CustomPaint(
      painter: _ChaldeanRingPainter(ruler: ruler, accent: acento),
      child: Center(
        child: _InstrumentTarget(
          key: const Key('hoy-ruler-target'),
          label: 'Regente del día: ${planetEs[ruler] ?? ruler}',
          onTap: onTap,
          child: Text(
            planetGlyph[ruler] ?? '✦',
            style: TextStyle(fontSize: 54, height: 1, color: acento),
          ),
        ),
      ),
    );
  }
}

class _ChaldeanRingPainter extends CustomPainter {
  const _ChaldeanRingPainter({required this.ruler, required this.accent});

  final String ruler;
  final Color accent;

  /// Radios en fraccion del lado, calcados del prototipo (viewBox 100): el
  /// anillo de los siete a 0,38 y el disco del glifo a 0,30.
  static const _ringFraction = 0.38;
  static const _discFraction = 0.30;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final side = size.shortestSide;
    final ring = side * _ringFraction;
    final disc = side * _discFraction;

    canvas
      ..drawCircle(
        center,
        side * 0.48,
        Paint()
          ..shader = RadialGradient(
            colors: [accent.withValues(alpha: 0.20), Colors.transparent],
          ).createShader(Rect.fromCircle(center: center, radius: side * 0.48)),
      )
      ..drawCircle(
        center,
        disc,
        // 0,38 y no el 0,60 del prototipo: alli el fondo de la tarjeta era
        // neutro, aqui esta tenido del planeta y un disco casi negro se
        // recortaba como una mancha.
        Paint()..color = ArcanumColors.background.withValues(alpha: 0.38),
      )
      ..drawCircle(
        center,
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = ArcanumColors.gold.withValues(alpha: 0.28),
      );

    for (var i = 0; i < kChaldeanOrder.length; i++) {
      final planet = kChaldeanOrder[i];
      final angle = -math.pi / 2 + i * 2 * math.pi / kChaldeanOrder.length;
      final at = center + Offset(math.cos(angle), math.sin(angle)) * ring;
      final vivo = planet == ruler;
      if (vivo) {
        canvas.drawCircle(
          at,
          side * 0.045,
          Paint()..color = accent.withValues(alpha: 0.12),
        );
      }
      // Los seis apagados en oro a 0,62: a menos se volvian invisibles y el
      // anillo dejaba de ensenar la rueda para ser adorno.
      _paintGlyph(
        canvas,
        at,
        planetGlyph[planet] ?? '✦',
        side * 0.075,
        vivo
            ? ArcanumMood.forPlanet(planet).accent
            : ArcanumColors.gold.withValues(alpha: 0.62),
      );
    }

    _paintDiamonds(canvas, center, disc);
    canvas.drawCircle(
      center,
      disc,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = ArcanumColors.gold.withValues(alpha: 0.50),
    );
  }

  /// Los cuatro rombos cardinales: lo unico que sobrevive del medallon viejo.
  /// Bastan para reconocer la marca; las 24 marcas eran lo que saturaba.
  void _paintDiamonds(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = ArcanumColors.goldLight.withValues(alpha: 0.90);
    final half = radius * 0.075;
    for (var i = 0; i < 4; i++) {
      final angle = -math.pi / 2 + i * math.pi / 2;
      final at = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final path = Path()
        ..moveTo(at.dx, at.dy - half * 1.4)
        ..lineTo(at.dx + half, at.dy)
        ..lineTo(at.dx, at.dy + half * 1.4)
        ..lineTo(at.dx - half, at.dy)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  void _paintGlyph(
    Canvas canvas,
    Offset at,
    String glyph,
    double fontSize,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(
          fontSize: fontSize,
          height: 1,
          color: color,
          fontFamilyFallback: kGlyphFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - painter.size.center(Offset.zero));
  }

  @override
  bool shouldRepaint(covariant _ChaldeanRingPainter old) =>
      old.ruler != ruler || old.accent != accent;
}

/// La escena de la hora: el dial de 24 marcas con el avance de la hora viva.
/// Reusa [PlanetaryHourDial], que ya existia y era fiel al prototipo — estaba
/// huerfano desde que el instrumento anidado se comio su sitio.
class _HourScene extends StatelessWidget {
  const _HourScene({
    required this.planet,
    required this.progress,
    required this.hourNumber,
    required this.isDay,
    required this.onTap,
  });

  final String planet;
  final double progress;
  final int hourNumber;
  final bool isDay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Hora planetaria: ${planetEs[planet] ?? planet}',
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          key: const Key('hoy-hour-target'),
          onTap: onTap,
          radius: 124,
          child: PlanetaryHourDial(
            progress: progress,
            glyph: planetGlyph[planet] ?? '✦',
            mood: ArcanumMood.forPlanet(planet),
            // El servidor numera 0..23 de corrido; el dial quiere 1..12 dentro
            // de su mitad, y la mitad la dice isDay.
            hourNumber: (hourNumber % 12) + 1,
            isDay: isDay,
            size: 248,
          ),
        ),
      ),
    );
  }
}

/// La escena de la Luna. Cerrada en el prototipo y sin cambios: mares difusos,
/// degradado de limbo y aro de oro, tal como ya la dibuja [MoonDisc].
class _MoonScene extends StatelessWidget {
  const _MoonScene({
    required this.illumination,
    required this.waxing,
    required this.phase,
    required this.onTap,
  });

  final double illumination;
  final bool waxing;
  final String phase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        button: true,
        label: 'Luna: $phase',
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            key: const Key('hoy-moon-target'),
            onTap: onTap,
            radius: 110,
            child: MoonDisc(
              illumination: illumination,
              waxing: waxing,
              size: 196,
            ),
          ),
        ),
      ),
    );
  }
}
