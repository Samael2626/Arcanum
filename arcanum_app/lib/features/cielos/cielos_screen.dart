import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/astro_symbols.dart';
import '../../shared/widgets/arcanum_card.dart';
import '../../shared/widgets/gold_button.dart';

class CielosScreen extends ConsumerWidget {
  const CielosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth.status == AuthStatus.unknown) {
      return const Center(
          child: CircularProgressIndicator(color: ArcanumColors.gold, strokeWidth: 2));
    }
    if (!auth.isAuthenticated) return const _LoginPrompt();
    return const _NatalView();
  }
}

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✶', style: TextStyle(fontSize: 60, color: ArcanumColors.goldMuted)),
            const SizedBox(height: 20),
            Text('Tu cielo te espera', textAlign: TextAlign.center, style: ArcanumText.heading(30)),
            const SizedBox(height: 12),
            Text('Inicia sesión para revelar tu carta natal y los tránsitos del cielo de hoy sobre ella.',
                textAlign: TextAlign.center,
                style: ArcanumText.body(16, color: ArcanumColors.ivoryMuted)),
            const SizedBox(height: 28),
            GoldButton(label: 'Iniciar sesión', onPressed: () => context.go('/login')),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/register'),
              child: Text('Crear cuenta', style: ArcanumText.body(15, color: ArcanumColors.gold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NatalView extends ConsumerStatefulWidget {
  const _NatalView();
  @override
  ConsumerState<_NatalView> createState() => _NatalViewState();
}

class _NatalViewState extends ConsumerState<_NatalView> {
  late final ArcanumApi _api = ref.read(arcanumApiProvider);
  late Future<(Map<String, dynamic>, Map<String, dynamic>)> _future = _load();

  Future<(Map<String, dynamic>, Map<String, dynamic>)> _load() async {
    final natal = await _api.natalChart();
    final transits = await _api.transits();
    return (natal, transits);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: RefreshIndicator(
          color: ArcanumColors.gold,
          backgroundColor: ArcanumColors.surface,
          onRefresh: () async => setState(() => _future = _load()),
          child: FutureBuilder<(Map<String, dynamic>, Map<String, dynamic>)>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: ArcanumColors.gold, strokeWidth: 2));
              }
              if (snap.hasError) {
                return ListView(children: [
                  const SizedBox(height: 120),
                  Text('No se pudo trazar tu carta',
                      textAlign: TextAlign.center, style: ArcanumText.heading(22)),
                  const SizedBox(height: 8),
                  Text('${snap.error}',
                      textAlign: TextAlign.center,
                      style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)),
                ]);
              }
              final chart = snap.data!.$1['chart_data'] as Map<String, dynamic>;
              final transits = snap.data!.$2;
              return _content(chart, transits);
            },
          ),
        ),
      ),
    );
  }

  Widget _content(Map<String, dynamic> chart, Map<String, dynamic> transits) {
    final asc = chart['ascendant'] as Map<String, dynamic>;
    final mc = chart['midheaven'] as Map<String, dynamic>;
    final planets = (chart['planets'] as List).cast<Map<String, dynamic>>();
    final aspects = (transits['aspects_to_natal'] as List).cast<Map<String, dynamic>>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        const ArcanumHeader(subtitle: 'Tu carta natal'),
        const SizedBox(height: 24),
        ArcanumCard(
          child: Column(children: [
            const SectionLabel('ÁNGULOS', infoKey: 'ascendente'),
            const SizedBox(height: 14),
            _angle('Ascendente', asc),
            const Divider(color: ArcanumColors.surfaceHigh, height: 28),
            _angle('Medio Cielo', mc),
          ]),
        ),
        const SizedBox(height: 18),
        ArcanumCard(
          child: Column(children: [
            const SectionLabel('PLANETAS', infoKey: 'carta_natal'),
            const SizedBox(height: 12),
            ...planets.map(_planetRow),
          ]),
        ),
        const SizedBox(height: 18),
        ArcanumCard(
          child: Column(children: [
            const SectionLabel('TRÁNSITOS DE HOY', infoKey: 'transitos'),
            const SizedBox(height: 12),
            if (aspects.isEmpty)
              Text('Cielo en calma: sin aspectos exactos a tu carta ahora.',
                  textAlign: TextAlign.center,
                  style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted))
            else
              ...aspects.map(_aspectRow),
          ]),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            child: Text('Cerrar sesión',
                style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)),
          ),
        ),
      ],
    );
  }

  Widget _angle(String label, Map<String, dynamic> a) {
    final sign = a['sign'] as String;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(label, style: ArcanumText.body(16, color: ArcanumColors.ivoryMuted)),
      const SizedBox(width: 12),
      Text('${signGlyph[sign] ?? ''} ${signEs[sign] ?? sign}',
          style: ArcanumText.heading(22, color: ArcanumColors.gold)),
    ]);
  }

  Widget _planetRow(Map<String, dynamic> p) {
    final name = p['name'] as String;
    final sign = p['sign'] as String;
    final retro = p['retrograde'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        SizedBox(
            width: 34,
            child: Text(planetGlyph[name] ?? '?',
                style: const TextStyle(fontSize: 22, color: ArcanumColors.gold))),
        Expanded(child: Text(planetEs[name] ?? name, style: ArcanumText.body(16))),
        Text('${signGlyph[sign] ?? ''} ${signEs[sign] ?? sign}',
            style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted)),
        if (retro)
          const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Text('℞', style: TextStyle(color: ArcanumColors.burgundy, fontSize: 15)),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text('C${p['house']}',
              style: ArcanumText.body(13, color: ArcanumColors.goldMuted)),
        ),
      ]),
    );
  }

  Widget _aspectRow(Map<String, dynamic> a) {
    final t = a['transit'] as String;
    final n = a['natal'] as String;
    final asp = a['aspect'] as String;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Text(
        '${planetGlyph[t] ?? ''} ${planetEs[t] ?? t}  ${aspectEs[asp] ?? asp}  ${planetGlyph[n] ?? ''} ${planetEs[n] ?? n} natal',
        textAlign: TextAlign.center,
        style: ArcanumText.body(15),
      ),
    );
  }
}
