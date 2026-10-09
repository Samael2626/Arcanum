import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../../core/theme/arcanum_colors.dart';
import '../../../../core/theme/arcanum_theme.dart';
import '../../../../shared/astro_symbols.dart';
import '../../../../shared/widgets/moon_disc.dart';
import 'reliquary_fx.dart';
import 'zodiaco_laminas.g.dart';

/// Portada «Atlas de reliquias» (propuesta E, Samuel 08-oct): el cielo vivo
/// arriba, la Mesa como puerta grande y las demas placas agrupadas por ritmo.
/// Especificacion: `prototipos/comparador_portada_viva.html`, columna E, con
/// «Vidrio selectivo», «Con vida» y «Ritual».
///
/// VIDRIO SELECTIVO, Y SU COSTE
///   Solo dos placas llevan `BackdropFilter`: el cielo vivo (sigma 14) y la
///   Mesa (sigma 10), las dos que el prototipo desenfoca. Las de lectura son
///   resina estable. Cada desenfoque es una capa que se recompone en cada
///   fotograma en que algo se mueve (scroll o destello), recortada a su placa.
///   Dos, y no siete: el coste queda acotado y medible.
///
/// MOVIMIENTO
///   Un solo ticker ([ReliquaryClock]) para aurora, orbe y destellos; cada
///   efecto en su propia capa de repintado. Con `disableAnimations` no hay
///   ticker ni destellos.
class AtlasHomePanel extends StatelessWidget {
  const AtlasHomePanel({
    super.key,
    required this.moon,
    required this.observedAt,
    required this.onMoonTap,
    required this.onHoroscope,
    required this.onGrimoire,
    required this.onSaber,
    required this.onTable,
    required this.onOracle,
    required this.onSigil,
    required this.onBreathe,
    this.dayRuler,
    this.hour,
    this.onChart,
    this.onToday,
    this.tableCard,
    this.showTable = false,
    this.horoscopeKey,
    this.chartKey,
  });

  final Map<String, dynamic> moon;
  final DateTime observedAt;

  /// Regente del dia y hora planetaria reales; ausentes sin lugar confirmado.
  final String? dayRuler;
  final Map<String, dynamic>? hour;

  final VoidCallback onMoonTap;
  final VoidCallback onHoroscope;
  final VoidCallback onGrimoire;
  final VoidCallback onSaber;
  final VoidCallback onTable;
  final VoidCallback onOracle;

  /// «+ Sigilo» en la placa del Grimorio: abre el taller de letras (Samuel,
  /// 07-oct, opcion B). Los sigilos se guardan en el Grimorio.
  final VoidCallback onSigil;

  /// «Respirar» en el cielo vivo: abre el motor de respiracion (07-oct).
  final VoidCallback onBreathe;

  /// «Tu carta»: la otra cara de Cielo. Sin conmutador arriba (E no lo
  /// lleva), la entrada vive aqui, junto a «Respirar».
  final VoidCallback? onChart;

  /// «Hoy →» del titulo: baja al instrumento del dia.
  final VoidCallback? onToday;

  /// Slug de la primera carta de la ultima tirada guardada, si la hay.
  final String? tableCard;

  /// La placa de la mesa se SUMA a la del Oraculo, no la sustituye: quitarla
  /// dejaba el Oraculo sin entrada.
  final bool showTable;
  final Key? horoscopeKey;

  /// Clave del Sendero para «Tu carta» (`cielo_toggle`).
  final Key? chartKey;

  /// Carta de la Mesa sin tirada guardada: la misma del prototipo.
  static const fallbackTableCard = 'la-luna';

  /// La del Oraculo, y la de reserva si la ultima tirada fue justo esa: dos
  /// placas nunca ensenan la misma carta.
  static const oracleCard = 'el-mago';
  static const oracleCardAlt = 'la-sacerdotisa';

