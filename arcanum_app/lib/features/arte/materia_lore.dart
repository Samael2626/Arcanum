import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/astro_symbols.dart';
import '../../shared/widgets/arcanum_mood.dart';
import '../../shared/widgets/arcanum_surface.dart';
import 'materia_engravings.dart';
import 'materia_specimen.dart';

/// Nombres en español de cada tipo de Materia Arcana.
const materiaTypeEs = {
  'herb': 'Hierba',
  'stone': 'Piedra',
  'metal': 'Metal',
  'incense': 'Incienso',
  'oil': 'Aceite',
  'resin': 'Resina',
  'element': 'Elemento',
  'color': 'Color',
  'planet': 'Planeta',
  'sign': 'Signo',
  'angel': 'Ángel',
};

/// Nombre en español de un elemento (clave ES o EN).
String materiaElementEs(String e) {
  switch (e.toLowerCase()) {
    case 'fuego':
    case 'fire':
      return 'Fuego';
    case 'agua':
    case 'water':
      return 'Agua';
    case 'aire':
    case 'air':
      return 'Aire';
    case 'tierra':
    case 'earth':
      return 'Tierra';
    default:
      return e[0].toUpperCase() + e.substring(1);
  }
}

/// Atmósfera de un ítem: manda su planeta regente; si no tiene, su elemento;
/// si tampoco, pergamino neutro. El color de la carta SIGNIFICA su regencia.
ArcanumMood materiaMood(String? planet, String? element) {
  if (planet != null && planet.isNotEmpty) return ArcanumMood.forPlanet(planet);
  if (element != null && element.isNotEmpty) {
    return ArcanumMood.forElement(element);
  }
  return ArcanumMood.neutral;
}

/// Hoja de detalle de un ítem de Materia Arcana, vestida con la atmósfera de su
/// regente. Se abre INSTANTÁNEA y ya tematizada (nombre/tipo/regente vienen del
/// resumen); el lore completo (usos, estudio, fuente) llega por [future].
///
/// Sigue el andamiaje de las hojas de Hoy/Cielos (DraggableScrollableSheet +
/// ArcanumSurface a intensidad ~0.42), para que todo ARCANUM respire igual.
void showMateriaLoreSheet(
  BuildContext context, {
  required Future<Map<String, dynamic>> future,
  required String slug,
  required String name,
  required String itemType,
  String? planet,
  String? element,
  String? zodiac,
}) {
  final mood = materiaMood(planet, element);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: ArcanumSurface(
          mood: mood,
          intensity: 0.42,
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
                const SizedBox(height: 18),
                _LoreHero(
                  slug: slug,
                  name: name,
                  itemType: itemType,
                  planet: planet,
                  element: element,
                  zodiac: zodiac,
                  mood: mood,
                ),
                const SizedBox(height: 22),
                FutureBuilder<Map<String, dynamic>>(
                  future: future,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Text(
                        'No se pudo abrir esta correspondencia.',
                        style: ArcanumText.body(
                          15,
                          color: ArcanumColors.ivoryMuted,
                          italic: true,
                        ),
                      );
                    }
                    if (!snap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: ArcanumColors.gold,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      );
                    }
                    return _body(snap.data!, mood);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Héroe del detalle: el grabado de la categoría GRANDE, con el trazo
/// dibujándose (PathMetrics) sobre la atmósfera del regente, y los sellos de
/// esquina (planeta arriba-izda, signo abajo-dcha). Debajo, nombre y linaje.
class _LoreHero extends StatefulWidget {
  const _LoreHero({
    required this.slug,
    required this.name,
    required this.itemType,
    required this.planet,
    required this.element,
    required this.zodiac,
    required this.mood,
  });

  final String slug;
  final String name;
  final String itemType;
  final String? planet;
  final String? element;
  final String? zodiac;
  final ArcanumMood mood;

  @override
  State<_LoreHero> createState() => _LoreHeroState();
}

class _LoreHeroState extends State<_LoreHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );
  late final Animation<double> _draw = CurvedAnimation(
    parent: _c,
    curve: Curves.easeInOutCubic,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planet = widget.planet;
    final mood = widget.mood;
    final planetG = (planet != null && planet.isNotEmpty)
        ? planetGlyph[planet]
        : null;
    final zodiacKey = materiaZodiacKey(
      planet,
      widget.element,
      explicit: widget.zodiac,
    );
    final zodiacG = zodiacKey == null ? null : signGlyph[zodiacKey];
    final subtitleParts = <String>[
      materiaTypeEs[widget.itemType] ?? widget.itemType,
      if (widget.element != null && widget.element!.isNotEmpty)
        materiaElementEs(widget.element!),
      if (planet != null && planet.isNotEmpty) planetEs[planet] ?? planet,
    ];

    return Column(
      children: [
        SizedBox(
          height: 148,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // halo suave tras el grabado
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      mood.glow.withValues(alpha: 0.16),
                      mood.glow.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _draw,
                builder: (_, _) => MateriaSpecimen(
                  slug: widget.slug,
                  type: widget.itemType,
                  mood: mood,
                  size: widget.itemType == 'herb' ? 148 : 132,
                  strokeWidth: 1.7,
                  progress: _draw.value,
                  semanticLabel: widget.name,
                ),
              ),
              if (planetG != null)
                Positioned(
                  top: 6,
                  left: 30,
                  child: MateriaSeal(glyph: planetG, mood: mood, size: 34),
                ),
              if (zodiacG != null)
                Positioned(
                  bottom: 6,
                  right: 34,
                  child: MateriaSeal(glyph: zodiacG, mood: mood, size: 30),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.name,
          textAlign: TextAlign.center,
          style: ArcanumText.heading(30, color: ArcanumColors.gold),
        ),
        const SizedBox(height: 3),
        Text(
          subtitleParts.join('  ·  '),
          textAlign: TextAlign.center,
          style: ArcanumText.body(
            15,
            color: ArcanumColors.ivoryMuted,
            italic: true,
          ),
        ),
      ],
    );
  }
}

