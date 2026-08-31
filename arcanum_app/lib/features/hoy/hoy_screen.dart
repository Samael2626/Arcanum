import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/astro/user_place.dart';
import '../../core/state/flow_providers.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/astro_symbols.dart';
import '../../shared/widgets/arcanum_card.dart';
import '../../shared/widgets/arcanum_mood.dart';
import '../../shared/widgets/arcanum_surface.dart';
import 'hoy_guidance.dart';
import 'hoy_lore.dart';
import 'presentation/widgets/nested_sky_instrument.dart';
import 'presentation/widgets/sky_today_card.dart';
import 'presentation/widgets/today_card.dart';

/// El cielo de hoy de ESTA persona, o solo la luna si no ha confirmado lugar.
///
/// La respuesta tiene la misma forma en los dos casos; lo que falta cuando no
/// hay lugar falta de verdad (`day_ruler` y `planetary_hour` ausentes), y la
/// pantalla lo declara en vez de rellenarlo.
///
/// DERIVA del lugar en vez de recargarse a mano. El perfil llega DESPUES del
/// arranque (el bootstrap de auth es asincrono), y la version anterior guardaba
/// el future en el State y lo reemplazaba con setState desde un ref.listen. Eso
/// abria una carrera perdida: si el future viejo (solo luna) resolvia despues
/// del cambio de lugar, el FutureBuilder seguia suscrito a EL, pintaba su
/// resultado y ya no volvia a construirse. La pantalla se quedaba clavada en
/// "No disponible sin tu lugar" para siempre aunque el lugar SI hubiera
/// llegado. Watch sobre el lugar hace que recalcular sea responsabilidad de
/// Riverpod y no de un orden de llegada.
final hoySkyProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  final place = ref.watch(userPlaceProvider);
  final api = ref.read(arcanumApiProvider);
  if (place == null) {
    return <String, dynamic>{'moon': await api.moon()};
  }
  return api.today(lat: place.lat, lon: place.lon);
});

class HoyScreen extends ConsumerStatefulWidget {
  const HoyScreen({super.key});
  @override
  ConsumerState<HoyScreen> createState() => _HoyScreenState();
}

class _HoyScreenState extends ConsumerState<HoyScreen> {
  /// Vuelve a pedir el cielo y espera a que llegue: sin el await, el indicador
  /// de arrastre se cerraria antes de que hubiera nada nuevo que mirar.
  Future<void> _reload() => ref.refresh(hoySkyProvider.future);

