import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../application/breath_settings.dart';
import '../domain/breath_pattern.dart';
import '../domain/breath_phase.dart';
import 'breath_texts.dart';

/// Ajustes de la practica: patron, retenciones, cantidad, cuenta y guia.
class BreathSetupScreen extends ConsumerWidget {
  const BreathSetupScreen({super.key});

  static const practicePath = '/respirar/practica';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(breathSettingsProvider);
    final n = ref.read(breathSettingsProvider.notifier);
    final p = s.pattern;
    final systemReduced = MediaQuery.disableAnimationsOf(context);
    final muted = ArcanumText.body(14, color: ArcanumColors.ivoryMuted);

    final String retSub;
    if (!p.hasRetention) {
      retSub = 'Este patrón no retiene el aire';
    } else if (s.retention) {
      retSub = 'Las pausas se sostienen con los tiempos del patrón';
    } else {
      retSub = 'Desactivado: cada pausa es un giro suave';
    }

    return Scaffold(
      backgroundColor: ArcanumColors.background,
      appBar: AppBar(title: Text('Respirar', style: ArcanumText.heading(24))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
          children: [
            Text(
              'Elige un patrón de la tradición y cómo quieres que te guíe.',
              style: ArcanumText.body(17, color: ArcanumColors.ivoryMuted),
            ),
            const _Heading('Patrón'),
            for (final pat in breathPatterns)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PatternTile(
                  pattern: pat,
                  selected: pat.id == s.patternId,
                  onSelect: () => n.selectPattern(pat.id),
                ),
              ),
            const _Heading('Ajustes'),
            SwitchListTile(
              key: const ValueKey('breath_retention'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Incluir retenciones'),
              subtitle: Text(retSub, style: muted),
              value: s.retentionActive,
              onChanged: p.free || !p.hasRetention ? null : n.setRetention,
            ),
            if (s.retentionActive)
              Container(
                key: const ValueKey('breath_retention_warning'),
                margin: const EdgeInsets.only(top: 4, bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1412),
                  border: Border.all(color: const Color(0xFF5B3A2A)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  retentionWarning,
                  style: ArcanumText.body(15, color: const Color(0xFFE7CFB4)),
                ),
              ),
            _AmountRow(settings: s, onChange: n.changeAmount),
            const SizedBox(height: 8),
            Text(
              'Duración de cada cuenta: '
              '${s.tempo.toStringAsFixed(1).replaceAll('.', ',')} s',
              style: ArcanumText.body(17),
            ),
            Text(
              'La Golden Dawn y Regardie dejan la velocidad al practicante.',
              style: muted,
            ),
            Slider(
              key: const ValueKey('breath_tempo'),
              value: s.tempo,
              min: BreathSettings.minTempo,
              max: BreathSettings.maxTempo,
              divisions: 10,
              semanticFormatterCallback: (v) =>
                  '${v.toStringAsFixed(1).replaceAll('.', ',')} segundos',
              onChanged: n.setTempo,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostrar la cuenta'),
              subtitle: Text('Números dentro de cada fase', style: muted),
              value: s.showCount,
              onChanged: n.setShowCount,
            ),
            const _Heading('Guía'),
            SwitchListTile(
              key: const ValueKey('breath_vibration'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Vibración al cambiar de fase'),
              subtitle: Text('Un pulso distinto por fase', style: muted),
              value: s.vibration,
              onChanged: n.setVibration,
            ),
            SwitchListTile(
              key: const ValueKey('breath_reduced'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Movimiento reducido'),
              subtitle: Text(
                systemReduced
                    ? 'Activado por tu sistema'
                    : 'Sin escalas: solo texto y un indicador fijo',
                style: muted,
              ),
              value: systemReduced || s.reducedMotion,
              onChanged: systemReduced ? null : n.setReducedMotion,
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 12,
              children: [
                Text('Duración total', style: ArcanumText.heading(18)),
                Text(
                  formatDuration(s.totalSeconds),
                  key: const ValueKey('breath_total'),
                  style: ArcanumText.heading(
                    26,
                    color: ArcanumColors.goldLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('breath_start'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: ArcanumColors.gold,
                foregroundColor: ArcanumColors.background,
              ),
              onPressed: () => context.push(practicePath),
              child: Text(
                'Empezar',
                style: ArcanumText.heading(20, color: ArcanumColors.background),
              ),
            ),
            const SizedBox(height: 6),
            Text('Puedes pausar o salir en cualquier momento.', style: muted),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: ArcanumText.heading(22, color: ArcanumColors.goldLight),
      ),
    ),
  );
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.settings, required this.onChange});

  final BreathSettings settings;
  final void Function(int delta) onChange;

  @override
  Widget build(BuildContext context) {
    final p = settings.pattern;
    final free = p.free;
    final sub = free
        ? 'Sin cuenta: toca al cambiar el aliento'
        : '${formatDuration(cycleSeconds(settings.phases))} por ciclo';
    final unit = free ? 'minutos' : 'ciclos';
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(free ? 'Minutos' : 'Ciclos', style: ArcanumText.body(17)),
                Text(
                  sub,
                  style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('breath_amount_minus'),
            tooltip: 'Menos $unit',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: settings.amount > 1 ? () => onChange(-1) : null,
            icon: const Icon(Icons.remove),
          ),
          Semantics(
            liveRegion: true,
            label: '${settings.amount} $unit',
            excludeSemantics: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 40),
              child: Text(
                '${settings.amount}',
                key: const ValueKey('breath_amount'),
                textAlign: TextAlign.center,
                style: ArcanumText.heading(22),
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('breath_amount_plus'),
            tooltip: 'Más $unit',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: settings.amount < p.maxAmount ? () => onChange(1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _PatternTile extends StatefulWidget {
  const _PatternTile({
    required this.pattern,
    required this.selected,
    required this.onSelect,
  });

  final BreathPattern pattern;
  final bool selected;
  final VoidCallback onSelect;

  @override
  State<_PatternTile> createState() => _PatternTileState();
}

class _PatternTileState extends State<_PatternTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.pattern;
    final on = widget.selected;
    final radius = BorderRadius.circular(12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: on ? const Color(0xFF1D1922) : ArcanumColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: on ? ArcanumColors.gold : ArcanumColors.surfaceHigh,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Semantics(
                    selected: on,
                    button: true,
                    child: InkWell(
                      key: ValueKey('breath_pattern_${p.id}'),
                      onTap: widget.onSelect,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: ArcanumText.heading(20)),
                              const SizedBox(height: 2),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    p.summary,
                                    style: ArcanumText.body(
                                      15,
                                      color: ArcanumColors.gold,
                                    ),
                                  ),
                                  _Tag(
                                    p.hasRetention
                                        ? 'con retención'
                                        : 'sin retención',
                                    strong: p.hasRetention,
                                  ),
                                  if (p.divulgation)
                                    const _Tag('divulgación', gold: true),
                                  if (p.advanced)
                                    const _Tag('avanzada', strong: true),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p.use,
                                style: ArcanumText.body(
                                  15,
                                  color: ArcanumColors.ivoryMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: ArcanumColors.surfaceHigh,
                ),
                SizedBox(
                  width: 48,
                  child: Semantics(
                    button: true,
                    expanded: _open,
                    label: 'Fuente de ${p.name}',
                    excludeSemantics: true,
                    child: InkWell(
                      key: ValueKey('breath_info_${p.id}'),
                      onTap: () => setState(() => _open = !_open),
                      child: Center(
                        child: Text(
                          'i',
                          style: ArcanumText.heading(
                            22,
                            color: ArcanumColors.gold,
                          ).copyWith(fontStyle: FontStyle.italic),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Container(
            key: ValueKey('breath_source_${p.id}'),
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: const BoxDecoration(
              color: Color(0xFF121017),
              border: Border(
                left: BorderSide(color: ArcanumColors.goldMuted, width: 2),
              ),
            ),
            child: Text(
              p.source,
              style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
            ),
          ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.strong = false, this.gold = false});

  final String text;
  final bool strong;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final color = strong
        ? ArcanumColors.burgundyLight
        : gold
        ? ArcanumColors.gold
        : ArcanumColors.ivoryMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(text, style: ArcanumText.body(12, color: color)),
    );
  }
}
