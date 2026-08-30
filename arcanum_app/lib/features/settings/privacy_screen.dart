import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/release_config.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/widgets/arcanum_card.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  Future<void> _copyUrl(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Enlace copiado.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ArcanumColors.background,
        title: Text('Privacidad y datos', style: ArcanumText.heading(24)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              const ArcanumHeader(subtitle: 'Custodia del umbral'),
              const SizedBox(height: 24),
              _PolicyCard(
                title: 'QUÉ CUSTODIAMOS',
                body:
                    'Cuenta, perfil natal, tiradas, conversaciones, saldo y '
                    'actividad necesaria para prestar el servicio. El contenido '
                    'del grimorio viaja cifrado y su clave permanece en tu dispositivo.',
              ),
              const SizedBox(height: 16),
              const _PolicyCard(
                title: 'SERVICIOS EXTERNOS',
                body:
                    'Firebase procesa analítica y fallos; Groq procesa las '
                    'consultas del oráculo; RevenueCat y Google Play procesan '
                    'compras; Google Mobile Ads procesa anuncios y medición.',
              ),
              const SizedBox(height: 16),
              const _PolicyCard(
                title: 'ELIMINAR TU CUENTA',
                body:
                    'En Ajustes, toca “Eliminar cuenta y datos” y escribe '
                    'ELIMINAR. Se borran la cuenta y sus datos asociados. '
                    'Cancelar una suscripción activa se hace por separado en Google Play.',
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () =>
                    _copyUrl(context, ReleaseConfig.privacyPolicyUrl),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copiar política de privacidad'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    _copyUrl(context, ReleaseConfig.accountDeletionUrl),
                icon: const Icon(Icons.person_remove_outlined),
                label: const Text('Copiar enlace de eliminación externa'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ArcanumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(title),
          const SizedBox(height: 12),
          Text(body, style: ArcanumText.body(16)),
        ],
      ),
    );
  }
}