  @override
  Widget build(BuildContext context) {
    final sky = ref.watch(hoySkyProvider);
    // La atmósfera del cielo deriva del regente REAL del día; mientras
    // carga, penumbra neutra.
    final ruler = sky.value?['day_ruler'] as String?;
    final mood = ruler != null
        ? ArcanumMood.forPlanet(ruler)
        : ArcanumMood.neutral;

    return Stack(
      children: [
        Positioned.fill(child: _LivingSky(mood: mood)),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: RefreshIndicator(
              color: ArcanumColors.gold,
              backgroundColor: ArcanumColors.surface,
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(22, 36, 22, 28),
                children: [
                  switch (sky) {
                    AsyncData(:final value) => _content(value),
                    AsyncError(:final error) => _error(error.toString()),
                    _ => const _SkyLoading(),
                  },
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Estados premium ────────────────────────────────────────────────────

  Widget _error(String msg) => ArcanumCard(
    mood: ArcanumMood.saturn,
    frame: true,
    child: Column(
      children: [
        Text(
          '⛧',
          style: TextStyle(
            fontSize: 44,
            color: ArcanumColors.saturnAccent.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'El cielo guarda silencio',
          textAlign: TextAlign.center,
          style: ArcanumText.heading(24),
        ),
        const SizedBox(height: 8),
        Text(
          'No se pudo contactar el oráculo astral.',
          textAlign: TextAlign.center,
          style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
        ),
        const SizedBox(height: 18),
        OutlinedButton(
          onPressed: _reload,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: ArcanumColors.gold.withValues(alpha: 0.6)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Reintentar',
            style: ArcanumText.body(15, color: ArcanumColors.gold),
          ),
        ),
      ],
    ),
  );

  // ── Contenido ──────────────────────────────────────────────────────────

  Widget _content(Map<String, dynamic> data) {
    // Sin lugar confirmado la luna sigue estando: es global. El regente y la
    // hora no, y llegan ausentes.
    final moon = data['moon'] as Map<String, dynamic>;
    final hour = data['planetary_hour'] as Map<String, dynamic>?;
    final ruler = data['day_ruler'] as String?;
    // "Tu siguiente paso": lo conduce la HORA planetaria (cambia cada ~60 min,
    // mantiene Hoy vivo), no el día. Si el planeta no es de los siete clásicos
    // no hay paso y la tarjeta no aparece.
    final step = hour == null
        ? null
        : nextStepFor(
            hourPlanet: hour['planet'] as String,
            hourNumber: (hour['hour_number'] as num?)?.toInt() ?? 1,
          );
    // Entrada en cascada suave: cada panel emerge del velo con su propio retardo.
    return Column(
      children: [
        if (step != null) ...[
          _NextStepCard(step: step, onTap: () => _runStep(step)),
          const SizedBox(height: 18),
        ],
        _skyInstrument(ruler: ruler, hour: hour, moon: moon),
        const SizedBox(height: 18),
        // La lectura personal cierra la pantalla. Carga por su cuenta para que
        // un fallo no se lleve por delante el instrumento local.
        const SkyTodayCard(),
      ],
    );
  }

  /// Ejecuta el salto de un paso/atajo. Todos los destinos existen ya: plantas
  /// filtradas por planeta, un capítulo de Culpeper, el editor del grimorio o
  /// la pestaña del oráculo.
  void _runStep(NextStep step) => _navigate(step.kind, step.planet, step.slug);

  void _navigate(NextStepKind kind, String planet, String? slug) {
    switch (kind) {
      case NextStepKind.materia:
        ref.read(materiaPlanetProvider.notifier).set(planet);
        context.go('/saber');
      case NextStepKind.culpeper:
        if (slug != null) {
          context.push('/saber/$culpeperWorkSlug/$slug');
        }
      case NextStepKind.grimoire:
        ref.read(grimoireComposeProvider.notifier).set(true);
        context.go('/grimorio');
      case NextStepKind.tarot:
        if (slug != null) {
          ref.read(oraculoFocusCardProvider.notifier).set(slug);
        }
        context.go('/oraculo');
      case NextStepKind.cielos:
        ref.read(cielosFocusPlanetProvider.notifier).set(planet);
        context.go('/cielos');
    }
  }

  Widget _skyInstrument({
    required String? ruler,
    required Map<String, dynamic>? hour,
    required Map<String, dynamic> moon,
  }) {
    final hourPlanet = hour?['planet'] as String?;
    // Ni `planet` ni `mood` se calculan ya aqui: los decide el selector del
    // instrumento, que es quien sabe que cuerpo se esta mirando.
    final illumination = (moon['illumination'] as num).toDouble();
    final waxing = moon['is_waxing'] as bool;
    final phase = moon['phase_name'] as String;
    final age = (moon['age_days'] as num?)?.toDouble();

    return NestedSkyInstrument(
      ruler: ruler,
      hour: hour,
      moon: moon,
      onRulerTap: ruler == null
          ? null
          : () => showPlanetLoreSheet(context, ruler),
      onHourTap: hourPlanet == null
          ? null
          : () => showPlanetaryHourSheet(
              context,
              hourPlanet,
              isDay: hour!['is_daytime'] as bool,
              minutesRemaining: (hour['minutes_remaining'] as num).toInt(),
            ),
      onMoonTap: () => showMoonPhaseSheet(
        context,
        phaseName: phase,
        illumination: illumination,
        waxing: waxing,
        ageDays: age,
      ),
      onConfirmPlace: () => context.push('/perfil'),
      // Los chips siguen al cuerpo elegido en el selector, no a la hora: los
      // del Sol no le sirven a la Luna.
      actionsFor: (elegido) =>
          _jumpRow(elegido, ArcanumMood.forPlanet(elegido)),
    );
  }

  Widget _jumpRow(String planet, ArcanumMood mood) {
    final name = planetEs[planet] ?? planet;
    // "Plantas de Venus" pero "Plantas de la Luna": de los siete cuerpos, el
    // unico con articulo es la Luna. Se veia poco porque los chips seguian al
    // planeta de la hora; con el selector, elegirla es un toque.
    final deName = planet == 'moon' ? 'de la $name' : 'de $name';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _JumpChip(
          label: 'Lore $deName',
          mood: mood,
          onTap: () => showPlanetLoreSheet(context, planet),
        ),
        _JumpChip(
          label: 'Plantas $deName',
          mood: mood,
          onTap: () => _navigate(NextStepKind.materia, planet, null),
        ),
        if (planetCulpeperChapter.containsKey(planet))
          _JumpChip(
            label: 'Léelo en Culpeper',
            mood: mood,
            onTap: () => _navigate(
              NextStepKind.culpeper,
              planet,
              planetCulpeperChapter[planet],
            ),
          ),
        _JumpChip(
          label: 'Tu $name natal',
          mood: mood,
          onTap: () => _navigate(NextStepKind.cielos, planet, null),
        ),
        _JumpChip(
          label: 'Anota',
          mood: mood,
          onTap: () => _navigate(NextStepKind.grimoire, planet, null),
        ),
      ],
    );
  }
}

// ── Cielo vivo: atmósfera de fondo que respira y transiciona al regente ────

/// "Tu siguiente paso": el titular de Hoy. Toma la atmósfera del planeta de la
/// hora y ofrece UNA acción concreta. Toda la tarjeta es tocable; el botón
/// repite la acción como afford explícito.
class _NextStepCard extends StatelessWidget {
  final NextStep step;
  final VoidCallback onTap;
  const _NextStepCard({required this.step, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final mood = ArcanumMood.forPlanet(step.planet);
    return _Tappable(
      borderRadius: 18,
      onTap: onTap,
      child: TodayCard(
        mood: mood,
        radius: 18,
        intensity: 0.55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '✶',
                  style: TextStyle(color: mood.accent, fontSize: 15, height: 1),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(step.eyebrow, style: ArcanumText.label())),
              ],
            ),
            const SizedBox(height: 12),
            Text(step.title, style: ArcanumText.heading(23)),
            const SizedBox(height: 18),
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: mood.glow.withValues(alpha: 0.16),
                  border: Border.all(color: mood.accent.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      step.actionLabel,
                      style: ArcanumText.body(15, color: mood.accent),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 17,
                      color: mood.accent,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip de salto contextual: un hilo corto a otra sección, teñido del planeta
/// del panel donde vive.
class _JumpChip extends StatelessWidget {
  final String label;
  final ArcanumMood mood;
  final VoidCallback onTap;
  const _JumpChip({
    required this.label,
    required this.mood,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: mood.glow.withValues(alpha: 0.10),
          border: Border.all(color: mood.accent.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: ArcanumText.body(13, color: mood.accent)),
            const SizedBox(width: 5),
            Icon(Icons.arrow_forward_rounded, size: 14, color: mood.accent),
          ],
        ),
      ),
    );
  }
}

class _LivingSky extends StatefulWidget {
  final ArcanumMood mood;
  const _LivingSky({required this.mood});

  @override
  State<_LivingSky> createState() => _LivingSkyState();
}

class _LivingSkyState extends State<_LivingSky>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late ArcanumMood _from = widget.mood;
  late ArcanumMood _to = widget.mood;

  @override
  void didUpdateWidget(covariant _LivingSky old) {
    super.didUpdateWidget(old);
    if (widget.mood.core != _to.core) {
      _from = ArcanumMood.lerp(_from, _to, _fade.value);
      _to = widget.mood;
      _fade.value = 1;
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fade,
      builder: (context, _) {
        final mood = widget.mood;
        return ArcanumSurface(
          mood: mood,
          drift: null,
          grain: false,
          // Cielo como INSINUACIÓN del regente: penumbra profunda para que el
          // color se lea misterioso, no brillante. Los paneles rebotan sobre él.
          intensity: 0.34,
        );
      },
    );
  }
}

// ── Cascada de entrada: cada panel emerge del velo con su retardo ──────────

class _Cascade extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const _Cascade({required this.child, required this.delayMs});

  @override
  State<_Cascade> createState() => _CascadeState();
}

class _CascadeState extends State<_Cascade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _startTimer = Timer(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 26),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ── Afford táctil: hace VISIBLE que un panel se abre al tocarlo ────────────

/// Envuelve un panel: escala/atenúa levemente al pulsar (feedback físico) y
/// dispara [onTap]. Los botones internos capturan su propio tap primero.
class _Tappable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;
  const _Tappable({
    required this.child,
    required this.onTap,
    this.borderRadius = 16,
  });