  @override
  Widget build(BuildContext context) {
    final tableSlug = tableCard ?? fallbackTableCard;
    final oracleSlug = tableSlug == oracleCard ? oracleCardAlt : oracleCard;
    final isDay = hour?['is_daytime'] as bool? ?? true;
    final heroSign = reliquarySign(dayRuler, isDay: isDay);
    final horoscopeSign = reliquarySign(
      hour?['planet'] as String? ?? dayRuler,
      isDay: isDay,
      avoid: heroSign,
    );

    final oracle = _Plate(
      key: const Key('atlas-oraculo'),
      title: 'Oráculo',
      subtitle: 'Pregunta o estudia',
      semantics: 'Abrir Oráculo. Pregunta o estudia el tarot',
      mark: ReliquaryMark.star,
      onTap: onOracle,
      minHeight: showTable ? 108 : 183,
      art: showTable
          ? const _ArtSpec(width: 66, height: 100, right: -8, bottom: -38)
          : const _ArtSpec.table(),
      alignment: showTable
          ? AlignmentDirectional.topStart
          : AlignmentDirectional.centerStart,
      titleClearsArt: showTable,
      artAsset: 'assets/tarot/$oracleSlug.webp',
      titleSize: showTable ? 25 : 36,
      padding: showTable ? null : const EdgeInsets.fromLTRB(25, 29, 25, 29),
      gradient: showTable ? _Tone.tile : _Tone.table,
      glass: !showTable,
      glint: !showTable,
    );

    return ReliquaryClock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SkyHero(
            moon: moon,
            observedAt: observedAt,
            hour: hour,
            sign: heroSign,
            onTap: onMoonTap,
            onBreathe: onBreathe,
            onChart: onChart,
            chartKey: chartKey,
          ),
          const SizedBox(height: 31),
          _SectionTitle(onToday: onToday),
          const SizedBox(height: 17),
          if (showTable) ...[
            _Plate(
              key: const Key('atlas-mesa'),
              title: 'Mesa de tarot',
              subtitle: tableCard == null
                  ? 'Baraja, tira y desvela con tus manos'
                  : 'Tu última tirada te espera',
              semantics: 'Abrir la mesa de tarot',
              mark: ReliquaryMark.sparkle,
              onTap: onTable,
              minHeight: 183,
              art: const _ArtSpec.table(),
              artAsset: 'assets/tarot/$tableSlug.webp',
              fallbackAsset: 'assets/tarot/$fallbackTableCard.webp',
              titleSize: 36,
              subtitleWidth: 140,
              padding: const EdgeInsets.fromLTRB(25, 29, 25, 29),
              gradient: _Tone.table,
              glass: true,
              glint: true,
            ),
          ] else
            oracle,
          const SizedBox(height: 15),
          _Plate(
            key: horoscopeKey ?? const Key('atlas-horoscopo'),
            title: 'Horóscopo',
            subtitle: 'Tu cielo de hoy',
            semantics: 'Abrir Horóscopo. Tu cielo de hoy, sobre tu carta',
            mark: ReliquaryMark.crescent,
            onTap: onHoroscope,
            minHeight: 85,
            art: const _ArtSpec(width: 90, height: 132, right: -8, bottom: -25),
            artAsset: laminasDelZodiaco[horoscopeSign]!.asset,
            gradient: _Tone.tile,
          ),
          const SizedBox(height: 15),
          _LowerRow(
            showTable: showTable,
            grimoire: (stretch) => _Plate(
              key: const Key('atlas-grimorio'),
              title: 'Grimorio',
              subtitle: 'Escribe y guarda',
              semantics: 'Escribir en el Grimorio, tu diario cifrado',
              mark: ReliquaryMark.quill,
              onTap: onGrimoire,
              minHeight: stretch ? 231 : 108,
              padding: EdgeInsets.fromLTRB(15, stretch ? 152 : 15, 15, 7),
              // apilado no hay alto para la pagina: solo el texto
              art: stretch ? const _ArtSpec.page() : null,
              artAsset: 'assets/materia/grabado/verbena.webp',
              alignment: stretch
                  ? AlignmentDirectional.bottomStart
                  : AlignmentDirectional.centerStart,
              gradient: _Tone.tile,
              extra: _ReliquaryAction(
                key: const Key('atlas-sigilo'),
                text: '+ Sigilo',
                semantics: 'Crear un sigilo de letras',
                onTap: onSigil,
              ),
            ),
            saber: _Plate(
              key: const Key('atlas-saber'),
              title: 'Saber',
              subtitle: 'Plantas y libros',
              semantics: 'Explorar Saber. Plantas y libros',
              mark: ReliquaryMark.asterisk,
              onTap: onSaber,
              minHeight: 108,
              gradient: _Tone.tile,
            ),
            oracle: showTable ? oracle : null,
          ),
        ],
      ),
    );
  }
}

