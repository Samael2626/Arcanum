import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/widgets/arcanum_card.dart';
import '../../shared/widgets/gold_button.dart';
import 'residence_card.dart';

/// "Perfil": la casa del "quién soy".
///
/// Se abre desde el avatar de la barra superior, presente en todas las
/// pantallas. Hoy guarda tu identidad y la puerta a Ajustes; cuando llegue el
/// camino guiado (racha, progreso, lecciones) vivirá aquí sin rediseñar nada.
class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final name = (user?['display_name'] as String?)?.trim();
    final email = (user?['email'] as String?)?.trim();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: ArcanumColors.background,
        title: Text('Perfil', style: ArcanumText.heading(24)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              if (auth.isAuthenticated) ...[
                _Identity(name: name, email: email),
                const SizedBox(height: 20),
                const ResidenceCard(),
                const SizedBox(height: 20),
                const _CaminoCard(),
                const SizedBox(height: 20),
                _actions(context, ref),
              ] else
                _SignedOut(onLogin: () => context.go('/login')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, WidgetRef ref) {
    return ArcanumCard(
      intensity: 0.35,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        children: [
          _row(
            icon: Icons.settings_outlined,
            label: 'Ajustes',
            hint: 'Cuenta, custodia y zona irreversible',
            onTap: () => context.push('/settings'),
          ),
          const Divider(height: 1, color: ArcanumColors.surfaceHigh),
          _row(
            icon: Icons.logout,
            label: 'Cerrar sesión',
            onTap: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String label,
    String? hint,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: ArcanumColors.gold),
      title: Text(label, style: ArcanumText.body(17)),
      subtitle: hint == null
          ? null
          : Text(
              hint,
              style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
            ),
      trailing: const Icon(
        Icons.chevron_right,
        color: ArcanumColors.ivoryMuted,
      ),
      onTap: onTap,
    );
  }
}

class _Identity extends StatelessWidget {
  final String? name;
  final String? email;
  const _Identity({this.name, this.email});

  @override
  Widget build(BuildContext context) {
    final display = (name != null && name!.isNotEmpty) ? name! : 'Practicante';
    final initial = display.substring(0, 1).toUpperCase();
    return ArcanumCard(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ArcanumColors.gold, width: 1.4),
              gradient: RadialGradient(
                colors: [
                  ArcanumColors.gold.withValues(alpha: 0.20),
                  Colors.transparent,
                ],
              ),
            ),
            child: Text(
              initial,
              style: ArcanumText.heading(30, color: ArcanumColors.gold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(display, style: ArcanumText.heading(24)),
                if (email != null && email!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email!,
                    style: ArcanumText.body(
                      14,
                      color: ArcanumColors.ivoryMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Semilla del camino guiado. Aún no hay juego, pero el sitio ya existe: cuando
/// lleguen racha y lecciones, aterrizan aquí sin mover nada de su lugar.
class _CaminoCard extends StatelessWidget {
  const _CaminoCard();

  @override
  Widget build(BuildContext context) {
    return ArcanumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('TU CAMINO'),
          const SizedBox(height: 12),
          Text(
            'Aquí verás tu progreso: lo que has aprendido, lo que sigue y tu '
            'constancia.',
            style: ArcanumText.body(16),
          ),
          const SizedBox(height: 10),
          Text(
            'Pronto — estamos tejiendo las primeras lecciones.',
            style: ArcanumText.body(
              14,
              color: ArcanumColors.ivoryMuted,
              italic: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  final VoidCallback onLogin;
  const _SignedOut({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return ArcanumCard(
      child: Column(
        children: [
          Text(
            'Cruza el umbral',
            style: ArcanumText.heading(24, color: ArcanumColors.gold),
          ),
          const SizedBox(height: 10),
          Text(
            'Inicia sesión para guardar tu carta, tu grimorio y tu camino.',
            textAlign: TextAlign.center,
            style: ArcanumText.body(16),
          ),
          const SizedBox(height: 20),
          GoldButton(label: 'Iniciar sesión', onPressed: onLogin),
        ],
      ),
    );
  }
}
