import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/state/flow_providers.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/astro_symbols.dart';
import '../../shared/widgets/arcanum_frame.dart';
import '../../shared/widgets/arcanum_mood.dart';
import '../../shared/widgets/arcanum_motion.dart';
import '../../shared/widgets/arcanum_surface.dart';
import '../../shared/widgets/info_dot.dart';
import 'materia_engravings.dart';
import 'materia_lore.dart';
import 'materia_specimen.dart';

const _filters = <(String?, String)>[
  (null, 'Todos'),
  ('herb', 'Hierbas'),
  ('stone', 'Piedras'),
  ('metal', 'Metales'),
  ('incense', 'Inciensos'),
  ('oil', 'Aceites'),
  ('resin', 'Resinas'),
  ('planet', 'Planetas'),
  ('angel', 'Ángeles'),
  ('sign', 'Signos'),
];

/// Los siete regentes clásicos, en orden de la semana mágica.
const _planets = [
  'sun',
  'moon',
  'mars',
  'mercury',
  'jupiter',
  'venus',
  'saturn',
];

class ArteScreen extends ConsumerStatefulWidget {
  const ArteScreen({super.key, this.itemsOverride});

  /// Fuente inyectable para previews y widget tests. Producción usa el API.
  final Future<List<Map<String, dynamic>>>? itemsOverride;
  @override
  ConsumerState<ArteScreen> createState() => _ArteScreenState();
}

class _ArteScreenState extends ConsumerState<ArteScreen> {
  late final ArcanumApi _api = ref.read(arcanumApiProvider);
  late Future<List<Map<String, dynamic>>> _future =
      widget.itemsOverride ?? _api.materiaList();
  String? _type;
  String? _lastPlanet;

  void _selectType(String? type) {
    setState(() {
      _type = type;
      _future = _api.materiaList(
        itemType: type,
        planet: ref.read(materiaPlanetProvider),
      );
    });
  }

  void _reload() {
    setState(() {
      _future =
          widget.itemsOverride ??
          _api.materiaList(
            itemType: _type,
            planet: ref.read(materiaPlanetProvider),
          );
    });
  }

  void _togglePlanet(String planet) {
    final current = ref.read(materiaPlanetProvider);
    ref
        .read(materiaPlanetProvider.notifier)
        .set(current == planet ? null : planet);
  }