/// El signo cuya lamina acompana a un planeta: su domicilio segun la secta
/// (diurno de dia, nocturno de noche). Sol y Luna tienen uno; si chocan con
/// [avoid], su exaltacion. Sin planeta, la casa de la Luna.
Signo reliquarySign(String? planet, {required bool isDay, Signo? avoid}) {
  const day = {
    'sun': Signo.leo,
    'moon': Signo.cancer,
    'mercury': Signo.geminis,
    'venus': Signo.libra,
    'mars': Signo.aries,
    'jupiter': Signo.sagitario,
    'saturn': Signo.acuario,
  };
  const night = {
    'sun': Signo.leo,
    'moon': Signo.cancer,
    'mercury': Signo.virgo,
    'venus': Signo.tauro,
    'mars': Signo.escorpio,
    'jupiter': Signo.piscis,
    'saturn': Signo.capricornio,
  };
  const exalted = {'sun': Signo.aries, 'moon': Signo.tauro};
  final p = day.containsKey(planet) ? planet! : 'moon';
  final first = (isDay ? day : night)[p]!;
  if (first != avoid) return first;
  final other = (isDay ? night : day)[p]!;
  return other != avoid ? other : exalted[p]!;
}

/// Dia de la semana del instante consultado, en versalitas.
const _weekdays = [
  'LUNES',
  'MARTES',
  'MIÉRCOLES',
  'JUEVES',
  'VIERNES',
  'SÁBADO',
  'DOMINGO',
];

String _hourLabel(String planet) => switch (planet) {
  'sun' => 'HORA DEL SOL',
  'moon' => 'HORA DE LA LUNA',
  _ => 'HORA DE ${(planetEs[planet] ?? planet).toUpperCase()}',
};

// ── Cielo vivo ──────────────────────────────────────────────────────────

class _SkyHero extends StatelessWidget {
  const _SkyHero({
    required this.moon,
    required this.observedAt,
    required this.hour,
    required this.sign,
    required this.onTap,
    required this.onBreathe,
    required this.onChart,
    required this.chartKey,
  });

  final Map<String, dynamic> moon;
  final DateTime observedAt;
  final Map<String, dynamic>? hour;
  final Signo sign;
  final VoidCallback onTap;
  final VoidCallback onBreathe;
  final VoidCallback? onChart;
  final Key? chartKey;

  static const _orb = 76.0;
  static const _radius = BorderRadius.only(topRight: Radius.circular(20));

