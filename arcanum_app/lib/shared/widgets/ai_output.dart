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
/// Version larga: se muestra UNA vez por sesion, la primera vez que la persona
/// ve texto generado. El art. 50(5) del AI Act pide la informacion "at the
/// latest at the time of the first interaction or exposure" — o sea la primera,
/// no todas. Repetirla bajo cada parrafo no cumple mas y se deja de leer.
const String kAiDisclosure =
    'Los textos de ARCANUM los redacta una inteligencia artificial a partir de '
    'tu carta y del cielo real. Son contenido simbólico y cultural.';

/// Version corta: la que acompana a cada texto a partir de la segunda vez.
const String kAiDisclosureShort = 'Generado con IA';

/// Recordatorio de salud de Google Play: "Apps must also remind users to
/// consult a healthcare professional". Solo cuando se nombra una planta.
const String kHealthReminder = 'No sustituye atención médica';

/// Ya se enseno el aviso largo en esta sesion?
bool _disclosureShown = false;

/// Solo para los tests: devuelve la sesion a su estado inicial.
void resetDisclosureForTest() => _disclosureShown = false;

/// Aviso de practica, en DOS niveles. Aparece solo cuando el texto nombra una
/// planta, para que no se vuelva ruido de fondo que nadie lee.
///
/// ARCANUM decide a proposito NO amputar el lenguaje ritual ni el de las
/// infusiones corrientes: ungir, ahumar, banar, ofrendar y tomarse un te de
/// manzanilla son la practica misma, y un guardarrail que los bloquease
/// vaciaria el producto. La contrapartida es avisar bien, y "bien" significa
/// distinto segun la planta.
///
/// El corte NO es "hierba si / hierba no". Es toxicidad:
///
///  - Manzanilla, tilo, menta o jengibre son alimentos. Se venden en cualquier
///    supermercado y beberlos no es un riesgo. Lo unico que hay que decir es
///    que acompanan, no tratan, y que no sustituyen a un profesional — que es
///    ademas lo que exige literalmente Google Play ("Apps must also remind
///    users to consult a healthcare professional").
///  - Aconito, beleno, mandragora, belladona, digital, cicuta y estramonio son
///    venenos reales que la tradicion nombra sin avisar. Aqui el riesgo no es
///    una multa: es una intoxicacion, y el aviso tiene que ser tajante.
///
/// Si el texto nombra de los dos tipos, manda el tajante.
const String kToxicNotice =
    'Varias de las plantas que nombra la tradición son tóxicas. Aquí se citan '
    'como correspondencias simbólicas: no las ingieras ni las apliques sobre '
    'la piel.';

// El aviso culinario largo se retiro: su contenido util —el recordatorio de
// consultar a un profesional, que Google Play exige— cabe en el pie como
// `kHealthReminder`. Un parrafo entero para una manzanilla era ruido, y el
// ruido se deja de leer justo cuando aparece el aviso que si importa.

/// Las que de verdad envenenan. La lista es corta a proposito: cada nombre de
/// aqui es una planta que puede matar, no una que "conviene vigilar".
const List<String> kToxicBotanicals = [
  'acónito', 'aconito', 'beleño', 'beleno', 'mandrágora', 'mandragora',
  'belladona', 'cicuta', 'estramonio', 'digital', 'dedalera',
  'tejo', 'adelfa', 'ruda', 'ajenjo', 'poleo', 'muérdago', 'muerdago',
];

/// Alimentos. Nombrarlas o beberlas no es un riesgo; el aviso solo recuerda
/// que acompanan y no tratan.
const List<String> kCulinaryBotanicals = [
  'manzanilla', 'tilo', 'menta', 'hierbabuena', 'jengibre', 'romero',
  'laurel', 'salvia', 'lavanda', 'canela', 'tomillo', 'melisa', 'anís',
  'anis', 'valeriana', 'té', 'infusión', 'infusion', 'tisana', 'hierba',
];

