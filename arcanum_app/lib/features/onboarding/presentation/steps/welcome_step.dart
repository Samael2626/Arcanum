import 'package:flutter/material.dart';

import '../../../../core/theme/arcanum_colors.dart';
import '../../../../core/theme/arcanum_theme.dart';
import '../../../../shared/widgets/gold_button.dart';

class WelcomeStep extends StatelessWidget {
  final VoidCallback onNext;
  const WelcomeStep({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 48),
          const Center(
            child: Text('⛧',
                style: TextStyle(fontSize: 56, color: ArcanumColors.gold)),
          ),
          const SizedBox(height: 18),
          Text('Bienvenido a tu grimorio',
              textAlign: TextAlign.center,
              style: ArcanumText.heading(26)),
          const SizedBox(height: 14),
          Center(
            child: Container(
              width: 2,
              height: 60,
              color: ArcanumColors.goldMuted.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Has cruzado el umbral. Guardaremos tu nombre y los astros de tu nacimiento para guiar tu práctica.',
            style: ArcanumText.body(17,
                italic: true, color: ArcanumColors.ivoryMuted),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          GoldButton(label: 'Comenzar', onPressed: onNext),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
