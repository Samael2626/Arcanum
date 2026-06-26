import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/state/flow_providers.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/astro_symbols.dart';
import '../../shared/widgets/arcanum_card.dart';
import '../../shared/widgets/info_dot.dart';
import '../../shared/widgets/moon_disc.dart';
import '../../shared/widgets/pulsing_glyph.dart';

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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: RefreshIndicator(
          color: ArcanumColors.gold,
          backgroundColor: ArcanumColors.surface,
          onRefresh: () async => setState(() => _future = _api.today()),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
            children: [
              const ArcanumHeader(subtitle: 'El cielo de hoy'),
              const SizedBox(height: 28),
              FutureBuilder<Map<String, dynamic>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return _loading();
                  }
                  if (snap.hasError) return _error(snap.error.toString());
                  return _content(snap.data!);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loading() => Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            const CircularProgressIndicator(
                color: ArcanumColors.gold, strokeWidth: 2),
            const SizedBox(height: 20),
            Text('Consultando los cielos…',
                style: ArcanumText.body(16, color: ArcanumColors.ivoryMuted)),
          ],
        ),
      );

  Widget _error(String msg) => ArcanumCard(
        child: Column(
          children: [
            const Text('⛧',
                style: TextStyle(fontSize: 40, color: ArcanumColors.burgundy)),
            const SizedBox(height: 12),
            Text('No se pudo contactar el oráculo',
                textAlign: TextAlign.center, style: ArcanumText.heading(22)),
            const SizedBox(height: 8),
            Text('¿El backend corre en localhost:8000?\n$msg',
                textAlign: TextAlign.center,
                style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)),
          ],
        ),
      );

  Widget _content(Map<String, dynamic> data) {
    final hour = data['planetary_hour'] as Map<String, dynamic>;
    final moon = data['moon'] as Map<String, dynamic>;
    final ruler = data['day_ruler'] as String;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 16), child: child),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text('${planetGlyph[ruler] ?? ''}  Día de ${planetEs[ruler] ?? ruler}',
                    textAlign: TextAlign.center, style: ArcanumText.heading(24)),
              ),
              const SizedBox(width: 8),
              const InfoDot('dia_regente'),
            ],
          ),
          const SizedBox(height: 24),
          _planetaryHourCard(hour),
          const SizedBox(height: 18),
          _moonCard(moon),
        ],
      ),
    );
  }

  Widget _planetaryHourCard(Map<String, dynamic> h) {
    final planet = h['planet'] as String;
    final mins = h['minutes_remaining'] as int;
    final isDay = h['is_daytime'] as bool;
    return ArcanumCard(
      child: Column(
        children: [
          const SectionLabel('HORA PLANETARIA', infoKey: 'hora_planetaria'),
          const SizedBox(height: 18),
          PulsingGlyph(planetGlyph[planet] ?? '?', size: 64),
          const SizedBox(height: 12),
          Text(planetEs[planet] ?? planet, style: ArcanumText.heading(30)),
          const SizedBox(height: 10),
          Text('${isDay ? 'Hora diurna' : 'Hora nocturna'}  ·  termina en $mins min',
              style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted)),
          if (planetFavors[planet] != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: ArcanumColors.gold.withValues(alpha: 0.07),
                border: Border.all(color: ArcanumColors.gold.withValues(alpha: 0.25)),
              ),
              child: Text('Ahora favorece: ${planetFavors[planet]}',
                  textAlign: TextAlign.center,
                  style: ArcanumText.body(14, color: ArcanumColors.gold)),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _ctaButton('⚗  Materiales', () {
                  ref.read(materiaPlanetProvider.notifier).set(planet);
                  context.go('/arte');
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ctaButton('❦  Anotar', () {
                  ref.read(grimoireComposeProvider.notifier).set(true);
                  context.go('/grimorio');
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ctaButton(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: ArcanumColors.gold.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label,
          textAlign: TextAlign.center,
          style: ArcanumText.body(14, color: ArcanumColors.gold)),
    );
  }

  Widget _moonCard(Map<String, dynamic> m) {
    final illum = (m['illumination'] as num).toDouble();
    final waxing = m['is_waxing'] as bool;
    final name = m['phase_name'] as String;
    return ArcanumCard(
      child: Column(
        children: [
          const SectionLabel('LA LUNA', infoKey: 'luna'),
          const SizedBox(height: 16),
          MoonDisc(illumination: illum, waxing: waxing),
          const SizedBox(height: 14),
          Text(name, style: ArcanumText.heading(26)),
          const SizedBox(height: 6),
          Text('${(illum * 100).round()}% iluminada',
              style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted)),
        ],
      ),
    );
  }
}
