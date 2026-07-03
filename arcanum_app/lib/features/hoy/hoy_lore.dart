import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/astro_symbols.dart';
import '../../shared/widgets/arcanum_mood.dart';
import '../../shared/widgets/arcanum_surface.dart';

/// Lore esotérico de un planeta clásico (correspondencias de Agrippa / Golden
/// Dawn) para las hojas de detalle de la pantalla Hoy.
class PlanetLore {
  final String dia;
  final String metal;
  final String sephirah;
  final String descripcion;
  final List<String> correspondencias;
  const PlanetLore({
    required this.dia,
    required this.metal,
    required this.sephirah,
    required this.descripcion,
    required this.correspondencias,
  });
}

const Map<String, PlanetLore> planetLore = {
  'sun': PlanetLore(
    dia: 'Domingo',
    metal: 'Oro',
    sephirah: 'Tiphareth · la Belleza',
    descripcion:
        'El Sol es el corazón del cielo, la luz que da forma y sostiene todo '
        'cuanto vive. Agrippa lo llama fuente de la vitalidad y del honor: '
        'donde el Sol mira, hay orden, salud y reconocimiento.\n\n'
        'Sus horas favorecen los ritos de éxito visible, la autoridad legítima, '
        'la curación y la protección solar. Los talismanes solares se graban en '
        'oro al mediodía del domingo, en su propia hora, cuando su fuerza '
        'alcanza el cenit.',
    correspondencias: [
      'Metal: oro',
      'Plantas: laurel, girasol, heliotropo, azafrán',
      'Piedra: rubí, ámbar, crisólito',
      'Incienso: olíbano, mirra',
      'Favorece: éxito, vitalidad, reconocimiento, salud',
    ],
  ),
  'moon': PlanetLore(
    dia: 'Lunes',
    metal: 'Plata',
    sephirah: 'Yesod · el Fundamento',
    descripcion:
        'La Luna gobierna las mareas del cuerpo y del alma: los sueños, la '
        'memoria, las aguas y todo cuanto crece y mengua. Es el espejo que '
        'recibe la luz del Sol y la vierte sobre el mundo sublunar.\n\n'
        'Sus horas favorecen la adivinación, el trabajo con los sueños, la '
        'protección del hogar y los viajes por agua. Creciente atrae y edifica; '
        'menguante destierra y disuelve. Los talismanes se cargan en plata bajo '
        'su luz.',
    correspondencias: [
      'Metal: plata',
      'Plantas: sauce, lirio blanco, artemisa, jazmín',
      'Piedra: piedra de luna, perla, selenita',
      'Incienso: jazmín, sándalo blanco, alcanfor',
      'Favorece: sueños, psiquismo, hogar, emociones',
    ],
  ),
  'mars': PlanetLore(
    dia: 'Martes',
    metal: 'Hierro',
    sephirah: 'Geburah · el Rigor',
    descripcion:
        'Marte es la espada del cielo: el fuego que corta, defiende y rompe '
        'obstáculos. Agrippa le atribuye el coraje, la disciplina marcial y la '
        'fuerza que no vacila ante el umbral.\n\n'
        'Sus horas favorecen la protección activa, la ruptura de ataduras, el '
        'valor y el deseo. Son horas de acción inmediata, no de contemplación. '
        'Los talismanes se forjan en hierro bajo su hora, en martes.',
    correspondencias: [
      'Metal: hierro',
      'Plantas: ortiga, ajo, pimienta, cardo',
      'Piedra: rubí, granate, jaspe rojo',
      'Incienso: sangre de dragón, tabaco, pimienta',
      'Favorece: fuerza, coraje, protección, deseo',
    ],
  ),
  'mercury': PlanetLore(
    dia: 'Miércoles',
    metal: 'Azogue',
    sephirah: 'Hod · la Gloria',
    descripcion:
        'Mercurio es el mensajero entre los mundos, señor de la palabra, el '
        'número y el intercambio. Rige la mente veloz, el comercio, los pactos '
        'y los cruces de camino.\n\n'
        'Sus horas favorecen el estudio, la escritura, la elocuencia, los viajes '
        'y todo trato o negociación. Los sigilos y talismanes de comunicación se '
        'trazan en su hora, en miércoles, sobre metal claro.',
    correspondencias: [
      'Metal: azogue (mercurio), latón',
      'Plantas: lavanda, mejorana, valeriana, eneldo',
      'Piedra: ágata, ópalo, citrino',
      'Incienso: benjuí, mastic, macis',
      'Favorece: estudio, comercio, comunicación, viajes',
    ],
  ),
  'venus': PlanetLore(
    dia: 'Viernes',
    metal: 'Cobre',
    sephirah: 'Netzach · la Victoria',
    descripcion:
        'Venus es la estrella del amor y de la armonía, la que reconcilia los '
        'opuestos y engendra la belleza. Agrippa la asocia al deleite de los '
        'sentidos, al arte y a la fertilidad.\n\n'
        'Sus horas favorecen el amor, la reconciliación, la belleza y toda obra '
        'artística. Los talismanes de atracción se labran en cobre bajo su hora, '
        'en viernes, ungidos con esencias dulces.',
    correspondencias: [
      'Metal: cobre',
      'Plantas: rosa, mirto, verbena, manzana',
      'Piedra: esmeralda, cuarzo rosa, lapislázuli',
      'Incienso: rosa, sándalo, ylang-ylang',
      'Favorece: amor, belleza, arte, reconciliación',
    ],
  ),
  'jupiter': PlanetLore(
    dia: 'Jueves',
    metal: 'Estaño',
    sephirah: 'Chesed · la Misericordia',
    descripcion:
        'Júpiter es el gran benéfico, el rey que expande y concede. Tzedek, '
        'el justo: donde mira, hay abundancia, crecimiento y ley recta. Agrippa '
        'le atribuye la fortuna, el honor y la clemencia del poderoso.\n\n'
        'Sus horas favorecen la prosperidad, la expansión, los asuntos legales '
        'y la búsqueda de sabiduría. Los talismanes de abundancia se graban en '
        'estaño bajo su hora, en jueves, con la casa en ascenso.',
    correspondencias: [
      'Metal: estaño',
      'Plantas: roble, higo, salvia, bálsamo',
      'Piedra: amatista, zafiro, topacio',
      'Incienso: cedro, nuez moscada, azafrán',
      'Favorece: abundancia, expansión, suerte, justicia',
    ],
  ),
  'saturn': PlanetLore(
    dia: 'Sábado',
    metal: 'Plomo',
    sephirah: 'Binah · el Entendimiento',
    descripcion:
        'Saturno es el Anciano de los Días, guardián del tiempo, de los límites '
        'y de la muerte. Agrippa lo asocia a la disciplina severa, a lo que dura '
        'y a lo que pone fin. Su fuerza es lenta, fría y permanente.\n\n'
        'Sus horas favorecen los destierros, la protección duradera, las '
        'estructuras de largo plazo y el trabajo con los ancestros. Los '
        'talismanes se funden en plomo bajo su hora, en sábado, en tiempo frío.',
    correspondencias: [
      'Metal: plomo',
      'Plantas: ciprés, consuelda, beleño, tejo',
      'Piedra: ónix, azabache, obsidiana',
      'Incienso: mirra, benjuí, cedro oscuro',
      'Favorece: límites, disciplina, destierro, estructura',
    ],
  ),
};