  @override
  Widget build(BuildContext context) {
    // Si Hoy (o el filtro de planeta) cambió el regente, refresca el catálogo.
    final planet = ref.watch(materiaPlanetProvider);
    if (widget.itemsOverride == null && planet != _lastPlanet) {
      _lastPlanet = planet;
      _future = _api.materiaList(itemType: _type, planet: planet);
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          children: [
            const SizedBox(height: 32),
            const ArcanumHeaderCompat(subtitle: 'Materia Arcana'),
            const SizedBox(height: 8),
            const Center(child: InfoDot('materia')),
            const SizedBox(height: 14),
            _typeBar(),
            const SizedBox(height: 10),
            _planetBar(planet),
            if (planet != null) _activeBanner(planet),
            const SizedBox(height: 6),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snap) {
                  final Widget child;
                  if (snap.connectionState == ConnectionState.waiting) {
                    child = const _LoadingState(key: ValueKey('loading'));
                  } else if (snap.hasError) {
                    child = _ErrorState(
                      key: const ValueKey('error'),
                      error: snap.error,
                      onRetry: _reload,
                    );
                  } else if ((snap.data ?? const []).isEmpty) {
                    child = _EmptyState(
                      key: const ValueKey('empty'),
                      type: _type,
                      planet: planet,
                    );
                  } else {
                    final items = snap.data!;
                    child = _grid(items, planet);
                  }
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: child,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filtros por tipo ────────────────────────────────────────────────────
  Widget _typeBar() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (value, label) = _filters[i];
          final selected = value == _type;
          return Semantics(
            button: true,
            selected: selected,
            label: 'Filtrar por $label',
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _selectType(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: selected
                      ? ArcanumColors.gold.withValues(alpha: 0.16)
                      : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? ArcanumColors.gold
                        : ArcanumColors.goldMuted.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  label,
                  style: ArcanumText.body(
                    15,
                    color: selected
                        ? ArcanumColors.gold
                        : ArcanumColors.ivoryMuted,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Filtro por regente (medallones planetarios) ─────────────────────────
  Widget _planetBar(String? active) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _planets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final p = _planets[i];
          final selected = p == active;
          final mood = ArcanumMood.forPlanet(p);
          return Semantics(
            button: true,
            selected: selected,
            label: 'Filtrar por ${planetEs[p] ?? p}',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _togglePlanet(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      mood.glow.withValues(alpha: selected ? 0.34 : 0.08),
                      mood.glow.withValues(alpha: 0.0),
                    ],
                  ),
                  border: Border.all(
                    color: mood.accent.withValues(
                      alpha: selected ? 0.95 : 0.30,
                    ),
                    width: selected ? 1.6 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: mood.glow.withValues(alpha: 0.30),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  planetGlyph[p] ?? '',
                  style: TextStyle(
                    fontSize: 22,
                    height: 1,
                    color: selected
                        ? mood.accent
                        : ArcanumColors.ivoryMuted.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _activeBanner(String planet) {
    final mood = ArcanumMood.forPlanet(planet);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: mood.glow.withValues(alpha: 0.08),
          border: Border.all(color: mood.accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Text(
              planetGlyph[planet] ?? '',
              style: TextStyle(color: mood.accent, fontSize: 18, height: 1),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Correspondencias de ${planetEs[planet] ?? planet}',
                style: ArcanumText.body(14.5, color: mood.accent),
              ),
            ),
            IconButton(
              tooltip: 'Quitar filtro planetario',
              onPressed: () =>
                  ref.read(materiaPlanetProvider.notifier).set(null),
              icon: const Icon(Icons.close, size: 18),
              color: ArcanumColors.ivoryMuted,
            ),
          ],
        ),
      ),
    );
  }

  // ── Rejilla de placas de correspondencia ────────────────────────────────
  Widget _grid(List<Map<String, dynamic>> items, String? planet) {
    return GridView.builder(
      key: ValueKey('grid-$_type-$planet-${items.length}'),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.80,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _Reveal(
        index: i,
        child: _MateriaCard(item: items[i], onTap: () => _openDetail(items[i])),
      ),
    );
  }

  void _openDetail(Map<String, dynamic> item) {
    showMateriaLoreSheet(
      context,
      future: _api.materiaDetail(item['slug'] as String),
      slug: item['slug'] as String,
      name: item['name'] as String,
      itemType: item['item_type'] as String,
      planet: item['planet'] as String?,
      element: item['element'] as String?,
      zodiac: item['zodiac'] as String?,
    );
  }
}

/// Cabecera compacta local (menos aire vertical que ArcanumHeader, que reserva
/// espacio para dos filas de filtros en esta pantalla densa de catálogo).
class ArcanumHeaderCompat extends StatelessWidget {
  final String subtitle;
  const ArcanumHeaderCompat({super.key, required this.subtitle});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        'ARCANUM',
        textAlign: TextAlign.center,
        style: ArcanumText.wordmark(size: 38),
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: ArcanumText.body(
          16,
          italic: true,
          color: ArcanumColors.ivoryMuted,
        ),
      ),
    ],
  );
}

// ── Placa de correspondencia ───────────────────────────────────────────────
class _MateriaCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _MateriaCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final planet = item['planet'] as String?;
    final element = item['element'] as String?;
    final type = item['item_type'] as String;
    final slug = item['slug'] as String? ?? '';
    final mood = materiaMood(planet, element);
    final planetG = (planet != null && planet.isNotEmpty)
        ? planetGlyph[planet]
        : null;
    final zodiacKey = materiaZodiacKey(
      planet,
      element,
      explicit: item['zodiac'] as String?,
    );
    final zodiacG = zodiacKey == null ? null : signGlyph[zodiacKey];
    final subtitle = [
      materiaTypeEs[type] ?? type,
      if (element != null && element.isNotEmpty) materiaElementEs(element),
    ].join('  ·  ');
    const br = BorderRadius.all(Radius.circular(16));

