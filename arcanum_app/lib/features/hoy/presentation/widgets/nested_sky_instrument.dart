import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/theme/arcanum_colors.dart';
import '../../../../core/theme/arcanum_theme.dart';
import '../../../../shared/astro_symbols.dart';
import '../../../../shared/widgets/arcanum_card.dart';
import '../../../../shared/widgets/arcanum_mood.dart';
import '../../../../shared/widgets/astral_glyph_3d.dart';
import '../../../../shared/widgets/instrument_glass_surface.dart';
import '../../../../shared/widgets/moon_disc.dart';
import '../../../../shared/widgets/moon_globe.dart';
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
    required this.onMoonTap,
    required this.onConfirmPlace,
    this.ruler,
    this.hour,
    this.latitude,
    this.longitude,
    this.onRulerTap,
    this.onHourTap,
  });

  final String? ruler;
  final Map<String, dynamic>? hour;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic> moon;

  final VoidCallback? onRulerTap;
  final VoidCallback? onHourTap;
  final VoidCallback onMoonTap;
  final VoidCallback onConfirmPlace;

  @override
  State<NestedSkyInstrument> createState() => _NestedSkyInstrumentState();
}

class _NestedSkyInstrumentState extends State<NestedSkyInstrument>
    with WidgetsBindingObserver {
  /// Arranca en el regente: es la lectura mas lenta de las tres y la que da
  /// marco a las otras dos. La hora cambia sola cada ~60 min y llamaria la
  /// atencion cada vez que se abre la app.
  SkyBody _elegido = SkyBody.ruler;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startClock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startClock();
    } else {
      _clockTimer?.cancel();
      _clockTimer = null;
    }
  }

  void _startClock() {
    _clockTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _actual == SkyBody.hour) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

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
      fondo: Positioned.fill(child: InstrumentGlassSurface(radius: 18)),
      child: Column(
        children: [
          SectionLabel(
            _actual == SkyBody.hour
                ? 'INSTRUMENTO DE LA HORA'
                : 'INSTRUMENTO DEL DÍA',
          ),
          const SizedBox(height: 14),
          SizedBox.square(
            dimension: 248,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _SigilRimPainter()),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  reverseDuration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.985,
                        end: 1,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_actual),
                    child: switch (_actual) {
                      SkyBody.ruler => _RulerScene(
                        ruler: widget.ruler!,
                        onTap: widget.onRulerTap!,
                      ),
                      SkyBody.hour => _HourScene(
                        planet: _hourPlanet!,
                        progress: _hourProgress(widget.hour),
                        hourNumber:
                            (widget.hour?['hour_number'] as num?)?.toInt() ?? 0,
                        isDay: widget.hour?['is_daytime'] == true,
                        startsAt: widget.hour?['starts_at'] as String?,
                        endsAt: widget.hour?['ends_at'] as String?,
                        minutesRemaining: _minutesRemaining,
                        latitude: widget.latitude,
                        longitude: widget.longitude,
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
              emblem: _actual == SkyBody.moon
                  ? MoonDisc(
                      illumination: illumination,
                      waxing: waxing,
                      size: 28,
                    )
                  : Text(
                      planetGlyph[_planeta] ?? '✦',
                      style: TextStyle(
                        fontFamilyFallback: kGlyphFallback,
                        fontSize: 26,
                        height: 1,
                        color: mood.accent,
                      ),
                    ),
              accent: mood.accent,
            ),
          ] else ...[
            const SizedBox(height: 10),
            _Panel(
              etiqueta: 'La Luna',
              nombre: phase,
              dato: _datoLunar(illumination, age),
              accent: ArcanumMood.forPlanet('moon').accent,
              emblem: MoonDisc(
                illumination: illumination,
                waxing: waxing,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            // DOS LUGARES DISTINTOS, y hay que decir cual falta. Este es
            // donde ESTAS -- fija el amanecer y el ocaso, o sea la hora
            // planetaria -- y se guarda en el perfil. El otro es donde
            // NACISTE, que dibuja la rueda y vive en el onboarding. Decir "tu
            // lugar" a secas hacia que quien ya habia dado el de nacimiento
            // creyera que lo tenia puesto.
            Text(
              'No disponible sin saber dónde estás',
              textAlign: TextAlign.center,
              style: ArcanumText.heading(23),
            ),
            const SizedBox(height: 8),
            Text(
              'El regente y la hora dependen del amanecer y el ocaso del sitio '
              'donde estás ahora, no del de tu nacimiento. La Luna permanece '
              'porque es global.',
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
                'Añadir dónde vivo',
                style: ArcanumText.body(14, color: ArcanumColors.gold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String get _etiqueta => switch (_actual) {
    SkyBody.ruler => 'Regente del día',
    SkyBody.hour =>
      '$_ordinalHora HORA ${widget.hour?['is_daytime'] == true ? 'DIURNA' : 'NOCTURNA'}'
          ' · ${(_hourProgress(widget.hour) * 100).round()}% TRANSCURRIDO',
    SkyBody.moon => 'La Luna',
  };

  String get _ordinalHora {
    final number = ((widget.hour?['hour_number'] as num?)?.toInt() ?? 0) % 12;
    return '${number + 1}.ª';
  }

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
    final minutos = _minutesRemaining;
    final starts = DateTime.tryParse(
      (widget.hour?['starts_at'] as String?) ?? '',
    )?.toLocal();
    final ends = DateTime.tryParse(
      (widget.hour?['ends_at'] as String?) ?? '',
    )?.toLocal();
    String clock(DateTime value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

    final interval = starts != null && ends != null
        ? '${clock(starts)}–${clock(ends)}'
        : null;
    if (interval != null && minutos != null) {
      return '$interval · quedan $minutos min';
    }
    if (interval != null) return interval;
    final franja = widget.hour?['is_daytime'] == true
        ? 'Hora diurna'
        : 'Hora nocturna';
    return minutos == null ? franja : '$franja · quedan $minutos min';
  }

  int? get _minutesRemaining {
    final endsAt = DateTime.tryParse(
      (widget.hour?['ends_at'] as String?) ?? '',
    )?.toLocal();
    if (endsAt == null) {
      return (widget.hour?['minutes_remaining'] as num?)?.toInt();
    }
    return math
        .max(0, (endsAt.difference(DateTime.now()).inSeconds / 60).ceil())
        .toInt();
  }

  String _datoLunar(double illumination, double? age) =>
      '${(illumination * 100).round()}% iluminada'
      '${age == null ? '' : ' · ${age.round()} días'}';

  static double _hourProgress(Map<String, dynamic>? hour) {
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
    // Sin fronteras reales no se adivina una hora de 60 minutos: el dial
    // muestra el inicio hasta que llegue el siguiente dato astronomico.
    return 0.0;
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
          caption: 'DÍA',
          acento: ArcanumMood.forPlanet(ruler).accent,
          onTap: () => onElegir(SkyBody.ruler),
          child: Text(
            planetGlyph[ruler] ?? '✦',
            style: TextStyle(
              fontFamilyFallback: kGlyphFallback, // el glifo, no el emoji
              fontSize: 20,
              height: 1,
              color: ArcanumMood.forPlanet(ruler).accent,
            ),
          ),
        ),
        const SizedBox(width: 10),
        _Boton(
          key: const Key('hoy-selector-hour'),
          semantica: 'Hora planetaria: ${planetEs[hourPlanet] ?? hourPlanet}',
          activo: elegido == SkyBody.hour,
          caption: 'HORA',
          acento: ArcanumMood.forPlanet(hourPlanet).accent,
          onTap: () => onElegir(SkyBody.hour),
          child: Text(
            planetGlyph[hourPlanet] ?? '✦',
            style: TextStyle(
              fontFamilyFallback: kGlyphFallback, // el glifo, no el emoji
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
          caption: 'LUNA',
          acento: ArcanumMood.forPlanet('moon').accent,
          onTap: () => onElegir(SkyBody.moon),
          // El disco lunar de verdad, con su fase: es mas reconocible que un
          // glifo y ya se dibuja arriba, asi que no introduce vocabulario nuevo.
          child: MoonDisc(illumination: illumination, waxing: waxing, size: 20),
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
    required this.caption,
    required this.acento,
    required this.onTap,
    required this.child,
  });

  final String semantica;
  final bool activo;
  final String caption;
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
            width: 62,
            height: 68,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: activo
                      ? acento.withValues(alpha: 0.85)
                      : Colors.transparent,
                  width: 1.2,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ArcanumColors.background.withValues(alpha: 0.55),
                    border: Border.all(
                      color: acento.withValues(alpha: activo ? 0.78 : 0.30),
                      width: 0.8,
                    ),
                    boxShadow: activo
                        ? [
                            BoxShadow(
                              color: acento.withValues(alpha: 0.22),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(child: child),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: ArcanumText.body(
                    9,
                    color: activo ? acento : ArcanumColors.ivoryMuted,
                  ).copyWith(letterSpacing: 1.1, height: 1),
                ),
              ],
            ),
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
    this.emblem,
    this.accent = ArcanumColors.gold,
  });

  final String etiqueta;
  final String nombre;
  final String dato;
  final Widget? emblem;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (emblem != null) ...[
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.08),
              border: Border.all(color: accent.withValues(alpha: 0.55)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.10),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Center(child: emblem!),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: emblem == null
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta,
                textAlign: emblem == null ? TextAlign.center : TextAlign.start,
                style: ArcanumText.body(
                  12,
                  color: accent,
                ).copyWith(letterSpacing: 1.5),
              ),
              const SizedBox(height: 2),
              Text(
                nombre,
                textAlign: emblem == null ? TextAlign.center : TextAlign.start,
                style: ArcanumText.heading(25),
              ),
              const SizedBox(height: 3),
              Text(
                dato,
                textAlign: emblem == null ? TextAlign.center : TextAlign.start,
                style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
              ),
            ],
          ),
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
/// Aro de metal grabado compartido por las tres lecturas del instrumento.
/// Las leyendas latinas son ornamentales: no alteran ni describen el dato.
class _SigilRimPainter extends CustomPainter {
  const _SigilRimPainter();

  static const _ink = Color(0xFFC8AD70);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.474;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..shader = const SweepGradient(
          colors: [
            Color(0xFF4E3D25),
            Color(0xFFE0C780),
            Color(0xFF8D713B),
            Color(0xFFF0D99B),
            Color(0xFF4E3D25),
          ],
        ).createShader(rect),
    );
    for (final factor in [0.452, 0.435]) {
      canvas.drawCircle(
        center,
        size.shortestSide * factor,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = factor == 0.452 ? 0.8 : 0.55
          ..color = _ink.withValues(alpha: factor == 0.452 ? 0.42 : 0.22),
      );
    }

    // Los cardinales llevan marcas de sigilo; las diagonales, trazos menores.
    for (var i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + i * math.pi / 4;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final cardinal = i.isEven;
      final outer = center + direction * (size.shortestSide * 0.459);
      final inner =
          center + direction * (size.shortestSide * (cardinal ? 0.437 : 0.446));
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = _ink.withValues(alpha: cardinal ? 0.72 : 0.32)
          ..strokeWidth = cardinal ? 1.0 : 0.65,
      );
      if (cardinal) {
        _drawDiamond(canvas, outer, size.shortestSide * 0.012);
        canvas.drawCircle(
          outer,
          size.shortestSide * 0.0038,
          Paint()..color = const Color(0xFFE7D39D),
        );
      } else {
        _drawDiamond(canvas, outer, size.shortestSide * 0.007);
      }
    }
  }

  void _drawDiamond(Canvas canvas, Offset center, double radius) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius, center.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = _ink.withValues(alpha: 0.86)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
  }

  @override
  bool shouldRepaint(covariant _SigilRimPainter oldDelegate) => false;
}

