/// Consentimiento para mandar datos personales a un proveedor de IA de terceros.
///
/// POR QUE ES UNA PANTALLA Y NO UNA LINEA EN LOS TERMINOS:
///
/// - Apple 5.1.2(i), desde el 13-nov-2025: "You must clearly disclose where
///   personal data will be shared with third parties, including with
///   third-party AI, and obtain explicit permission before doing so".
/// - Google Play, anuncio del 15-jul-2026: las integraciones con IA de terceros
///   quedan sujetas a los requisitos de User Data.
/// - GDPR art. 9(1) leido con C-184/20 y las Directrices CEPD 8/2020: una app
///   de practica magica trata datos que REVELAN convicciones filosoficas o
///   religiosas, aunque la persona no las declare. Eso es categoria especial y
///   pide consentimiento explicito del art. 9(2)(a), separado del general.
/// - Ley 1581/2012 (Colombia) arts. 5, 6 y 9: los datos que revelan
///   convicciones son sensibles; su tratamiento exige autorizacion explicita, y
///   hay un deber correlativo de INFORMAR que no esta obligado a darla.
///
/// De ahi las dos casillas separadas y ninguna premarcada. Marcar por defecto
/// no es consentimiento: es la ausencia de una negativa.
///
/// EL PROVEEDOR ES GROQ. No Anthropic. El fichero del backend se llama
/// `claude_service.py` por herencia, y ese nombre ya indujo el error una vez en
/// la investigacion legal. Nombrar aqui a la empresa equivocada seria decirle a
/// la persona que sus datos van a donde no van.
///
/// LIMITACION DECLARADA: la aceptacion se guarda en el dispositivo. Sirve para
/// no volver a preguntar y para saber que version se acepto, pero NO es prueba
/// auditable — se pierde al desinstalar y no se puede consultar desde el
/// servidor. Una prueba de verdad necesita columnas en `users` y su migracion.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/arcanum_colors.dart';
import '../theme/arcanum_theme.dart';

/// Tercero real al que viajan los datos.
const String kAiProvider = 'Groq, Inc.';
const String kAiProviderCountry = 'Estados Unidos';

/// Version del texto aceptado. Si cambia lo que se le cuenta a la persona, esto
/// sube y se vuelve a preguntar: un consentimiento es para lo que se leyo.
const int kConsentVersion = 1;

const _kAcceptedVersion = 'ai_consent_version';
const _kAcceptedAt = 'ai_consent_at';
const _kSensitive = 'ai_consent_sensitive';

class AiConsent {
  const AiConsent._();

  /// Hay que preguntar? True tambien cuando la version subio.
  static Future<bool> isPending() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_kAcceptedVersion) ?? 0) < kConsentVersion;
  }

  static Future<void> accept({required bool sensitive}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAcceptedVersion, kConsentVersion);
    await prefs.setString(_kAcceptedAt, DateTime.now().toUtc().toIso8601String());
    await prefs.setBool(_kSensitive, sensitive);
  }

  /// Para poder mostrarlo en Ajustes y para revocar.
  static Future<Map<String, Object?>> current() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'version': prefs.getInt(_kAcceptedVersion) ?? 0,
      'at': prefs.getString(_kAcceptedAt),
      'sensitive': prefs.getBool(_kSensitive) ?? false,
    };
  }

  static Future<void> revoke() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAcceptedVersion);
    await prefs.remove(_kAcceptedAt);
    await prefs.remove(_kSensitive);
  }
}

/// La persona no dio (o retiro) el permiso. No es un error tecnico: es una
/// respuesta valida, y la pantalla debe tratarla como tal en vez de enseniar
/// "no se pudo conectar", que seria mentir sobre lo que paso.
class ConsentDeclined implements Exception {
  const ConsentDeclined();
  @override
  String toString() => 'ConsentDeclined';
}

/// Pide el consentimiento si hace falta. Devuelve true si se puede continuar.
///
/// Se llama ANTES de la primera consulta que manda datos fuera. Si la persona
/// cierra sin aceptar, devuelve false y la consulta NO se hace: es la
/// diferencia entre pedir permiso y avisar de que ya se hizo.
Future<bool> ensureAiConsent(BuildContext context) async {
  if (!await AiConsent.isPending()) return true;
  if (!context.mounted) return false;
  final aceptado = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ConsentDialog(),
  );
  return aceptado ?? false;
}

class _ConsentDialog extends StatefulWidget {
  const _ConsentDialog();

  @override
  State<_ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<_ConsentDialog> {
  // Ninguna premarcada, a proposito.
  bool _envio = false;
  bool _sensible = false;

  @override
  Widget build(BuildContext context) {
    // Las dos son necesarias: sin la primera no hay a donde mandar la consulta,
    // y sin la segunda no hay base juridica para tratar el dato que revela
    // convicciones. Se piden por separado porque son cosas distintas.
    final puede = _envio && _sensible;

    return AlertDialog(
      backgroundColor: ArcanumColors.surface,
      title: Text('Antes de tu primera lectura', style: ArcanumText.heading(19)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Para escribir tu lectura, ARCANUM envía tu fecha, hora y lugar de '
              'nacimiento —y el texto de tu consulta— a $kAiProvider, un '
              'proveedor de inteligencia artificial en $kAiProviderCountry. '
              'Sin ese envío no hay lectura interpretada.',
              style: ArcanumText.body(14),
            ),
            const SizedBox(height: 14),
            _Check(
              value: _envio,
              onChanged: (v) => setState(() => _envio = v),
              label: 'Autorizo el envío de esos datos a $kAiProvider '
                  '($kAiProviderCountry).',
            ),
            const SizedBox(height: 10),
            _Check(
              value: _sensible,
              onChanged: (v) => setState(() => _sensible = v),
              label: 'Entiendo que mi práctica —tradición, rituales, carta— '
                  'puede revelar convicciones filosóficas o religiosas, y '
                  'autorizo expresamente su tratamiento.',
            ),
            const SizedBox(height: 12),
            // Deber de informacion del art. 6 de la Ley 1581: hay que decirle
            // que puede negarse.
            Text(
              'No estás obligado a autorizar el tratamiento de datos sensibles. '
              'Puedes revocarlo cuando quieras desde Ajustes; en ese caso no '
              'podremos generar lecturas interpretadas.',
              style: ArcanumText.body(12, color: ArcanumColors.ivoryMuted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Ahora no'),
        ),
        FilledButton(
          onPressed: puede
              ? () async {
                  await AiConsent.accept(sensitive: true);
                  if (context.mounted) Navigator.of(context).pop(true);
                }
              : null,
          child: const Text('Acepto'),
        ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            value ? Icons.check_box : Icons.check_box_outline_blank,
            size: 22,
            color: value ? ArcanumColors.gold : ArcanumColors.ivoryMuted,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: ArcanumText.body(13))),
        ],
      ),
    );
  }
}
