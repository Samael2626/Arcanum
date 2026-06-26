import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/arcanum_colors.dart';
import '../../../../core/theme/arcanum_theme.dart';
import '../../../../shared/widgets/arcanum_field.dart';
import '../../../../shared/widgets/gold_button.dart';
import '../../application/onboarding_controller.dart';

class BirthTimeStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const BirthTimeStep(
      {super.key, required this.onNext, required this.onBack});

  @override
  ConsumerState<BirthTimeStep> createState() => _BirthTimeStepState();
}

class _BirthTimeStepState extends ConsumerState<BirthTimeStep> {
  TimeOfDay? _time;
  late final TextEditingController _ctrl;

  static String _pad(int n) => n.toString().padLeft(2, '0');
  static TimeOfDay _parse(String s) {
    final p = s.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  @override
  void initState() {
    super.initState();
    final existing = ref.read(onboardingProvider).data.birthTime;
    if (existing != null && existing.contains(':')) {
      _time = _parse(existing);
      _ctrl = TextEditingController(text: existing);
    } else {
      _ctrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 12, minute: 0),
    );
    if (t != null) {
      setState(() {
        _time = t;
        _ctrl.text = '${_pad(t.hour)}:${_pad(t.minute)}';
      });
    }
  }

  Future<void> _continuar() async {
    if (_time != null) {
      final v = '${_pad(_time!.hour)}:${_pad(_time!.minute)}';
      await ref.read(onboardingProvider.notifier).setBirthTime(v);
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text('Hora de nacimiento',
              style: ArcanumText.heading(24)),
          const SizedBox(height: 12),
          Text('Las horas planetarias exactas requieren hora local del lugar.',
              style: ArcanumText.body(15,
                  color: ArcanumColors.ivoryMuted)),
          const SizedBox(height: 28),
          ArcanumField(
            controller: _ctrl,
            label: 'Hora (HH:mm)',
            readOnly: true,
            onTap: _pick,
          ),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onBack,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: ArcanumColors.ivoryMuted),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: Text('Atrás',
                    style: ArcanumText.heading(18,
                        color: ArcanumColors.ivoryMuted)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: GoldButton(label: 'Siguiente', onPressed: _continuar)),
          ]),
        ],
      ),
    );
  }
}
