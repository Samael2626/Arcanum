import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import 'gold_button.dart';

/// Invitación a iniciar sesión para pantallas que requieren cuenta.
class LoginPrompt extends StatelessWidget {
  final String glyph;
  final String title;
  final String description;
  const LoginPrompt({
    super.key,
    required this.glyph,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(glyph, style: const TextStyle(fontSize: 60, color: ArcanumColors.goldMuted)),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: ArcanumText.heading(30)),
            const SizedBox(height: 12),
            Text(description,
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
