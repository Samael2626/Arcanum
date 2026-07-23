import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/state/flow_providers.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/astro_symbols.dart';
import '../../shared/widgets/arcanum_card.dart';
import '../../shared/widgets/arcanum_mood.dart';
import '../../shared/widgets/arcanum_surface.dart';
import '../../shared/widgets/moon_disc.dart';
import 'hoy_lore.dart';
import 'presentation/widgets/planetary_hour_dial.dart';

class HoyScreen extends ConsumerStatefulWidget {
  const HoyScreen({super.key});
  @override
  ConsumerState<HoyScreen> createState() => _HoyScreenState();
}

class _HoyScreenState extends ConsumerState<HoyScreen> {
  late final ArcanumApi _api = ref.read(arcanumApiProvider);
  late Future<Map<String, dynamic>> _future = _api.today();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        // La atmósfera del cielo deriva del regente REAL del día; mientras
        // carga, penumbra neutra.
        final ruler = (snap.data?['day_ruler'] as String?);
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
                  onRefresh: () async => setState(() => _future = _api.today()),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(22, 36, 22, 28),
                    children: [
                      if (snap.connectionState == ConnectionState.waiting)
                        const _SkyLoading()
                      else if (snap.hasError)
                        _error(snap.error.toString())
                      else
                        _content(snap.data!),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
          onPressed: () => setState(() => _future = _api.today()),
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
    final hour = data['planetary_hour'] as Map<String, dynamic>;
    final moon = data['moon'] as Map<String, dynamic>;
    final ruler = data['day_ruler'] as String;
    // Entrada en cascada suave: cada panel emerge del velo con su propio retardo.
    return Column(
      children: [
        _rulerHero(ruler),
        const SizedBox(height: 18),
        _planetaryHourCard(hour),
        const SizedBox(height: 18),
        _moonCard(moon),
      ],
    );
  }