/// Orden caldeo de los regentes de las horas planetarias (descendente por
/// velocidad aparente). Cada hora sucesiva pertenece al siguiente de la lista,
/// cíclicamente — así se calculan las próximas horas sin pedir nada al backend.
const List<String> _chaldean = [
  'saturn', 'jupiter', 'mars', 'sun', 'venus', 'mercury', 'moon',
];

/// Regentes de las [count] horas siguientes a [planet], en orden caldeo.
List<String> nextPlanetaryRulers(String planet, {int count = 3}) {
  final start = _chaldean.indexOf(planet.toLowerCase());
  if (start < 0) return const [];
  return List.generate(count, (i) => _chaldean[(start + 1 + i) % 7]);
}

// ── Hoja: detalle del planeta (regente del día) ───────────────────────────

void showPlanetLoreSheet(BuildContext context, String planetKey) {
  final lore = planetLore[planetKey];
  if (lore == null) return;
  final name = planetEs[planetKey] ?? planetKey;
  final glyph = planetGlyph[planetKey] ?? '✶';
  final mood = ArcanumMood.forPlanet(planetKey);

  _sheet(
    context,
    mood: mood,
    glyph: glyph,
    title: name,
    subtitle: '${lore.dia} · ${lore.metal}',
    body: (scroll) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('DÍA', lore.dia),
        const SizedBox(height: 10),
        _row('METAL', lore.metal),
        const SizedBox(height: 10),
        _row('SEPHIRAH', lore.sephirah),
        const SizedBox(height: 24),
        Text('NATURALEZA', style: ArcanumText.label()),
        const SizedBox(height: 10),
        Text(lore.descripcion,
            style: ArcanumText.body(16), textAlign: TextAlign.justify),
        const SizedBox(height: 24),
        Text('CORRESPONDENCIAS', style: ArcanumText.label()),
        const SizedBox(height: 10),
        ..._bullets(lore.correspondencias, mood),
      ],
    ),
  );
}

// ── Hoja: la hora planetaria vigente + las próximas ───────────────────────