Widget _body(Map<String, dynamic> d, ArcanumMood mood) {
  final props = (d['properties'] as Map?)?.cast<String, dynamic>() ?? const {};
  final intenciones =
      (props['intenciones'] as List?)?.cast<String>() ?? const [];
  final aliases = (d['aliases'] as List?)?.cast<String>() ?? const [];
  final notas = props['notas'] as String?;
  final estudio = props['estudio'] as String?;
  final fuente = props['fuente'] as String?;
  final parte = props['parte'] as String?;
  final toxicidad = props['toxicidad'] as String?;
  final dia = props['dia'] as String?;
  final angel = props['angel_regente'] as String?;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (intenciones.isNotEmpty) ...[
        Text('USOS', style: ArcanumText.label()),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: intenciones.map((i) => _chip(i, mood)).toList(),
        ),
        const SizedBox(height: 22),
      ],
      if (notas != null && notas.isNotEmpty) ...[
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: mood.glow.withValues(alpha: 0.07),
            border: Border(
              left: BorderSide(
                color: mood.accent.withValues(alpha: 0.6),
                width: 2,
              ),
            ),
          ),
          child: Text(
            notas,
            style: ArcanumText.body(
              16,
              color: ArcanumColors.ivory,
              italic: true,
            ),
          ),
        ),
        const SizedBox(height: 22),
      ],
      if (estudio != null && estudio.isNotEmpty) ...[
        Text('EN LA TRADICIÓN', style: ArcanumText.label()),
        const SizedBox(height: 10),
        Text(
          estudio,
          style: ArcanumText.body(16),
          textAlign: TextAlign.justify,
        ),
        const SizedBox(height: 22),
      ],
      if (dia != null ||
          angel != null ||
          parte != null ||
          toxicidad != null) ...[
        if (dia != null) ...[
          _row('DÍA', _cap(dia)),
          const SizedBox(height: 10),
        ],
        if (angel != null) ...[
          _row('ÁNGEL', angel),
          const SizedBox(height: 10),
        ],
        if (parte != null) ...[
          _row('PARTE', _cap(parte)),
          const SizedBox(height: 10),
        ],
        if (toxicidad != null) _row('TOXICIDAD', _cap(toxicidad)),
        const SizedBox(height: 22),
      ],
      if (aliases.isNotEmpty) ...[
        _row('TAMBIÉN', aliases.join(', ')),
        const SizedBox(height: 22),
      ],
      if (fuente != null && fuente.isNotEmpty) ...[
        Text('FUENTE', style: ArcanumText.label()),
        const SizedBox(height: 6),
        Text(
          fuente,
          style: ArcanumText.body(
            13,
            color: ArcanumColors.ivoryMuted,
            italic: true,
          ),
        ),
      ],
    ],
  );
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

Widget _chip(String text, ArcanumMood mood) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    color: mood.glow.withValues(alpha: 0.08),
    border: Border.all(color: mood.accent.withValues(alpha: 0.45)),
  ),
  child: Text(
    _cap(text),
    style: ArcanumText.body(13.5, color: ArcanumColors.ivory),
  ),
);

Widget _row(String label, String value) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    SizedBox(width: 96, child: Text(label, style: ArcanumText.label())),
    Expanded(
      child: Text(
        value,
        style: ArcanumText.body(16, color: ArcanumColors.ivory),
      ),
    ),
  ],
);
