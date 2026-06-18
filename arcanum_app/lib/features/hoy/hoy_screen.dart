import 'package:flutter/material.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/widgets/arcanum_card.dart';
import '../../shared/widgets/moon_disc.dart';

const planetGlyph = {
  'sun': '☉', 'moon': '☽', 'mercury': '☿', 'venus': '♀',
  'mars': '♂', 'jupiter': '♃', 'saturn': '♄',
};
const planetEs = {
  'sun': 'Sol', 'moon': 'Luna', 'mercury': 'Mercurio', 'venus': 'Venus',
  'mars': 'Marte', 'jupiter': 'Júpiter', 'saturn': 'Saturno',
};

class HoyScreen extends StatefulWidget {
  const HoyScreen({super.key});
  @override
  State<HoyScreen> createState() => _HoyScreenState();
}

class _HoyScreenState extends State<HoyScreen> {
  final _api = ArcanumApi();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.today();
  }

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
    return Column(
      children: [
        Text('${planetGlyph[ruler] ?? ''}  Día de ${planetEs[ruler] ?? ruler}',
            textAlign: TextAlign.center, style: ArcanumText.heading(24)),
        const SizedBox(height: 24),
        _planetaryHourCard(hour),
        const SizedBox(height: 18),
        _moonCard(moon),
      ],
    );
  }

  Widget _planetaryHourCard(Map<String, dynamic> h) {
    final planet = h['planet'] as String;
    final mins = h['minutes_remaining'] as int;
    final isDay = h['is_daytime'] as bool;
    return ArcanumCard(
      child: Column(
        children: [
          const SectionLabel('HORA PLANETARIA'),
          const SizedBox(height: 14),
          Text(planetGlyph[planet] ?? '?',
              style: const TextStyle(fontSize: 64, color: ArcanumColors.gold)),
          const SizedBox(height: 6),
          Text(planetEs[planet] ?? planet, style: ArcanumText.heading(30)),
          const SizedBox(height: 10),
          Text('${isDay ? 'Hora diurna' : 'Hora nocturna'}  ·  termina en $mins min',
              style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted)),
        ],
      ),
    );
  }

  Widget _moonCard(Map<String, dynamic> m) {
    final illum = (m['illumination'] as num).toDouble();
    final waxing = m['is_waxing'] as bool;
    final name = m['phase_name'] as String;
    return ArcanumCard(
      child: Column(
        children: [
          const SectionLabel('LA LUNA'),
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