/// Busca la planta como PALABRA ENTERA, no como subcadena.
///
/// Comparar subcadenas producia falsos positivos absurdos que se vieron en el
/// telefono: "te" casa dentro de "estetica", "menta" dentro de "alimenta" y
/// "mentalidad", "tilo" dentro de "estilo". Un horoscopo que hablaba de una
/// "proyeccion estetica" acababa con un recordatorio de atencion medica al pie.
///
/// Y eso no es un detalle cosmetico: un aviso que salta cuando no toca ensena a
/// la persona a ignorarlo, y entonces tampoco lo lee el dia que la planta es
/// beleno de verdad.
bool _nombra(String texto, List<String> plantas) {
  final t = texto.toLowerCase();
  for (final planta in plantas) {
    //  no funciona con acentos en Dart, asi que el limite se expresa como
    // "no hay letra pegada", incluyendo las acentuadas del espanol.
    const letra = r'[a-záéíóúüñ]';
    final re = RegExp('(?<!$letra)${RegExp.escape(planta)}(?!$letra)');
    if (re.hasMatch(t)) return true;
  }
  return false;
}

/// Aviso duro si el texto nombra un veneno real, o null. Este NO se acorta.
String? toxicNoticeFor(String text) =>
    _nombra(text, kToxicBotanicals) ? kToxicNotice : null;

/// El texto nombra una planta corriente (manzanilla, tilo, romero)? Con eso
/// basta para anadir el recordatorio de salud al pie, sin un parrafo aparte.
bool mentionsCulinary(String text) => _nombra(text, kCulinaryBotanicals);

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
    // El aviso largo solo la primera vez que se ve texto generado en esta
    // sesion; despues, una linea gris. Cumple el 50(5) igual y deja de ser un
    // muro que nadie lee.
    final primeraVez = !_disclosureShown;
    if (primeraVez) _disclosureShown = true;

    final toxico = toxicNoticeFor(text);
    final nombraPlanta = toxico != null || mentionsCulinary(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        child ?? Text(text, style: ArcanumText.body(16)),
        const SizedBox(height: 10),
        if (primeraVez) ...[
          Text(
            kAiDisclosure,
            style: ArcanumText.body(11, color: ArcanumColors.ivoryMuted),
          ),
          const SizedBox(height: 6),
        ],
        // El aviso duro NO se acorta ni se esconde: aqui el riesgo no es una
        // multa, es una intoxicacion.
        if (toxico != null) ...[
          Text(
            toxico,
            style: ArcanumText.body(11, color: ArcanumColors.burgundyLight),
          ),
          const SizedBox(height: 6),
        ],
        _PiePie(
          text: text,
          surface: surface,
          conPlanta: nombraPlanta && toxico == null,
        ),
      ],
    );
  }
}

/// La linea de pie: lo obligatorio en una sola linea gris.
///
/// "Generado con IA" cubre el art. 50(1) a partir de la segunda vez.
/// "Reportar" cubre el requisito de Google Play, que exige que la funcion
/// EXISTA sin salir de la app, no que haya un icono bajo cada parrafo.
/// El recordatorio de salud solo aparece cuando el texto nombra una planta.
class _PiePie extends ConsumerWidget {
  const _PiePie({
    required this.text,
    required this.surface,
    required this.conPlanta,
  });

  final String text;
  final String surface;
  final bool conPlanta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estilo = ArcanumText.body(11, color: ArcanumColors.ivoryMuted);
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(kAiDisclosureShort, style: estilo),
        if (conPlanta) ...[
          Text('·', style: estilo),
          Text(kHealthReminder, style: estilo),
        ],
        Text('·', style: estilo),
        InkWell(
          onTap: () => showReportSheet(
            context: context,
            ref: ref,
            text: text,
            surface: surface,
          ),
          child: Text(
            'Reportar',
            style: ArcanumText.body(11, color: ArcanumColors.goldMuted),
          ),
        ),
      ],
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
