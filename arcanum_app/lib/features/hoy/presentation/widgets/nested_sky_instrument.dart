import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/arcanum_colors.dart';
import '../../../../core/theme/arcanum_theme.dart';
import '../../../../shared/astro_symbols.dart';
import '../../../../shared/widgets/arcanum_card.dart';
import '../../../../shared/widgets/arcanum_mood.dart';
import '../../../../shared/widgets/moon_disc.dart';
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
/// Los glifos del aro SIGUEN abriendo su hoja de lore al tocarlos. Son dos
/// gestos distintos y no redundantes: el selector CAMBIA lo que se lee aqui, el
/// glifo LLEVA a otra pantalla. Ver la regla "si se toca, abre".
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
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _InstrumentPainter(
                      hourProgress: _hourProgress(
                        widget.hour,
                        (widget.hour?['minutes_remaining'] as num?)?.toInt(),
                      ),
                      illumination: illumination,
                      hasPlace: _hasPlace,
                    ),
                  ),
                ),
                if (widget.ruler != null)
                  Positioned(
                    top: 0,
                    left: 100,
                    child: _InstrumentTarget(
                      key: const Key('hoy-ruler-target'),
                      label:
                          'Regente del día: '
                          '${planetEs[widget.ruler] ?? widget.ruler}',
                      onTap: widget.onRulerTap!,
                      child: Text(
                        planetGlyph[widget.ruler] ?? '✦',
                        style: TextStyle(
                          fontSize: 27,
                          height: 1,
                          color: mood.accent,
                        ),
                      ),
                    ),
                  ),
                if (_hourPlanet != null)
                  _InstrumentTarget(
                    key: const Key('hoy-hour-target'),
                    label:
                        'Hora planetaria: '
                        '${planetEs[_hourPlanet] ?? _hourPlanet}',
                    onTap: widget.onHourTap!,
                    child: Text(
                      planetGlyph[_hourPlanet] ?? '✦',
                      style: TextStyle(
                        fontSize: 42,
                        height: 1,
                        color: ArcanumMood.forPlanet(_hourPlanet!).accent,
                      ),
                    ),
                  ),
                Positioned(
                  top: 38,
                  right: 21,
                  child: _InstrumentTarget(
                    key: const Key('hoy-moon-target'),
                    label: 'Luna: $phase',
                    onTap: widget.onMoonTap,
                    child: MoonDisc(
                      illumination: illumination,
                      waxing: waxing,
                      size: 36,
                    ),
                  ),
                ),
              ],
            ),
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

class _InstrumentPainter extends CustomPainter {
  const _InstrumentPainter({
    required this.hourProgress,
    required this.illumination,
    required this.hasPlace,
  });

  final double hourProgress;
  final double illumination;
  final bool hasPlace;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.shortestSide * 0.44;
    final hourRadius = size.shortestSide * 0.31;
    final moonRadius = size.shortestSide * 0.20;
    final faint = Paint()
      ..color = ArcanumColors.goldMuted.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas
      ..drawCircle(center, outerRadius, faint)
      ..drawCircle(center, hourRadius, faint)
      ..drawCircle(center, moonRadius, faint);

    for (var i = 0; i < 24; i++) {
      final angle = i * math.pi / 12 - math.pi / 2;
      final length = i % 6 == 0 ? 13.0 : 7.0;
      final start =
          center + Offset(math.cos(angle), math.sin(angle)) * outerRadius;
      final end =
          center +
          Offset(math.cos(angle), math.sin(angle)) * (outerRadius - length);
      canvas.drawLine(start, end, faint);
    }

    if (hasPlace) {
      final hourPaint = Paint()
        ..color = ArcanumColors.moonAccent.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: hourRadius),
        -math.pi / 2,
        math.pi * 2 * hourProgress,
        false,
        hourPaint,
      );
    }

    final moonPaint = Paint()
      ..color = ArcanumColors.ivory.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: moonRadius),
      -math.pi / 2,
      math.pi * 2 * illumination,
      false,
      moonPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _InstrumentPainter oldDelegate) {
    return hourProgress != oldDelegate.hourProgress ||
        illumination != oldDelegate.illumination ||
        hasPlace != oldDelegate.hasPlace;
  }
}
