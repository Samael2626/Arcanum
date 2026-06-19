import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/arcanum_colors.dart';
import '../../../../core/theme/arcanum_theme.dart';
import '../../../../shared/widgets/arcanum_field.dart';
import '../../../../shared/widgets/gold_button.dart';
import '../../application/onboarding_controller.dart';

class BirthDateStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const BirthDateStep(
      {super.key, required this.onNext, required this.onBack});

  @override
  ConsumerState<BirthDateStep> createState() => _BirthDateStepState();
}

class _BirthDateStepState extends ConsumerState<BirthDateStep> {
  DateTime? _date;
  late final TextEditingController _ctrl;

  static String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  void initState() {
    super.initState();
    _date = ref.read(onboardingProvider).data.birthDate;
    _ctrl = TextEditingController(
      text: _date == null
          ? ''
          : '${_date!.year}-${_pad(_date!.month)}-${_pad(_date!.day)}',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() {
        _date = d;
        _ctrl.text = '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
      });
    }
  }

  Future<void> _continuar() async {
    if (_date != null) {
      await ref.read(onboardingProvider.notifier).setBirthDate(_date!);
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
          Text('Fecha de nacimiento',
              style: ArcanumText.heading(24)),
          const SizedBox(height: 12),
          Text('Los astros requieren precisión.',
              style: ArcanumText.body(15,
                  color: ArcanumColors.ivoryMuted)),
          const SizedBox(height: 28),
          ArcanumField(
            controller: _ctrl,
            label: 'Fecha',
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
