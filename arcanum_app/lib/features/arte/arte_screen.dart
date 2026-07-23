import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/state/flow_providers.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/astro_symbols.dart';
import '../../shared/widgets/arcanum_mood.dart';
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
  late Future<List<Map<String, dynamic>>> _catalog =
      widget.itemsOverride ?? _api.materiaList();
  late Future<List<Map<String, dynamic>>> _future = _catalog;
  String? _type;
  String? _lastPlanet;

  void _selectType(String? type) {
    setState(() {
      _type = type;
      _future = _filterCatalog(type, ref.read(materiaPlanetProvider));
    });
  }

  void _reload() {
    setState(() {
      _catalog = widget.itemsOverride ?? _api.materiaList();
      _future = _filterCatalog(_type, ref.read(materiaPlanetProvider));
    });
  }

  Future<List<Map<String, dynamic>>> _filterCatalog(
    String? type,
    String? planet,
  ) async {
    final items = await _catalog;
    return items
        .where((item) {
          final matchesType = type == null || item['item_type'] == type;
          final matchesPlanet = planet == null || item['planet'] == planet;
          return matchesType && matchesPlanet;
        })
        .toList(growable: false);
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
      _future = _filterCatalog(_type, planet);
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          children: [
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
        child: _MateriaCard(item: items[i], onTap: () => _openDetail(items[i])),
      ),
    );
  }

  void _openDetail(Map<String, dynamic> item) {
    final slug = item['slug'] as String;
    final isHerb = item['item_type'] == 'herb';
    showMateriaLoreSheet(
      context,
      future: _api.materiaDetail(slug),
      slug: slug,
      name: item['name'] as String,
      itemType: item['item_type'] as String,
      planet: item['planet'] as String?,
      element: item['element'] as String?,
      zodiac: item['zodiac'] as String?,
      // El puente vive en Culpeper, que es un herbario: solo las hierbas
      // pueden tener capítulo enlazado. 404 (sin puente) se ignora en silencio.
      bridgeFuture: isHerb ? _api.materiaBridge(slug) : null,
    );
  }
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
        child: Container(
          decoration: BoxDecoration(
            borderRadius: br,
            border: Border.all(color: mood.accent.withValues(alpha: 0.36)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(mood.edge, mood.core, 0.30)!, mood.edge],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x52000000),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: br,
                      gradient: RadialGradient(
                        center: Alignment(0, -0.55),
                        radius: 0.9,
                        colors: [
                          mood.accent.withValues(alpha: 0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 26),
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
                      size: 102,
                      strokeWidth: 1.55,
                      compact: true,
                      semanticLabel: item['name'] as String,
                    ),
                    const Spacer(),
                    Text(
                      item['name'] as String,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ArcanumText.heading(20, color: ArcanumColors.gold),
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
                  top: 12,
                  left: 13,
                  child: Text(
                    planetG,
                    style: TextStyle(
                      color: mood.accent.withValues(alpha: 0.78),
                      fontSize: 18,
                      height: 1,
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 12,
                child: Container(
                  width: 24,
                  height: 1,
                  color: mood.accent.withValues(alpha: 0.48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Entrada en cascada (fade + rise, desfasada por índice) ──────────────────
class _Reveal extends StatelessWidget {
  final Widget child;
  const _Reveal({required this.child});

  @override
  Widget build(BuildContext context) => child;
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
