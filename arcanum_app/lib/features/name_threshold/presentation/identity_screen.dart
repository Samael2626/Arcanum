import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../../shared/widgets/arcanum_card.dart';
import '../../../shared/widgets/gold_button.dart';
import '../application/reading_identity_controller.dart';

class IdentityScreen extends ConsumerWidget {
  const IdentityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName =
        (ref.watch(authProvider).user?['display_name'] as String?)?.trim();
    final readingProfile = ref.watch(readingIdentityProvider);
    final partCount = readingProfile.value?.parts.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: ArcanumColors.background,
        title: Text('Identidad', style: ArcanumText.heading(24)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              const ArcanumHeader(subtitle: 'Lo social y lo íntimo, separados'),
              const SizedBox(height: 24),
              ArcanumCard(
                intensity: 0.35,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('NOMBRE PARA MOSTRAR'),
                    const SizedBox(height: 10),
                    Text(
                      displayName?.isNotEmpty == true
                          ? displayName!
                          : 'Sin nombre para mostrar',
                      style: ArcanumText.heading(22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Uso social de la cuenta. Nunca llena tu nombre de lectura.',
                      style: ArcanumText.body(
                        14,
                        color: ArcanumColors.ivoryMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ArcanumCard(
                frame: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('NOMBRE Y UMBRAL'),
                    const SizedBox(height: 12),
                    Text(
                      partCount == 0
                          ? 'Perfil privado vacío'
                          : '$partCount partes guardadas',
                      style: ArcanumText.heading(23),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Archivo documentado, forma hebrea elegida y cálculo letra por letra. Nada sale de este dispositivo.',
                      style: ArcanumText.body(15),
                    ),
                    const SizedBox(height: 20),
                    GoldButton(
                      label: partCount == 0
                          ? 'Crear perfil privado'
                          : 'Abrir Nombre y Umbral',
                      onPressed: () =>
                          context.push('/perfil/identidad/nombre-y-umbral'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
