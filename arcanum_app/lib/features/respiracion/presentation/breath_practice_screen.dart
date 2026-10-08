import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../application/breath_settings.dart';
import '../domain/breath_engine.dart';
import '../domain/breath_pattern.dart';
import '../domain/breath_phase.dart';
import 'breath_cues.dart';
import 'breath_orb.dart';
import 'breath_texts.dart';

/// Practica guiada con el orbe.
///
/// El reloj es el del Ticker, acumulado: al pausar se para el Ticker y el
/// tiempo no corre, asi que el motor nunca ve un salto. Si la app pasa a
/// segundo plano se pausa sola. La pantalla PUEDE apagarse durante la
/// practica: en v1 no se usa ningun paquete para mantenerla encendida.
class BreathPracticeScreen extends ConsumerStatefulWidget {
  const BreathPracticeScreen({super.key});

  @override
  ConsumerState<BreathPracticeScreen> createState() =>
      _BreathPracticeScreenState();
}

class _BreathPracticeScreenState extends ConsumerState<BreathPracticeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final BreathSettings _settings;
  late final List<BreathCue> _cues;
  late final Ticker _ticker;
  BreathEngine? _engine;
  ObserveSession? _observe;

  Duration _accum = Duration.zero;
  Duration _tickerNow = Duration.zero;

  BreathFrame? _frame;
  ObserveFrame? _obs;
  bool _paused = false;
  String? _doneText;

  Duration _clock() => _accum + _tickerNow;

  @override
  void initState() {
    super.initState();
    _settings = ref.read(breathSettingsProvider);
    _cues = ref.read(breathCuesProvider);
    _ticker = createTicker(_onTick);
    final p = _settings.pattern;
    if (p.free) {
      _observe = ObserveSession(minutes: _settings.amount, clock: _clock)
        ..start();
      _obs = _observe!.frame();
    } else {
      _engine = BreathEngine(
        phases: _settings.phases,
        cycles: _settings.amount,
        clock: _clock,
      )..start();
      _apply(_engine!.tick());
    }
    _ticker.start();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _engine?.stop();
    _observe?.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      if (!_paused && _doneText == null) _togglePause();
    }
  }

  void _onTick(Duration elapsed) {
    _tickerNow = elapsed;
    if (_engine != null) {
      _apply(_engine!.tick());
    } else {
      final f = _observe!.frame();
      if (f.finished) {
        _finish(observedText(f.breaths));
      }
      _obs = f;
    }
    if (mounted) setState(() {});
  }

  void _apply(BreathFrame f, {bool cue = true}) {
    _frame = f;
    if (f.finished) {
      _finish(cyclesDoneText(_settings.amount));
      return;
    }
    if (f.phaseChanged && cue) {
      for (final c in _cues) {
        c.phase(f.phase.kind);
      }
    }
  }

  void _finish(String text) {
    if (_doneText != null) return;
    _doneText = text;
    _ticker.stop();
    for (final c in _cues) {
      c.finish();
    }
  }

  void _togglePause() {
    setState(() {
      if (_paused) {
        _engine?.resume();
        _observe?.resume();
        _paused = false;
        _ticker.start();
        // reanudar repite el anuncio de la fase, sin volver a vibrar
        if (_engine != null) _apply(_engine!.tick(), cue: false);
      } else {
        _engine?.pause();
        _observe?.pause();
        _paused = true;
        _accum += _tickerNow;
        _tickerNow = Duration.zero;
        _ticker.stop();
      }
    });
  }

  void _onObserveTap() {
    final s = _observe!;
    if (!s.tap()) return;
    final f = s.frame();
    for (final c in _cues) {
      c.phase(f.inhale ? BreathKind.inhale : BreathKind.exhale);
    }
    setState(() => _obs = f);
  }

  void _exit() => Navigator.of(context).maybePop();

  bool get _reduced =>
      _settings.reducedMotion || MediaQuery.disableAnimationsOf(context);

  String get _title {
    final p = _settings.pattern;
    final noRet = p.hasRetention && !_settings.retention && !p.free;
    return p.name + (noRet ? ' · sin retención' : '');
  }

  @override
  Widget build(BuildContext context) {
    final done = _doneText != null;
    return Scaffold(
      backgroundColor: ArcanumColors.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.2,
            colors: [Color(0xFF1A1622), Color(0xFF0B0A0E)],
            stops: [0, .7],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(title: _title, onExit: _exit),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => Column(
                    children: [
                      Expanded(child: done ? const SizedBox() : _stage()),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: box.maxHeight * (done ? 1 : 0.45),
                          maxWidth: box.maxWidth,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: box.maxWidth),
                            child: done ? _doneBox() : _phaseBox(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!done) _meta(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                child: SizedBox(
                  width: double.infinity,
                  child: done
                      ? FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: _exit,
                          child: const Text('Volver'),
                        )
                      : OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            foregroundColor: ArcanumColors.goldLight,
                            side: const BorderSide(color: ArcanumColors.gold),
                          ),
                          onPressed: _togglePause,
                          child: Text(
                            _paused ? 'Reanudar' : 'Pausar',
                            style: ArcanumText.heading(20),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stage() {
    final Widget visual;
    if (_engine != null) {
      final f = _frame!;
      visual = _reduced
          ? Center(
              child: BreathStaticIndicator(
                phases: _engine!.phases,
                current: f.index,
              ),
            )
          : CustomPaint(
              key: const ValueKey('breath_orb'),
              size: Size.infinite,
              painter: BreathOrbPainter(
                level: f.level,
                kind: f.phase.kind,
                time: f.elapsed,
              ),
            );
      return ExcludeSemantics(child: visual);
    }
    final o = _obs!;
    return Semantics(
      button: true,
      label: 'Toca al cambiar el aliento',
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('breath_tapzone'),
        behavior: HitTestBehavior.opaque,
        onTap: _onObserveTap,
        child: _reduced
            ? const SizedBox.expand()
            : CustomPaint(
                key: const ValueKey('breath_orb'),
                size: Size.infinite,
                painter: BreathOrbPainter(
                  level: o.level,
                  kind: o.inhale ? BreathKind.inhale : BreathKind.exhale,
                  time: 0,
                ),
              ),
      ),
    );
  }

  Widget _phaseBox() {
    final String name, hint, count, spoken;
    if (_engine != null) {
      final f = _frame!;
      final ph = f.phase;
      name = phaseText(ph.kind, ph.side);
      hint = _paused ? 'En pausa' : phaseHint[ph.kind]!;
      count = _settings.showCount && ph.kind != BreathKind.turn
          ? '${f.beat}'
          : '';
      spoken = _paused ? 'En pausa' : (hint.isEmpty ? name : '$name, $hint');
    } else {
      final inhale = _obs!.inhale;
      name = inhale ? 'Entra…' : 'Sale…';
      hint = _paused ? 'En pausa' : 'Toca cuando el aliento cambie';
      count = '';
      spoken = _paused ? 'En pausa' : (inhale ? 'Entra' : 'Sale');
    }
    return Semantics(
      key: const ValueKey('breath_phase'),
      liveRegion: true,
      label: spoken,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                textAlign: TextAlign.center,
                style: ArcanumText.heading(44),
              ),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: ArcanumText.body(17, color: ArcanumColors.ivoryMuted),
              ),
              Text(
                count,
                key: const ValueKey('breath_count'),
                style: ArcanumText.heading(
                  30,
                  color: ArcanumColors.goldLight,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _doneBox() => Semantics(
    liveRegion: true,
    label: 'Terminado. $_doneText',
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Terminado',
              style: ArcanumText.heading(28, color: ArcanumColors.goldLight),
            ),
            const SizedBox(height: 8),
            Text(
              _doneText!,
              textAlign: TextAlign.center,
              style: ArcanumText.body(16, color: ArcanumColors.ivoryMuted),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _meta() {
    final String cycle;
    final double left;
    if (_engine != null) {
      cycle = 'Ciclo ${_frame!.cycle + 1} de ${_settings.amount}';
      left = _frame!.left;
    } else {
      cycle = 'Sin cuenta';
      left = _obs!.left;
    }
    final style = ArcanumText.body(
      15,
      color: ArcanumColors.ivoryMuted,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(cycle, style: style)),
          Text(
            formatClock(left),
            key: const ValueKey('breath_left'),
            style: style,
            semanticsLabel: 'Quedan ${formatDuration(left)}',
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onExit});

  final String title;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ArcanumText.label(),
            ),
          ),
          IconButton(
            tooltip: 'Salir',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: onExit,
            icon: const Icon(Icons.close, color: ArcanumColors.ivory),
          ),
        ],
      ),
    );
  }
}