  /// Héroe del día: el regente con su atmósfera y color verdaderos. Tap → lore.
  Widget _rulerHero(String ruler) {
    final mood = ArcanumMood.forPlanet(ruler);
    final favors = planetFavors[ruler];
    // Glow del tilt hundido hacia el borde: acompaña, no quema.
    return _Tappable(
      borderRadius: 20,
      onTap: () => showPlanetLoreSheet(context, ruler),
      // Atmósfera más profunda: menos bloom para que el violeta sea regio.
      child: _TodayCard(
        mood: mood,
        radius: 20,
        intensity: 0.6,
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 22),
        child: Column(
          children: [
            const SectionLabel('REGENTE DEL DÍA', infoKey: 'dia_regente'),
            const SizedBox(height: 18),
            _HeroGlyph(glyph: planetGlyph[ruler] ?? '✦', accent: mood.accent),
            const SizedBox(height: 14),
            Text(
              'Día de ${planetEs[ruler] ?? ruler}',
              textAlign: TextAlign.center,
              style: ArcanumText.heading(32),
            ),
            if (favors != null) ...[
              const SizedBox(height: 10),
              Text('El cielo favorece hoy', style: ArcanumText.label()),
              const SizedBox(height: 4),
              Text(
                favors,
                textAlign: TextAlign.center,
                style: ArcanumText.body(16, color: ArcanumColors.ivory),
              ),
            ],
            const SizedBox(height: 16),
            _TapHint(color: mood.accent, label: 'Toca para su lore'),
          ],
        ),
      ),
    );
  }

  Widget _planetaryHourCard(Map<String, dynamic> h) {
    final planet = h['planet'] as String;
    final mins = h['minutes_remaining'] as int;
    final isDay = h['is_daytime'] as bool;
    final hourNumber = (h['hour_number'] as num?)?.toInt() ?? 1;
    final mood = ArcanumMood.forPlanet(planet);
    final progress = _hourProgress(h, mins);

    return _Tappable(
      borderRadius: 18,
      onTap: () => showPlanetaryHourSheet(
        context,
        planet,
        isDay: isDay,
        minutesRemaining: mins,
      ),
      child: _TodayCard(
        mood: mood,
        radius: 18,
        // Ámbar hundido a bronce: brasa en la penumbra, no panel amarillo.
        intensity: 0.48,
        child: Column(
          children: [
            const SectionLabel('HORA PLANETARIA', infoKey: 'hora_planetaria'),
            const SizedBox(height: 20),
            PlanetaryHourDial(
              progress: progress,
              glyph: planetGlyph[planet] ?? '?',
              mood: mood,
              hourNumber: hourNumber,
              isDay: isDay,
            ),
            const SizedBox(height: 18),
            Text(planetEs[planet] ?? planet, style: ArcanumText.heading(30)),
            const SizedBox(height: 8),
            Text(
              '${isDay ? 'Hora diurna' : 'Hora nocturna'}  ·  termina en $mins min',
              style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
            ),
            if (planetFavors[planet] != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: mood.glow.withValues(alpha: 0.10),
                  border: Border.all(
                    color: mood.accent.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  'Ahora favorece: ${planetFavors[planet]}',
                  textAlign: TextAlign.center,
                  style: ArcanumText.body(14, color: mood.accent),
                ),
              ),
            ],
            const SizedBox(height: 14),
            _TapHint(
              color: mood.accent,
              label: 'Toca para ver las próximas horas',
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ctaButton('⚗  Materiales', mood, () {
                    ref.read(materiaPlanetProvider.notifier).set(planet);
                    context.go('/saber');
                  }),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ctaButton('❦  Anotar', mood, () {
                    ref.read(grimoireComposeProvider.notifier).set(true);
                    context.go('/grimorio');
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Avance de la hora vigente (0→1) desde starts/ends; fallback a minutos.
  double _hourProgress(Map<String, dynamic> h, int mins) {
    final starts = DateTime.tryParse((h['starts_at'] as String?) ?? '');
    final ends = DateTime.tryParse((h['ends_at'] as String?) ?? '');
    if (starts != null && ends != null) {
      final total = ends.difference(starts).inSeconds;
      final elapsed = DateTime.now()
          .toUtc()
          .difference(starts.toUtc())
          .inSeconds;
      if (total > 0) return (elapsed / total).clamp(0.0, 1.0);
    }
    // Fallback: hora planetaria ~ 60 min.
    return (1 - (mins / 60)).clamp(0.0, 1.0);
  }

  Widget _ctaButton(String label, ArcanumMood mood, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 13),
        side: BorderSide(color: mood.accent.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: ArcanumText.body(14, color: mood.accent),
      ),
    );
  }

  Widget _moonCard(Map<String, dynamic> m) {
    final illum = (m['illumination'] as num).toDouble();
    final waxing = m['is_waxing'] as bool;
    final name = m['phase_name'] as String;
    final age = (m['age_days'] as num?)?.toDouble();
    return _Tappable(
      borderRadius: 18,
      onTap: () => showMoonPhaseSheet(
        context,
        phaseName: name,
        illumination: illum,
        waxing: waxing,
        ageDays: age,
      ),
      child: _TodayCard(
        mood: ArcanumMood.moon,
        radius: 18,
        intensity: 0.72,
        child: Column(
          children: [
            const SectionLabel('LA LUNA', infoKey: 'luna'),
            const SizedBox(height: 18),
            // Halo plateado tras el disco (respira suave).
            _MoonHalo(
              child: MoonDisc(illumination: illum, waxing: waxing, size: 96),
            ),
            const SizedBox(height: 16),
            Text(name, style: ArcanumText.heading(26)),
            const SizedBox(height: 6),
            Text(
              '${(illum * 100).round()}% iluminada'
              '${age != null ? '  ·  ${age.round()} días de edad' : ''}',
              textAlign: TextAlign.center,
              style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
            ),
            const SizedBox(height: 16),
            _TapHint(
              color: ArcanumColors.moonAccent,
              label: 'Toca para la fase',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cielo vivo: atmósfera de fondo que respira y transiciona al regente ────

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.mood,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
    this.radius = 18,
    this.intensity = 0.55,
  });

  final ArcanumMood mood;
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: br,
          border: Border.all(color: mood.accent.withValues(alpha: 0.34)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(mood.edge, mood.core, intensity * 0.45)!,
              mood.edge,
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4A000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: child,
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

// ── Glifo del héroe: pulso amplio y estelas ────────────────────────────────

class _HeroGlyph extends StatefulWidget {
  final String glyph;
  final Color accent;
  const _HeroGlyph({required this.glyph, required this.accent});

  @override
  State<_HeroGlyph> createState() => _HeroGlyphState();
}

class _HeroGlyphState extends State<_HeroGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Halo hundido: parte del acento hacia negro → aura profunda, no neón. El
    // glifo respira lento y bajo, misterio por encima de brillo.
    final halo = Color.lerp(widget.accent, Colors.black, 0.35)!;
    final glyphColor = Color.lerp(widget.accent, Colors.black, 0.12)!;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          width: 96,
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                halo.withValues(alpha: 0.07 + 0.05 * t),
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: halo.withValues(alpha: 0.10 + 0.10 * t),
                blurRadius: 16 + 12 * t,
                spreadRadius: 1 + 2 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Text(
        widget.glyph,
        style: TextStyle(fontSize: 60, color: glyphColor, height: 1),
      ),
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

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
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

/// Pista sutil de que el panel es tocable: filete + microcopy que late apenas.
class _TapHint extends StatefulWidget {
  final Color color;
  final String label;
  const _TapHint({required this.color, required this.label});

  @override
  State<_TapHint> createState() => _TapHintState();
}

class _TapHintState extends State<_TapHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.20 + 0.18 * t),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ArcanumText.body(
                    12.5,
                    color: ArcanumColors.ivoryMuted,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: widget.color.withValues(alpha: 0.55 + 0.35 * t),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Halo plateado tras el disco lunar, con respiración muy lenta.
class _MoonHalo extends StatefulWidget {
  final Widget child;
  const _MoonHalo({required this.child});

  @override
  State<_MoonHalo> createState() => _MoonHaloState();
}

class _MoonHaloState extends State<_MoonHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5000),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: ArcanumColors.moonGlow.withValues(
                  alpha: 0.12 + 0.06 * t,
                ),
                blurRadius: 24 + 8 * t,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
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
