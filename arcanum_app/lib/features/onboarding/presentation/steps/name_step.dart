import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/arcanum_colors.dart';
import '../../../../core/theme/arcanum_theme.dart';
import '../../../../shared/widgets/arcanum_field.dart';
import '../../../../shared/widgets/gold_button.dart';
import '../../application/onboarding_controller.dart';

class NameStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const NameStep(
      {super.key, required this.onNext, required this.onBack});

  @override
  ConsumerState<NameStep> createState() => _NameStepState();
}

class _NameStepState extends ConsumerState<NameStep> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: ref.read(onboardingProvider).data.displayName ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _continuar() async {
    final v = _ctrl.text.trim();
    if (v.isNotEmpty) {
      await ref.read(onboardingProvider.notifier).setDisplayName(v);
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
          Text('¿Cómo quieres que te llamemos?',
              style: ArcanumText.heading(24)),
          const SizedBox(height: 12),
          Text('Tu nombre se mostrará en toda la app.',
              style: ArcanumText.body(15,
                  color: ArcanumColors.ivoryMuted)),
          const SizedBox(height: 28),
          ArcanumField(controller: _ctrl, label: 'Nombre'),
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
