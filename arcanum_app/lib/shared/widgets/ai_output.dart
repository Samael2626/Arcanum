/// Envoltorio de toda salida de IA: el aviso obligatorio y el boton de reportar.
///
/// Existe para que las dos obligaciones vivan en UN solo sitio. Repartidas por
/// cada pantalla, la que se anada manana se olvidara de ponerlas.
///
/// EL AVISO — AI Act (UE) art. 50(1), aplicable desde el 2 de agosto de 2026:
/// hay que informar a la persona de que interactua con un sistema de IA, y el
/// 50(5) fija el plazo: "at the latest at the time of the first interaction or
/// exposure". Por eso va PEGADO al texto y no solo en los Terminos: un aviso
/// aceptado una vez al instalar no acompana a la lectura de dentro de seis
/// meses, y es justo la ficha que se lee sola la que necesita el matiz.
///
/// EL BOTON — politica *AI-Generated Content* de Google Play, literal: "Apps
/// that generate content using AI must contain in-app user reporting or
/// flagging features that allow users to report or flag offensive content to
/// developers without needing to exit the app". Un enlace a correo NO sirve:
/// obliga a salir de la app, que es lo que la politica prohibe.
///
/// Nota sobre el proveedor: ARCANUM sirve con Groq, no con Anthropic. La AUP de
/// Groq no exige este aviso; la obligacion es legal y no contractual, y por eso
/// no desaparece aunque se cambie de proveedor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';

/// Texto del aviso. Igual que la constante del backend (`safety.AI_DISCLOSURE`)
/// a proposito: la persona debe leer lo mismo venga por donde venga.
const String kAiDisclosure =
    'Texto generado con IA a partir de tu carta y del cielo real. Contenido '
    'simbólico y cultural: no sustituye orientación médica, psicológica, legal '
    'ni financiera.';

/// Motivos de reporte. Cerrados a proposito: texto libre sin acotar seria otro
/// campo que moderar, y la persona que reporta quiere terminar rapido.
const Map<String, String> kReportReasons = {
  'ofensivo': 'Ofensivo o de mal gusto',
  'peligroso': 'Peligroso o dañino',
  'salud': 'Da consejo médico o de salud',
  'incorrecto': 'Es incorrecto o no encaja con mi carta',
  'otro': 'Otro motivo',
};

class AiOutput extends ConsumerWidget {
  const AiOutput({
    super.key,
    required this.text,
    required this.surface,
    this.child,
  });

  /// El texto generado. Se usa para el fragmento del reporte.
  final String text;

  /// De donde sale: 'oraculo', 'horoscopo', 'tarot'. Va al reporte para poder
  /// distinguir que superficie falla sin tener que adivinarlo.
  final String surface;

  /// Como se pinta el texto. Si es null se pinta llano: asi una pantalla puede
  /// conservar su presentacion y seguir teniendo aviso y boton.
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        child ?? Text(text, style: ArcanumText.body(16)),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                kAiDisclosure,
                style: ArcanumText.body(11, color: ArcanumColors.ivoryMuted),
              ),
            ),
            const SizedBox(width: 8),
            _ReportButton(text: text, surface: surface),
          ],
        ),
      ],
    );
  }
}

class _ReportButton extends ConsumerWidget {
  const _ReportButton({required this.text, required this.surface});

  final String text;
  final String surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: 'Reportar este texto',
      child: IconButton(
        icon: const Icon(Icons.flag_outlined, size: 18),
        color: ArcanumColors.ivoryMuted,
        tooltip: 'Reportar este texto',
        onPressed: () => showReportSheet(
          context: context,
          ref: ref,
          text: text,
          surface: surface,
        ),
      ),
    );
  }
}

/// Hoja de reporte. Publica para poder abrirla desde un menu contextual, no
/// solo desde el icono.
Future<void> showReportSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String text,
  required String surface,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ArcanumColors.surface,
    builder: (_) => _ReportSheet(text: text, surface: surface, ref: ref),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.text,
    required this.surface,
    required this.ref,
  });

  final String text;
  final String surface;
  final WidgetRef ref;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _reason;
  final _note = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reason == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.ref.read(arcanumApiProvider).reportContent(
            surface: widget.surface,
            reason: _reason!,
            excerpt: widget.text,
            note: _note.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gracias. Lo revisaremos.')),
      );
    } catch (_) {
      // Sin traza cruda en pantalla: no le dice nada a quien lee y expone
      // detalle del servidor. El motivo concreto vive en el log.
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'No se pudo enviar el reporte. Inténtalo de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Reportar este texto', style: ArcanumText.heading(18)),
          const SizedBox(height: 6),
          Text(
            'Nos ayuda a corregir lo que el modelo no debería haber escrito.',
            style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
          ),
          const SizedBox(height: 14),
          // Seleccion propia en vez de RadioListTile: el widget de Material
          // esta deprecado desde 3.32 y el repo no usa radios en ningun otro
          // sitio, asi que no se hereda una API que ya avisa de su retirada.
          for (final entry in kReportReasons.entries)
            InkWell(
              onTap: _sending ? null : () => setState(() => _reason = entry.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _reason == entry.key
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: _reason == entry.key
                          ? ArcanumColors.gold
                          : ArcanumColors.ivoryMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(entry.value, style: ArcanumText.body(14)),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            enabled: !_sending,
            maxLength: 500,
            maxLines: 3,
            style: ArcanumText.body(14),
            decoration: const InputDecoration(
              hintText: 'Cuéntanos algo más (opcional)',
              counterText: '',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: ArcanumText.body(13, color: ArcanumColors.burgundyLight),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _reason == null || _sending ? null : _send,
            child: Text(_sending ? 'Enviando…' : 'Enviar reporte'),
          ),
        ],
      ),
    );
  }
}
