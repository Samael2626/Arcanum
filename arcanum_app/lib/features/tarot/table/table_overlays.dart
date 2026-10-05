/// Lo que flota sobre la mesa sin ser mesa: la ayuda de gestos y deshacer.
///
/// Van FUERA del `Listener` de la mesa: sus toques no deben llegar al director
/// (tocar «Entendido» no puede, ademas, tocar el paño que hay debajo).
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/arcanum_colors.dart';
import 'table_icons.dart';

/// Lista de posiciones del abanico con zonas de toque de 48 dp.
class FanPickerButton extends StatelessWidget {
  const FanPickerButton({
    super.key,
    required this.positions,
    required this.onChoose,
  });

  final List<int> positions;
  final ValueChanged<int> onChoose;

  @override
  Widget build(BuildContext context) {
    if (positions.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (sheet) => SafeArea(
                child: FractionallySizedBox(
                  heightFactor: .75,
                  child: ListView.builder(
                    itemCount: positions.length,
                    itemExtent: 48,
                    itemBuilder: (row, index) {
                      final position = positions[index];
                      void choose() {
                        Navigator.pop(sheet);
                        onChoose(position);
                      }

                      return Semantics(
                        label:
                            'Carta ${index + 1} de ${positions.length}, '
                            'posicion ${position + 1} del mazo',
                        button: true,
                        onTap: choose,
                        excludeSemantics: true,
                        child: InkWell(
                          onTap: choose,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Carta ${position + 1}'),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            child: Text('Elegir carta (${positions.length})'),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta con los cuatro gestos. Sale sola la primera vez, se cierra a los
/// 40 s (o con «Entendido») y deja un «?» arriba a la derecha para volver.
class TableHelp extends StatefulWidget {
  const TableHelp({super.key});

  static const seenKey = 'tarot_mesa_ayuda_vista';
  static const autoClose = Duration(seconds: 40);

  @override
  State<TableHelp> createState() => _TableHelpState();
}

class _TableHelpState extends State<TableHelp>
    with SingleTickerProviderStateMixin {
  // se crea al montar, no al primer uso: si la ayuda ya se vio, el primer uso
  // era el dispose, y crear un ticker mientras se desmonta revienta
  late final AnimationController _timer;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _timer = AnimationController(vsync: this, duration: TableHelp.autoClose)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _close();
      });
    _firstTime();
  }

  Future<void> _firstTime() async {
    bool seen;
    try {
      seen =
          (await SharedPreferences.getInstance()).getBool(TableHelp.seenKey) ??
          false;
    } on Object {
      seen = false;
    }
    if (!seen && mounted) _show();
  }

  void _show() {
    setState(() => _open = true);
    _timer.forward(from: 0);
  }

  Future<void> _close() async {
    _timer.stop();
    if (mounted) setState(() => _open = false);
    try {
      await (await SharedPreferences.getInstance()).setBool(
        TableHelp.seenKey,
        true,
      );
    } on Object {
      // sin almacenamiento la ayuda volvera a salir la proxima vez: no es grave
    }
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: IconButton(
            tooltip: 'Cómo se usa la mesa',
            onPressed: _show,
            icon: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ArcanumColors.goldMuted),
              ),
              child: const Text(
                '?',
                style: TextStyle(fontSize: 16, color: ArcanumColors.goldLight),
              ),
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 52, 12, 0),
        child: Material(
          color: ArcanumColors.surfaceHigh.withValues(alpha: .96),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: const Text(
                    'Cómo se usa la mesa',
                    style: TextStyle(
                      fontSize: 17,
                      letterSpacing: .8,
                      color: ArcanumColors.goldLight,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const _Gesture(
                  'Tocar',
                  'Hace lo evidente: extiende el mazo, desvela una carta de la tirada o devuelve una suelta a su montón.',
                ),
                const _Gesture(
                  'Mantener',
                  'Abre el menú de lo que tocas. Desliza hasta la opción y suelta.',
                ),
                const _Gesture(
                  'Arrastrar el paño',
                  'Gira e inclina la mesa. Pellizca para acercarte.',
                ),
                const _Gesture(
                  'Esquina',
                  'Levanta la esquina de una carta para voltearla. El doble toque también la desvela.',
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _timer,
                        builder: (context, _) => LinearProgressIndicator(
                          value: 1 - _timer.value,
                          minHeight: 2,
                          color: ArcanumColors.goldMuted,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _close,
                      child: const Text('Entendido'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Gesture extends StatelessWidget {
  const _Gesture(this.name, this.text);
  final String name;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$name  ',
            style: const TextStyle(
              color: ArcanumColors.gold,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: text),
        ],
      ),
      style: const TextStyle(
        fontSize: 13.5,
        height: 1.4,
        color: ArcanumColors.ivory,
      ),
    ),
  );
}

/// Deshacer, en la esquina de abajo a la izquierda: nunca tapa cartas. El
/// anillo se consume en el tiempo que queda para poder deshacer.
class UndoDot extends StatefulWidget {
  const UndoDot({super.key, required this.until, required this.onUndo});

  /// Hasta cuando se ofrece. null: no se enseña.
  final DateTime? until;
  final VoidCallback onUndo;

  @override
  State<UndoDot> createState() => _UndoDotState();
}

class _UndoDotState extends State<UndoDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ring;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(vsync: this)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) setState(() {});
      });
    _start();
  }

  @override
  void didUpdateWidget(UndoDot old) {
    super.didUpdateWidget(old);
    if (old.until != widget.until) _start();
  }

  void _start() {
    final until = widget.until;
    if (until == null) {
      _ring.stop();
      return;
    }
    final left = until.difference(DateTime.now());
    if (left <= Duration.zero) {
      _ring.value = 1;
      return;
    }
    _ring
      ..duration = left
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.until == null || _ring.isCompleted) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Semantics(
          label: 'Deshacer',
          button: true,
          child: GestureDetector(
            onTap: widget.onUndo,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ArcanumColors.surfaceHigh.withValues(alpha: .92),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _ring,
                    builder: (context, _) => SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: 1 - _ring.value,
                        strokeWidth: 2,
                        color: ArcanumColors.gold,
                      ),
                    ),
                  ),
                  const TableIcon(
                    'undo',
                    color: ArcanumColors.goldLight,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
