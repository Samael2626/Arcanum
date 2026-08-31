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
              const _PolicyCard(
                title: 'QUÉ CUSTODIAMOS',
                body:
                    'Tu cuenta, el perfil natal, las tiradas, las conversaciones '
                    'con el Oráculo, el grimorio y el saldo de créditos. Nada más: '
                    'ARCANUM no pide tu ubicación ni lee tus contactos, fotos o '
                    'archivos.',
              ),
              const SizedBox(height: 16),
              // El cifrado no es uniforme y la politica lo dice con estas mismas
              // palabras. Prometer aqui mas de lo que hace el codigo seria la
              // infraccion; que las tres piezas digan lo mismo es el requisito.
              const _PolicyCard(
                title: 'QUÉ VA CIFRADO Y QUÉ NO',
                body:
                    'El cuerpo de cada entrada del grimorio se cifra en tu '
                    'dispositivo y su clave nunca sale de él: el servidor guarda '
                    'texto que no puede leer. El título y las etiquetas, no. La '
                    'pregunta de una tirada, sí. Las conversaciones con el '
                    'Oráculo se guardan en claro para poder mostrarte tu '
                    'historial. Tenlo en cuenta al escribir.',
              ),
              const SizedBox(height: 16),
              const _PolicyCard(
                title: 'DATOS SENSIBLES',
                body:
                    'Lo que preguntas puede revelar creencias religiosas o '
                    'filosóficas. La ley las protege de forma especial, así que '
                    'se piden aparte y puedes usar ARCANUM sin concederlas. '
                    'Puedes retirar el permiso cuando quieras desde Ajustes.',
              ),
              const SizedBox(height: 16),
              const _PolicyCard(
                title: 'SERVICIOS EXTERNOS',
                body:
                    'Groq genera las lecturas y recibe tu pregunta y las cartas, '
                    'nunca tu correo ni tu grimorio. Railway aloja la base de '
                    'datos. RevenueCat y la tienda procesan las compras; tu '
                    'tarjeta no pasa por nosotros. Firebase recoge fallos y uso. '
                    'Todos tratan datos en Estados Unidos, con cláusulas '
                    'contractuales tipo.',
              ),
              const SizedBox(height: 16),
              const _PolicyCard(
                title: 'SIN ANUNCIOS',
                body:
                    'Esta versión no muestra publicidad y no recoge tu '
                    'identificador de anuncios. ARCANUM se financia con '
                    'suscripciones y créditos.',
              ),
              const SizedBox(height: 16),
              const _PolicyCard(
                title: 'TUS DERECHOS',
                body:
                    'Puedes pedir acceso, corrección, borrado, portabilidad u '
                    'oposición escribiendo a arcanum.magick.app@gmail.com desde '
                    'el correo de tu cuenta. Respondemos en diez días hábiles en '
                    'Colombia y en un mes en Europa y el Reino Unido.',
              ),
              const SizedBox(height: 16),
              const _PolicyCard(
                title: 'ELIMINAR TU CUENTA',
                body:
                    'En Ajustes, toca “Eliminar cuenta y datos” y escribe '
                    'ELIMINAR. Se borran la cuenta, el perfil natal, el grimorio, '
                    'las tiradas y las conversaciones. Los apuntes de crédito se '
                    'conservan cinco años porque respaldan un pago. Cancelar una '
                    'suscripción activa es un paso aparte, en la tienda: borrar '
                    'la cuenta no detiene el cobro.',
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
                onPressed: () => _copyUrl(context, ReleaseConfig.termsUrl),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copiar términos de servicio'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    _copyUrl(context, ReleaseConfig.accountDeletionUrl),
                icon: const Icon(Icons.person_remove_outlined),
                label: const Text('Copiar enlace de eliminación externa'),
              ),
              const SizedBox(height: 24),
              Text(
                'Política vigente: versión ${ReleaseConfig.policyVersion}.',
                textAlign: TextAlign.center,
                style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
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