  @override
  State<_Tappable> createState() => _TappableState();
}

class _TappableState extends State<_Tappable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ── Carga premium: constelación girando ────────────────────────────────────

class _SkyLoading extends StatefulWidget {
  const _SkyLoading();

  @override
  State<_SkyLoading> createState() => _SkyLoadingState();
}

class _SkyLoadingState extends State<_SkyLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  static const _glyphs = ['☉', '☽', '☿', '♀', '♂', '♃', '♄'];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final a = _c.value * 2 * math.pi;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i < _glyphs.length; i++)
                      Transform.translate(
                        offset: Offset(
                          math.cos(a + i * 2 * math.pi / _glyphs.length) * 58,
                          math.sin(a + i * 2 * math.pi / _glyphs.length) * 58,
                        ),
                        child: Opacity(
                          opacity: 0.35 + 0.4 * (0.5 + 0.5 * math.sin(a + i)),
                          child: Text(
                            _glyphs[i],
                            style: const TextStyle(
                              fontSize: 20,
                              color: ArcanumColors.gold,
                            ),
                          ),
                        ),
                      ),
                    Text(
                      '✶',
                      style: TextStyle(
                        fontSize: 30,
                        color: ArcanumColors.gold.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Consultando los cielos…',
            style: ArcanumText.body(
              16,
              italic: true,
              color: ArcanumColors.ivoryMuted,
            ),
          ),
        ],
      ),
    );
  }
}