class _RulerScene extends StatefulWidget {
  const _RulerScene({required this.ruler, required this.onTap});

  final String ruler;
  final VoidCallback onTap;

  @override
  State<_RulerScene> createState() => _RulerSceneState();
}

class _RulerSceneState extends State<_RulerScene>
    with TickerProviderStateMixin {
  late final AnimationController _snapController;
  late final AnimationController _satelliteController;
  Animation<double>? _snapAnimation;
  double _rotation = 0;
  double _previousPointerAngle = 0;
  Offset? _pointerOrigin;
  bool _pointerDragged = false;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _snapController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 280),
        )..addListener(() {
          setState(() => _rotation = _snapAnimation!.value);
        });
    _satelliteController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reducedMotion) {
      _satelliteController
        ..stop()
        ..value = 0;
    } else if (!_satelliteController.isAnimating) {
      _satelliteController.repeat();
    }
  }

  @override
  void dispose() {
    _snapController.dispose();
    _satelliteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = ArcanumMood.forPlanet(widget.ruler).accent;
    final actions = <CustomSemanticsAction, VoidCallback>{
      for (final planet in kChaldeanOrder)
        CustomSemanticsAction(
          label: 'Alinear ${planetEs[planet] ?? planet}',
        ): () =>
            _animatePlanetToIndex(kChaldeanOrder.indexOf(planet)),
    };
    return Semantics(
      label: 'Anillo caldeo de los siete astros',
      hint:
          'Arrastra el aro para girarlo o usa las acciones para alinear un astro bajo la aguja.',
      explicitChildNodes: true,
      customSemanticsActions: actions,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final center = Offset(
            constraints.maxWidth / 2,
            constraints.maxHeight / 2,
          );
          return Listener(
            onPointerDown: (event) {
              _pointerOrigin = event.localPosition;
              _pointerDragged = false;
            },
            onPointerMove: (event) {
              final origin = _pointerOrigin;
              if (origin != null &&
                  (event.localPosition - origin).distance > 8) {
                _pointerDragged = true;
              }
            },
            onPointerUp: (event) {
              if (!_pointerDragged) {
                _alignTouchedPlanet(
                  event.localPosition,
                  center,
                  constraints.biggest.shortestSide,
                );
              }
              _pointerOrigin = null;
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) {
                _snapController.stop();
                _previousPointerAngle = _pointerAngle(
                  details.localPosition,
                  center,
                );
              },
              onPanUpdate: (details) {
                final angle = _pointerAngle(details.localPosition, center);
                var delta = angle - _previousPointerAngle;
                if (delta > math.pi) delta -= 2 * math.pi;
                if (delta < -math.pi) delta += 2 * math.pi;
                _previousPointerAngle = angle;
                setState(() => _rotation += delta);
              },
              onPanEnd: (_) => _snapToNearestPlanet(),
              child: CustomPaint(
                painter: _ChaldeanRingPainter(
                  ruler: widget.ruler,
                  accent: accent,
                  rotation: _rotation,
                  satelliteProgress: _satelliteController,
                ),
                child: Center(
                  child: _InstrumentTarget(
                    key: const Key('hoy-ruler-target'),
                    label:
                        'Regente del día: ${planetEs[widget.ruler] ?? widget.ruler}',
                    onTap: widget.onTap,
                    child: AstralGlyph3D(
                      glyph: planetGlyph[widget.ruler] ?? '✦',
                      color: accent,
                      size: 54,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  double _pointerAngle(Offset point, Offset center) =>
      math.atan2(point.dy - center.dy, point.dx - center.dx);

  void _snapToNearestPlanet() {
    final step = 2 * math.pi / kChaldeanOrder.length;
    final topAngle = -math.pi / 2;
    var selectedIndex = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < kChaldeanOrder.length; index++) {
      final angle = topAngle + index * step + _rotation;
      final distance = _angularDistance(angle, topAngle);
      if (distance < nearestDistance) {
        selectedIndex = index;
        nearestDistance = distance;
      }
    }

    _animatePlanetToIndex(selectedIndex);
  }

  void _alignTouchedPlanet(Offset point, Offset center, double side) {
    final ring = side * _ChaldeanRingPainter._ringFraction;
    var selectedIndex = -1;
    var nearestDistance = double.infinity;
    for (var index = 0; index < kChaldeanOrder.length; index++) {
      final angle =
          -math.pi / 2 +
          index * 2 * math.pi / kChaldeanOrder.length +
          _rotation;
      final at = center + Offset(math.cos(angle), math.sin(angle)) * ring;
      final distance = (point - at).distance;
      if (distance < nearestDistance) {
        selectedIndex = index;
        nearestDistance = distance;
      }
    }
    if (nearestDistance <= 26) _animatePlanetToIndex(selectedIndex);
  }

  void _animatePlanetToIndex(int index) {
    final step = 2 * math.pi / kChaldeanOrder.length;
    final target = -index * step;
    final delta = _wrapAngle(target - _rotation);
    if (_reducedMotion) {
      setState(() => _rotation = target);
      return;
    }
    _snapAnimation = Tween<double>(begin: _rotation, end: _rotation + delta)
        .animate(
          CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
        );
    _snapController
      ..reset()
      ..forward().whenComplete(() {
        if (!mounted) return;
        setState(() => _rotation = _wrapAngle(_rotation));
      });
  }

  double _angularDistance(double first, double second) =>
      _wrapAngle(first - second).abs();

  double _wrapAngle(double angle) =>
      (angle + math.pi) % (2 * math.pi) - math.pi;
}

class _ChaldeanRingPainter extends CustomPainter {
  const _ChaldeanRingPainter({
    required this.ruler,
    required this.accent,
    required this.rotation,
    required this.satelliteProgress,
  }) : super(repaint: satelliteProgress);

  final String ruler;
  final Color accent;
  final double rotation;
  final Animation<double> satelliteProgress;

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
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = ArcanumColors.gold.withValues(alpha: 0.28);
    final orbitStep = 2 * math.pi / kChaldeanOrder.length;
    final glyphClearance = math.atan2(side * (0.075 * 0.62 + 0.015), ring);
    final ringBounds = Rect.fromCircle(center: center, radius: ring);

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
      );

    // El aro se abre alrededor de cada glifo y rota con la rueda.
    for (var i = 0; i < kChaldeanOrder.length; i++) {
      final symbolAngle = -math.pi / 2 + i * orbitStep + rotation;
      canvas.drawArc(
        ringBounds,
        symbolAngle + glyphClearance,
        orbitStep - glyphClearance * 2,
        false,
        ringPaint,
      );
    }

    for (var i = 0; i < kChaldeanOrder.length; i++) {
      final planet = kChaldeanOrder[i];
      final angle = -math.pi / 2 + i * orbitStep + rotation;
      final at = center + Offset(math.cos(angle), math.sin(angle)) * ring;
      final vivo = planet == ruler;
      if (vivo) {
        canvas.drawCircle(
          at,
          side * 0.045,
          Paint()..color = accent.withValues(alpha: 0.12),
        );
        _paintOrbitalAccent(canvas, at, side, satelliteProgress.value);
      }
      // Cada cuerpo conserva su propio color. El regente se distingue por el
      // satelite orbital; los otros seis no reciben halo.
      _paintGlyph(
        canvas,
        at,
        planetGlyph[planet] ?? '✦',
        side * 0.075,
        ArcanumMood.forPlanet(planet).accent.withValues(alpha: vivo ? 1 : 0.78),
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

  void _paintOrbitalAccent(
    Canvas canvas,
    Offset at,
    double side,
    double progress,
  ) {
    final orbitRadius = side * 0.045;
    final bounds = Rect.fromCircle(center: at, radius: orbitRadius);
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = accent.withValues(alpha: 0.72);
    const start = -math.pi * 0.72;
    const sweep = math.pi * 1.16;
    canvas.drawArc(bounds, start, sweep, false, orbitPaint);
    final satelliteAngle = start + sweep * progress;
    final satellite =
        at +
        Offset(math.cos(satelliteAngle), math.sin(satelliteAngle)) *
            orbitRadius;
    canvas.drawCircle(
      satellite,
      side * 0.009,
      Paint()..color = ArcanumMood.forPlanet(ruler).accent,
    );
    canvas.drawCircle(
      satellite,
      side * 0.017,
      Paint()..color = accent.withValues(alpha: 0.14),
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
      old.ruler != ruler || old.accent != accent || old.rotation != rotation;
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
    required this.startsAt,
    required this.endsAt,
    required this.minutesRemaining,
    required this.latitude,
    required this.longitude,
    required this.onTap,
  });

  final String planet;
  final double progress;
  final int hourNumber;
  final bool isDay;
  final String? startsAt;
  final String? endsAt;
  final int? minutesRemaining;
  final double? latitude;
  final double? longitude;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Hora planetaria: ${planetEs[planet] ?? planet}',
      onTap: onTap,
      hint:
          'Toca el aro diurno o nocturno para entender el ciclo. '
          'Toca la joya para leer el avance; el centro abre la lectura.',
      customSemanticsActions: {
        CustomSemanticsAction(label: 'Explicar las horas diurnas'): () =>
            _explain(context, PlanetaryHourInfo.daytime),
        CustomSemanticsAction(label: 'Explicar las horas nocturnas'): () =>
            _explain(context, PlanetaryHourInfo.nighttime),
        CustomSemanticsAction(label: 'Explicar el avance de la hora'): () =>
            _explain(context, PlanetaryHourInfo.progress),
      },
      child: PlanetaryHourDial(
        key: const Key('hoy-hour-target'),
        progress: progress,
        glyph: planetGlyph[planet] ?? '✦',
        mood: ArcanumMood.forPlanet(planet),
        // La API numera 0..23; el dial muestra 1..12 en la mitad correcta.
        hourNumber: (hourNumber % 12) + 1,
        isDay: isDay,
        onTapCenter: onTap,
        onExplain: (info) => _explain(context, info),
        latitude: latitude,
        longitude: longitude,
        size: 248,
      ),
    );
  }

  void _explain(BuildContext context, PlanetaryHourInfo info) {
    final ordinal = (hourNumber % 12) + 1;
    final start = DateTime.tryParse(startsAt ?? '')?.toLocal();
    final end = DateTime.tryParse(endsAt ?? '')?.toLocal();
    String time(DateTime value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    final interval = start != null && end != null
        ? '${time(start)}–${time(end)}'
        : null;
    final title = switch (info) {
      PlanetaryHourInfo.daytime => 'Las doce horas diurnas',
      PlanetaryHourInfo.nighttime => 'Las doce horas nocturnas',
      PlanetaryHourInfo.progress => 'Avance de la hora planetaria',
    };
    final explanation = switch (info) {
      PlanetaryHourInfo.daytime =>
        'Van del orto al ocaso y se dividen en doce partes. Cada hora dura '
            'una doceava parte de ese tramo; por eso no siempre equivale a '
            'sesenta minutos.',
      PlanetaryHourInfo.nighttime =>
        'Van del ocaso al siguiente orto y también se dividen en doce partes. '
            'El nuevo día planetario empieza al amanecer. Las 00:00 pertenecen '
            'al reloj civil; no marcan el inicio del ciclo planetario.',
      PlanetaryHourInfo.progress =>
        'La joya marca cuánto ha transcurrido de la hora actual: '
            '${(progress * 100).round()}%. '
            '${interval == null ? '' : 'La hora $ordinal va de $interval. '}'
            '${minutesRemaining == null ? '' : 'Quedan $minutesRemaining min. '}'
            'Su duración depende del tiempo entre orto y ocaso locales.',
    };

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ArcanumColors.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: ArcanumColors.ivory,
                  fontFamily: 'Cormorant Garamond',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                explanation,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: ArcanumColors.ivoryMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La fase permanece fija; el gesto rota solo la superficie de la esfera.
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
      child: MoonGlobe(
        key: const Key('hoy-moon-target'),
        illumination: illumination,
        waxing: waxing,
        phase: phase,
        onTap: onTap,
        size: 196,
      ),
    );
  }
}
