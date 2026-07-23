import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/astro_symbols.dart';
import '../../shared/widgets/arcanum_mood.dart';
import '../../shared/widgets/arcanum_surface.dart';
import '../lecturas/domain/library_models.dart';
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
  // El puente Materia → Lecturas. Solo se pasa para hierbas (Culpeper es un
  // herbario). Si resuelve 404 (planta sin capítulo) la tarjeta no se muestra:
  // ausencia esperada, en silencio. La entrada vive al pie, junto a FUENTE.
  Future<Map<String, dynamic>>? bridgeFuture,
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
                if (bridgeFuture != null)
                  _BridgeSection(
                    future: bridgeFuture,
                    materiaPlanet: planet,
                    mood: mood,
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// El puente Materia → Culpeper dentro de la ficha, al pie (junto a FUENTE).
///
/// Silencioso por diseño: mientras carga no ocupa sitio, y si el backend
/// responde 404 (esta planta no tiene capítulo enlazado) desaparece sin ruido.
/// Solo cuando hay puente aparece la tarjeta, con la comparación de regencias
/// y un anticipo del pasaje; el capítulo entero queda a un toque.
class _BridgeSection extends StatelessWidget {
  const _BridgeSection({
    required this.future,
    required this.materiaPlanet,
    required this.mood,
  });

  final Future<Map<String, dynamic>> future;
  final String? materiaPlanet;
  final ArcanumMood mood;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        // Sin puente (404) o aún cargando: no ocupamos sitio. La ausencia de
        // enlace es lo normal en la mayoría de plantas, no un fallo que mostrar.
        if (snap.connectionState != ConnectionState.done || !snap.hasData) {
          return const SizedBox.shrink();
        }
        final CulpeperBridge bridge;
        try {
          bridge = CulpeperBridge.fromJson(snap.data!);
        } catch (_) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 26),
          child: _BridgeCard(
            bridge: bridge,
            materiaPlanet: materiaPlanet,
            mood: mood,
          ),
        );
      },
    );
  }
}

class _BridgeCard extends StatelessWidget {
  const _BridgeCard({
    required this.bridge,
    required this.materiaPlanet,
    required this.mood,
  });

  final CulpeperBridge bridge;
  final String? materiaPlanet;
  final ArcanumMood mood;

  String _planetLabel(String p) {
    final glyph = planetGlyph[p];
    final name = planetEs[p] ?? _cap(p);
    return glyph == null ? name : '$glyph  $name';
  }

  String _rulersLabel(List<String> planets) => planets.isEmpty
      ? 'sin regente declarado'
      : planets.map(_planetLabel).join('  ·  ');

  @override
  Widget build(BuildContext context) {
    final ref = [
      bridge.author,
      if (bridge.year != null) '${bridge.year}',
    ].join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '❦',
              style: TextStyle(color: mood.accent, fontSize: 15, height: 1),
            ),
            const SizedBox(width: 8),
            Text('EN LAS LECTURAS', style: ArcanumText.label()),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(
          button: true,
          label: 'Leer «${bridge.chapterTitle}» en ${bridge.workTitle}',
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.push(
              '/saber/${bridge.workSlug}/${bridge.chapterSlug}',
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: mood.glow.withValues(alpha: 0.08),
                border: Border.all(color: mood.accent.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bridge.chapterTitle,
                    style: ArcanumText.heading(19, color: ArcanumColors.gold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${bridge.workTitle} · $ref',
                    style: ArcanumText.body(
                      12.5,
                      color: ArcanumColors.ivoryMuted,
                      italic: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _rulings(),
                  if (bridge.excerpt != null &&
                      bridge.excerpt!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.black.withValues(alpha: 0.16),
                        border: Border(
                          left: BorderSide(
                            color: mood.accent.withValues(alpha: 0.55),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        '“${bridge.excerpt!.trim()}”',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: ArcanumText.body(
                          14.5,
                          color: ArcanumColors.ivory,
                          italic: true,
                        ),
                      ),
                    ),
                    if (!bridge.excerptIsTranslation) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Texto original — se traduce al abrir el capítulo.',
                        style: ArcanumText.body(
                          11.5,
                          color: ArcanumColors.ivoryMuted,
                          italic: true,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Leer capítulo completo',
                        style: ArcanumText.body(13.5, color: mood.accent),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: mood.accent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// La comparación de regencias. Si difieren, ambas con su etiqueta y sin
  /// jerarquía: son dos tradiciones, no una correcta y otra equivocada.
  Widget _rulings() {
    final culpeper = _rulersLabel(bridge.rulingPlanets);
    if (!bridge.discrepant) {
      return _rulerRow('REGENTE', culpeper);
    }
    final materia = materiaPlanet != null && materiaPlanet!.isNotEmpty
        ? _planetLabel(materiaPlanet!)
        : 'sin regente declarado';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rulerRow('MATERIA', materia),
        const SizedBox(height: 6),
        _rulerRow('CULPEPER', culpeper),
        const SizedBox(height: 8),
        Text(
          'Las dos tradiciones difieren en la regencia; ambas se conservan.',
          style: ArcanumText.body(
            12,
            color: ArcanumColors.ivoryMuted,
            italic: true,
          ),
        ),
      ],
    );
  }

  Widget _rulerRow(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 78, child: Text(label, style: ArcanumText.label())),
      Expanded(
        child: Text(
          value,
          style: ArcanumText.body(15, color: ArcanumColors.ivory),
        ),
      ),
    ],
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
                  compact: true,
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