    return Semantics(
      button: true,
      label: 'Abrir ${item['name']}, $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: br,
        child: ArcanumTilt(
          maxTilt: 0.06,
          borderRadius: br,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: br,
              border: Border.all(color: mood.accent.withValues(alpha: 0.28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.32),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: br,
              child: ArcanumFrame(
                mood: mood,
                radius: 16,
                corners: false,
                child: ArcanumSurface(
                  mood: mood,
                  intensity: 0.44,
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                        child: Column(
                          children: [
                            // Deja aire a los lados: el sello planetario vive
                            // arriba-izquierda y no debe pisar el label.
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 26,
                              ),
                              child: Text(
                                (materiaTypeEs[type] ?? type).toUpperCase(),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ArcanumText.label(),
                              ),
                            ),
                            const Spacer(),
                            MateriaSpecimen(
                              slug: slug,
                              type: type,
                              mood: mood,
                              size: type == 'herb' ? 104 : 88,
                              strokeWidth: 1.4,
                              semanticLabel: item['name'] as String,
                            ),
                            const Spacer(),
                            Text(
                              item['name'] as String,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: ArcanumText.heading(
                                20,
                                color: ArcanumColors.gold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ArcanumText.body(
                                12.5,
                                color: ArcanumColors.ivoryMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (planetG != null)
                        Positioned(
                          top: 9,
                          left: 10,
                          child: MateriaSeal(
                            glyph: planetG,
                            mood: mood,
                            size: 25,
                          ),
                        ),
                      if (zodiacG != null)
                        Positioned(
                          bottom: 9,
                          right: 10,
                          child: MateriaSeal(
                            glyph: zodiacG,
                            mood: mood,
                            size: 23,
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
    );
  }
}

// ── Entrada en cascada (fade + rise, desfasada por índice) ──────────────────
class _Reveal extends StatefulWidget {
  final int index;
  final Widget child;
  const _Reveal({required this.index, required this.child});
  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, 0.10),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    final delayMs = (widget.index * 55).clamp(0, 700);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    alwaysIncludeSemantics: true,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

// ── Estados: carga / error / vacío ──────────────────────────────────────────
class _LoadingState extends StatefulWidget {
  const _LoadingState({super.key});
  @override
  State<_LoadingState> createState() => _LoadingStateState();
}

class _LoadingStateState extends State<_LoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) =>
                Transform.rotate(angle: _c.value * 6.283, child: child),
            child: const Text(
              '✦',
              style: TextStyle(color: ArcanumColors.gold, fontSize: 34),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Consultando el herbario…',
            style: ArcanumText.body(
              15,
              color: ArcanumColors.ivoryMuted,
              italic: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  const _ErrorState({super.key, this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: ArcanumColors.goldMuted,
              size: 34,
            ),
            const SizedBox(height: 14),
            Text(
              'No se pudo abrir el herbario.',
              textAlign: TextAlign.center,
              style: ArcanumText.heading(20, color: ArcanumColors.ivory),
            ),
            const SizedBox(height: 6),
            Text(
              'El velo entre tú y el catálogo está denso. Inténtalo de nuevo.',
              textAlign: TextAlign.center,
              style: ArcanumText.body(
                14,
                color: ArcanumColors.ivoryMuted,
                italic: true,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String? type;
  final String? planet;
  const _EmptyState({super.key, this.type, this.planet});
  @override
  Widget build(BuildContext context) {
    final t = type;
    final tipoEs = t == null
        ? 'correspondencias'
        : (materiaTypeEs[t] ?? t).toLowerCase();
    final regente = planet == null
        ? ''
        : ' regidas por ${planetEs[planet] ?? planet}';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '✧',
              style: TextStyle(
                color: ArcanumColors.gold.withValues(alpha: 0.7),
                fontSize: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'El herbario aún calla',
              textAlign: TextAlign.center,
              style: ArcanumText.heading(22, color: ArcanumColors.gold),
            ),
            const SizedBox(height: 8),
            Text(
              'No guarda $tipoEs$regente. Prueba otra correspondencia.',
              textAlign: TextAlign.center,
              style: ArcanumText.body(
                15,
                color: ArcanumColors.ivoryMuted,
                italic: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
