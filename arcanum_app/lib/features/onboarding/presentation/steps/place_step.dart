import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/arcanum_colors.dart';
import '../../../../core/theme/arcanum_theme.dart';
import '../../../../shared/widgets/arcanum_field.dart';
import '../../../../shared/widgets/gold_button.dart';
import '../../application/onboarding_controller.dart';

class PlaceStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const PlaceStep(
      {super.key, required this.onNext, required this.onBack});

  @override
  ConsumerState<PlaceStep> createState() => _PlaceStepState();
}

class _PlaceStepState extends ConsumerState<PlaceStep> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: ref.read(onboardingProvider).data.birthPlace ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _finalizar() async {
    final v = _ctrl.text.trim();
    if (v.isNotEmpty) {
      await ref.read(onboardingProvider.notifier).setBirthPlace(v);
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
          Text('Lugar de nacimiento',
              style: ArcanumText.heading(24)),
          const SizedBox(height: 12),
          Text('Ciudad y país. Lo afinaremos luego con coordenadas precisas.',
              style: ArcanumText.body(15,
                  color: ArcanumColors.ivoryMuted)),
          const SizedBox(height: 28),
          ArcanumField(
            controller: _ctrl,
            label: 'Ciudad, país',
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
            Expanded(child: GoldButton(label: 'Finalizar', onPressed: _finalizar)),
          ]),
        ],
      ),
    );
  }
}