void showPlanetaryHourSheet(BuildContext context, String planetKey,
    {required bool isDay, required int minutesRemaining}) {
  final name = planetEs[planetKey] ?? planetKey;
  final glyph = planetGlyph[planetKey] ?? '✶';
  final mood = ArcanumMood.forPlanet(planetKey);
  final favors = planetFavors[planetKey] ?? '';
  final nexts = nextPlanetaryRulers(planetKey, count: 4);

  _sheet(
    context,
    mood: mood,
    glyph: glyph,
    title: 'Hora de $name',
    subtitle:
        '${isDay ? 'Hora diurna' : 'Hora nocturna'} · termina en $minutesRemaining min',
    body: (scroll) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AHORA FAVORECE', style: ArcanumText.label()),
        const SizedBox(height: 8),
        Text(favors,
            style: ArcanumText.body(17, color: mood.accent),
            textAlign: TextAlign.start),
        const SizedBox(height: 20),
        Text(
            'Cada hora del día mágico pertenece a un planeta. Al terminar esta, '
            'el cielo pasa el cetro al siguiente regente en el orden antiguo — '
            'y con él cambia lo que la hora favorece.',
            style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
            textAlign: TextAlign.justify),
        const SizedBox(height: 24),
        Text('LAS PRÓXIMAS HORAS', style: ArcanumText.label()),
        const SizedBox(height: 12),
        ...nexts.map((p) => _hourRow(p)),
      ],
    ),
  );
}

Widget _hourRow(String planetKey) {
  final m = ArcanumMood.forPlanet(planetKey);
  final name = planetEs[planetKey] ?? planetKey;
  final glyph = planetGlyph[planetKey] ?? '✶';
  final favors = planetFavors[planetKey] ?? '';
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: m.glow.withValues(alpha: 0.12),
            border: Border.all(color: m.accent.withValues(alpha: 0.35)),
          ),
          child: Text(glyph,
              style: TextStyle(fontSize: 20, color: m.accent, height: 1)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: ArcanumText.heading(19, color: ArcanumColors.ivory)),
              Text(favors,
                  style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Hoja: la fase de la Luna ───────────────────────────────────────────────

void showMoonPhaseSheet(BuildContext context,
    {required String phaseName,
    required double illumination,
    required bool waxing,
    double? ageDays}) {
  final mood = ArcanumMood.moon;
  final favors = waxing
      ? 'atraer, crecer, edificar, invocar. La Luna que crece suma fuerza a '
          'todo lo que quieres que aumente: prosperidad, amor, salud, proyectos '
          'nuevos.'
      : 'desterrar, disolver, cerrar, soltar. La Luna que mengua retira y '
          'limpia: rompe ataduras, aleja lo dañino, termina lo que debe acabar.';
  final pct = (illumination * 100).round();

  _sheet(
    context,
    mood: mood,
    glyph: '☽',
    title: phaseName,
    subtitle:
        '$pct% iluminada${ageDays != null ? ' · ${ageDays.round()} días de edad' : ''}',
    body: (scroll) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('FASE', phaseName),
        const SizedBox(height: 10),
        _row('LUZ', '$pct % iluminada'),
        const SizedBox(height: 10),
        _row('MARCHA', waxing ? 'Creciente' : 'Menguante'),
        const SizedBox(height: 24),
        Text('QUÉ FAVORECE', style: ArcanumText.label()),
        const SizedBox(height: 10),
        Text(favors,
            style: ArcanumText.body(16), textAlign: TextAlign.justify),
        const SizedBox(height: 20),
        Text(
            'La Luna es el reloj de la magia sublunar: rige las mareas del alma, '
            'los sueños y las aguas. Trabaja con su marcha, no contra ella.',
            style: ArcanumText.body(15,
                color: ArcanumColors.ivoryMuted, italic: true),
            textAlign: TextAlign.justify),
      ],
    ),
  );
}

// ── Andamiaje compartido de las hojas ──────────────────────────────────────

void _sheet(
  BuildContext context, {
  required ArcanumMood mood,
  required String glyph,
  required String title,
  required String subtitle,
  required Widget Function(ScrollController) body,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.74,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: ArcanumSurface(
          mood: mood,
          intensity: 0.40,
          child: SingleChildScrollView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(28, 18, 28, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ArcanumColors.goldMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(glyph, style: TextStyle(fontSize: 44, color: mood.accent)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: ArcanumText.heading(32,
                                  color: ArcanumColors.gold)),
                          Text(subtitle,
                              style: ArcanumText.body(15,
                                  color: ArcanumColors.ivoryMuted, italic: true)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                body(scroll),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _row(String label, String value) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 110, child: Text(label, style: ArcanumText.label())),
        Expanded(
          child: Text(value,
              style: ArcanumText.body(16, color: ArcanumColors.ivory)),
        ),
      ],
    );

List<Widget> _bullets(List<String> items, ArcanumMood mood) => items
    .map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('·  ', style: TextStyle(color: mood.accent, fontSize: 18)),
              Expanded(child: Text(c, style: ArcanumText.body(15))),
            ],
          ),
        ))
    .toList();