  @override
  Widget build(BuildContext context) {
    final illumination = (moon['illumination'] as num).toDouble();
    final waxing = moon['is_waxing'] as bool;
    final phase = moon['phase_name'] as String;
    final percent = (illumination * 100).round();
    final planet = hour?['planet'] as String?;
    final label = [
      _weekdays[observedAt.weekday - 1],
      if (planet != null) _hourLabel(planet),
    ].join(' · ');

    return LayoutBuilder(
      builder: (context, box) {
        // el texto nunca entra bajo el orbe
        final textRoom = box.maxWidth - 21 - 18 - _orb - 12;
        return Container(
          key: const Key('atlas-cielo'),
          decoration: const BoxDecoration(
            borderRadius: _radius,
            boxShadow: [
              BoxShadow(
                color: Color(0x88000000),
                blurRadius: 35,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: _radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Semantics(
                button: true,
                label: 'Explorar la Luna. $phase, $percent % iluminada',
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: onTap,
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: _Tone.hero.gradient,
                        border: Border(
                          top: BorderSide(
                            color: ArcanumColors.ivory.withValues(alpha: .33),
                          ),
                        ),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 177),
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: IgnorePointer(child: ReliquaryAurora()),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: _Engraving(
                                  asset: laminasDelZodiaco[sign]!.asset,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 18,
                              bottom: 16,
                              child: ExcludeSemantics(
                                child: ReliquaryOrb(
                                  size: _orb,
                                  child: MoonDisc(
                                    illumination: illumination,
                                    waxing: waxing,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                21,
                                19,
                                21,
                                16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ExcludeSemantics(
                                    child: Text(
                                      label,
                                      style: ArcanumText.label().copyWith(
                                        fontSize: 11,
                                        letterSpacing: 2.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      // con letra grande el ancho crece con ella: nunca se parte
                                      // una palabra
                                      maxWidth: math.min(
                                        box.maxWidth - 42,
                                        MediaQuery.textScalerOf(
                                          context,
                                        ).scale(230),
                                      ),
                                    ),
                                    child: Text(
                                      'Tu cielo\nestá en movimiento',
                                      style: ArcanumText.heading(
                                        32,
                                      ).copyWith(height: .97),
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: math.min(215, textRoom),
                                    ),
                                    child: Text(
                                      // la fase real va delante: es el unico sitio de la portada
                                      // donde se lee con su nombre
                                      '$phase: la Luna '
                                      '${waxing ? 'crece' : 'mengua'}. Toca '
                                      'el instrumento para mirar más cerca.',
                                      style: ArcanumText.body(
                                        14,
                                        color: ArcanumColors.ivoryMuted,
                                      ).copyWith(height: 1.28),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: math.max(120, textRoom),
                                    child: Wrap(
                                      spacing: 8,
                                      children: [
                                        _ReliquaryAction(
                                          key: const Key('atlas-respirar'),
                                          text: 'Respirar',
                                          semantics:
                                              'Abrir la práctica de respiración',
                                          onTap: onBreathe,
                                        ),
                                        if (onChart != null)
                                          KeyedSubtree(
                                            key: chartKey,
                                            child: _ReliquaryAction(
                                              key: const Key('atlas-tu-carta'),
                                              text: 'Tu carta',
                                              semantics:
                                                  'Ver tu carta natal y lo que '
                                                  'hoy la toca',
                                              onTap: onChart!,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Grabado de fondo del cielo vivo: media placa a la derecha, desaturado y
/// a un cuarto de luz, como el `::after` del prototipo.
class _Engraving extends StatelessWidget {
  const _Engraving({required this.asset});

  final String asset;

  // la lamina cubre toda la mitad derecha, de arriba abajo: con la placa mas
  // alta (letra grande, 360 dp) no deja un canto cortado a media altura
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: FractionallySizedBox(
      widthFactor: .5,
      heightFactor: 1,
      child: ColorFiltered(
        colorFilter: reliquaryTone(saturation: .65, alpha: .26),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -.56),
          cacheWidth: 600,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    ),
  );
}

// ── Titulo de seccion ───────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.onToday});

  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text('Elige tu práctica', style: ArcanumText.heading(25)),
          ),
        ),
        if (onToday != null)
          Semantics(
            button: true,
            label: 'Bajar al instrumento de hoy',
            excludeSemantics: true,
            child: InkWell(
              key: const Key('atlas-hoy'),
              onTap: onToday,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Hoy',
                      style: ArcanumText.body(
                        14,
                        color: ArcanumColors.goldLabel,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: ArcanumColors.goldLabel,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

// ── Placas ──────────────────────────────────────────────────────────────

/// Gradientes de las placas, con los angulos CSS del prototipo.
enum _Tone {
  hero(
    ArcanumColors.reliquaryHeroTop,
    ArcanumColors.reliquaryHeroBottom,
    145,
    .8,
  ),
  tile(
    ArcanumColors.reliquaryTileTop,
    ArcanumColors.reliquaryTileBottom,
    160,
    .8,
  ),
  table(
    ArcanumColors.reliquaryTableTop,
    ArcanumColors.reliquaryTableBottom,
    130,
    .76,
  );

  const _Tone(this.from, this.to, this.degrees, this.stop);
  final Color from;
  final Color to;
  final double degrees;
  final double stop;

  LinearGradient get gradient {
    final a = degrees * math.pi / 180;
    final dir = Alignment(math.sin(a), -math.cos(a));
    return LinearGradient(
      begin: -dir,
      end: dir,
      colors: [from, to],
      stops: [0, stop],
    );
  }
}

/// Donde cae el arte de una placa, en dp desde su esquina inferior derecha.
class _ArtSpec {
  const _ArtSpec({
    required this.width,
    required this.height,
    required this.right,
    required this.bottom,
  }) : degrees = 8,
       opacity = .78,
       saturation = .65,
       top = null;

  /// Una lamina como pagina suelta del libro: arriba a la derecha, sobre el
  /// titulo, que va abajo. Verbena: la Clavicula de Salomon la pide para
  /// consagrar pluma, tinta y libro.
  const _ArtSpec.page()
    : width = 80,
      height = 122,
      right = 44,
      bottom = 0,
      top = 18,
      degrees = -6,
      opacity = .62,
      saturation = .45;

  /// La carta de la Mesa: inclinada a la izquierda y a plena luz.
  const _ArtSpec.table()
    : width = 112,
      height = 167,
      right = 29,
      bottom = -23,
      degrees = -9,
      opacity = 1,
      saturation = .8,
      top = null;

  final double width;
  final double height;
  final double right;
  final double bottom;
  final double degrees;
  final double opacity;
  final double saturation;

  /// Si va anclado arriba, en dp desde el borde superior (y no abajo).
  final double? top;

  /// Ancho que el arte ocupa de verdad desde el borde derecho, girado sobre
  /// su centro.
  double get footprint {
    final a = degrees.abs() * math.pi / 180;
    return right + width / 2 + (width * math.cos(a) + height * math.sin(a)) / 2;
  }
}

class _Plate extends StatelessWidget {
  const _Plate({
    super.key,
    required this.title,
    required this.subtitle,
    required this.semantics,
    required this.mark,
    required this.onTap,
    required this.minHeight,
    required this.gradient,
    this.art,
    this.artAsset,
    this.fallbackAsset,
    this.titleSize = 25,
    this.subtitleWidth,
    this.padding,
    this.glass = false,
    this.glint = false,
    this.alignment = AlignmentDirectional.centerStart,
    this.titleClearsArt = false,
    this.extra,
  });

  final String title;
  final String subtitle;
  final String semantics;
  final ReliquaryMark mark;
  final VoidCallback onTap;
  final double minHeight;
  final _Tone gradient;
  final _ArtSpec? art;
  final String? artAsset;
  final String? fallbackAsset;
  final double titleSize;
  final double? subtitleWidth;
  final EdgeInsets? padding;
  final bool glass;
  final bool glint;

  /// Donde se asienta el texto en la placa: al centro (como el boton del
  /// prototipo), arriba si el arte ocupa la esquina de abajo, o abajo en la
  /// placa alta del Grimorio.
  final AlignmentDirectional alignment;

  /// El arte vive por debajo del titulo: el titulo usa todo el ancho y solo
  /// el subtitulo se aparta de la carta.
  final bool titleClearsArt;
  final Widget? extra;

  static const _radius = BorderRadius.all(Radius.circular(2));

  @override
  Widget build(BuildContext context) {
    final pad = padding ?? const EdgeInsets.all(15);
    final spec = art;
    // el texto se para antes de la carta: nada se monta sobre el arte
    final artRoom = spec == null || artAsset == null || spec.top != null
        ? 0.0
        : spec.footprint + 6;
    // la marca de la esquina tampoco se pisa
    final markRoom = pad.right + 26;
    final titleRight = titleClearsArt ? markRoom : math.max(markRoom, artRoom);
    final subtitleRight = math.max(pad.right, artRoom);

    Widget body = Ink(
      decoration: BoxDecoration(
        gradient: gradient.gradient,
        border: Border(
          top: BorderSide(
            color: glass
                ? ArcanumColors.ivory.withValues(alpha: .4)
                : ArcanumColors.gold.withValues(alpha: .27),
          ),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Stack(
          alignment: alignment,
          children: [
            Positioned(
              right: 13,
              top: 13,
              child: ExcludeSemantics(child: mark.draw()),
            ),
            if (spec != null && artAsset != null)
              Positioned(
                right: spec.right,
                top: spec.top,
                bottom: spec.top == null ? spec.bottom : null,
                child: ExcludeSemantics(
                  child: _CardArt(
                    spec: spec,
                    asset: artAsset!,
                    fallback: fallbackAsset,
                  ),
                ),
              ),
            if (glint) const Positioned.fill(child: ReliquaryGlint()),
            Padding(
              padding: pad.copyWith(right: 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(right: titleRight),
                          child: Text(
                            title,
                            style: ArcanumText.heading(
                              titleSize,
                            ).copyWith(height: 1),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: EdgeInsets.only(right: subtitleRight),
                          constraints: BoxConstraints(
                            maxWidth:
                                (subtitleWidth ?? double.infinity) +
                                subtitleRight,
                          ),
                          child: Text(
                            subtitle,
                            style: ArcanumText.body(
                              14,
                              color: ArcanumColors.ivoryMuted,
                            ).copyWith(height: 1.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // la accion propia sigue al texto, con su mismo margen
                  if (extra != null) ...[const SizedBox(height: 6), extra!],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    body = Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, child: body),
    );
    if (glass) {
      body = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: body,
      );
    }

    return Semantics(
      button: true,
      label: semantics,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: _radius,
          boxShadow: [
            BoxShadow(
              color: Color(glass ? 0x99000000 : 0x77000000),
              blurRadius: glass ? 36 : 25,
              offset: Offset(0, glass ? 15 : 12),
            ),
          ],
        ),
        child: ClipRRect(borderRadius: _radius, child: body),
      ),
    );
  }
}

class _CardArt extends StatelessWidget {
  const _CardArt({required this.spec, required this.asset, this.fallback});

  final _ArtSpec spec;
  final String asset;
  final String? fallback;

  @override
  Widget build(BuildContext context) {
    Widget image(String path, {Widget? onError}) => Image.asset(
      path,
      width: spec.width,
      height: spec.height,
      fit: BoxFit.cover,
      cacheWidth: (spec.width * 3).round(),
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => onError ?? const SizedBox.shrink(),
    );
    return Transform.rotate(
      angle: spec.degrees * math.pi / 180,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0x77000000),
              blurRadius: 18,
              offset: Offset(-5, 0),
            ),
          ],
        ),
        child: ColorFiltered(
          colorFilter: reliquaryTone(
            saturation: spec.saturation,
            alpha: spec.opacity,
          ),
          // un slug guardado que no tenga lamina cae en la carta fija
          child: image(
            asset,
            onError: fallback == null ? null : image(fallback!),
          ),
        ),
      ),
    );
  }
}

/// Grimorio a la izquierda, alto; Saber y Oraculo apilados a la derecha.
/// Sin Mesa (el Oraculo sube a placa grande), Grimorio y Saber a la par. Muy
/// estrecho o con letra grande, todo en columna.
class _LowerRow extends StatelessWidget {
  const _LowerRow({
    required this.showTable,
    required this.grimoire,
    required this.saber,
    required this.oracle,
  });

  final bool showTable;
  final Widget Function(bool stretch) grimoire;
  final Widget saber;
  final Widget? oracle;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final stacked =
          box.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.35;
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            grimoire(false),
            const SizedBox(height: 15),
            saber,
            if (oracle != null) ...[const SizedBox(height: 15), oracle!],
          ],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 115, child: grimoire(oracle != null)),
            const SizedBox(width: 12),
            Expanded(
              flex: 85,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: saber),
                  if (oracle != null) ...[
                    const SizedBox(height: 15),
                    Expanded(child: oracle!),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Accion secundaria de una placa: boton fantasma del prototipo (filete de
/// oro viejo, oro claro), con 48 dp de zona tactil y su propia etiqueta.
class _ReliquaryAction extends StatelessWidget {
  const _ReliquaryAction({
    super.key,
    required this.text,
    required this.semantics,
    required this.onTap,
  });

  final String text;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semantics,
    excludeSemantics: true,
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: ArcanumColors.background.withValues(alpha: .35),
                border: Border.all(color: ArcanumColors.goldMuted),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                text,
                style: ArcanumText.body(14, color: ArcanumColors.goldLight),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
