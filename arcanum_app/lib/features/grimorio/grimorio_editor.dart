import 'grimorio_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/astro/user_place.dart';
import '../../core/crypto/grimoire_crypto.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/widgets/arcanum_field.dart';
import '../../shared/widgets/arcanum_mood.dart';
import '../../shared/widgets/arcanum_resin.dart';
import '../../shared/widgets/gold_button.dart';
import '../sigilos/compare_screen.dart';
import '../sigilos/kamea_screen.dart';
import '../sigilos/personal_screen.dart';
import '../sigilos/rosa_screen.dart';
import '../sigilos/taller_screen.dart';
import 'grimorio_atmosphere.dart';

class GrimorioEditor extends ConsumerStatefulWidget {
  const GrimorioEditor({super.key, this.initialTitle});

  /// Titulo de partida (p. ej. el nombre de una planta desde Saber). El titulo
  /// viaja en claro; el contenido se cifra igual que siempre al sellar.
  final String? initialTitle;

  @override
  ConsumerState<GrimorioEditor> createState() => _GrimorioEditorState();
}

class _GrimorioEditorState extends ConsumerState<GrimorioEditor> {
  late final _title = TextEditingController(text: widget.initialTitle);
  final _content = TextEditingController();
  String _type = 'note';
  bool _saving = false;
  bool _sealing = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _content.text.trim().isEmpty) {
      setState(
        () => _error = 'El título y el contenido son necesarios para sellar.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final api = ref.read(arcanumApiProvider);
    try {
      final enc = await ref
          .read(grimoireCryptoProvider)
          .encryptText(_content.text);

      // Captura el contexto astral del momento (best-effort).
      String? moonPhase, planetaryHour, dayPlanet;
      try {
        final place = ref.read(userPlaceProvider);
        if (place == null) {
          // Sin lugar confirmado la luna sigue siendo cierta; la hora y el
          // regente no. Quedan ausentes en la entrada, no inventados.
          moonPhase = (await api.moon())['phase_name'] as String?;
        } else {
          final today = await api.today(lat: place.lat, lon: place.lon);
          moonPhase = today['moon']?['phase_name'] as String?;
          planetaryHour = today['planetary_hour']?['planet'] as String?;
          dayPlanet = today['day_ruler'] as String?;
        }
      } catch (error) {
        // Best-effort de verdad: la entrada se guarda igual, solo pierde la
        // anotación astral. Pero deja rastro: si /astral/today se rompiera,
        // TODAS las entradas quedarían sin contexto y nadie se enteraría hasta
        // mirar el grimorio meses después.
        debugPrint(
          'ARCANUM grimorio: sin contexto astral para esta entrada ($error).',
        );
      }

      await api.grimoireCreate({
        'entry_type': _type,
        'title': _title.text.trim(),
        'encrypted_content': enc.ciphertext,
        'content_iv': enc.iv,
        'moon_phase': moonPhase,
        'planetary_hour': planetaryHour,
        'day_planet': dayPlanet,
        'entry_date': DateTime.now().toUtc().toIso8601String(),
      });
      // Guardado OK → estampa el sello y luego cierra.
      if (mounted) setState(() => _sealing = true);
    } catch (e) {
      // El error de verdad va al log SIEMPRE. Antes se perdia entero: el
      // usuario veia «revisa tu conexion» y quien tenia que arreglarlo no
      // veia nada.
      debugPrint('ARCANUM grimorio: fallo al sellar la entrada ($e).');
      if (mounted) {
        setState(() {
          _error = mensajeAlSellar(e);
          _saving = false;
        });
      }
    }
  }

  Future<void> _openTaller() async {
    // navegador raiz: el taller ocupa la pantalla entera, sin la cabecera
    // del Grimorio encima (le quitaba ~85 dp al lienzo)
    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(MaterialPageRoute(builder: (_) => const TallerScreen()));
    if (mounted && saved == true) Navigator.pop(context, true);
  }

  Future<void> _openKamea() async {
    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(MaterialPageRoute(builder: (_) => const KameaScreen()));
    if (mounted && saved == true) Navigator.pop(context, true);
  }

  Future<void> _openRosa() async {
    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(MaterialPageRoute(builder: (_) => const RosaScreen()));
    if (mounted && saved == true) Navigator.pop(context, true);
  }

  Future<void> _openPersonal() async {
    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(MaterialPageRoute(builder: (_) => const PersonalScreen()));
    if (mounted && saved == true) Navigator.pop(context, true);
  }

  Future<void> _openCompare() async {
    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(MaterialPageRoute(builder: (_) => const CompareScreen()));
    if (mounted && saved == true) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('Nueva entrada', style: ArcanumText.heading(22)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: ArcanumColors.ivoryMuted),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GrimoireSky(intensity: 0.3)),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TypeSelector(
                      value: _type,
                      onChanged: (t) => setState(() => _type = t),
                    ),
                    const SizedBox(height: 18),
                    // un sigilo no se escribe: se forja en el taller, que lo
                    // guarda el mismo como entrada «Sigilo» cifrada
                    if (_type == 'sigil')
                      Expanded(child: _SigilInvite(onOpen: _openTaller, onKamea: _openKamea, onRosa: _openRosa, onPersonal: _openPersonal, onCompare: _openCompare))
                    else ...[
                      ArcanumField(controller: _title, label: 'Título'),
                      const SizedBox(height: 16),
                      Expanded(child: _WritingPage(controller: _content)),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: ArcanumText.body(
                            14,
                            color: ArcanumColors.burgundyLight,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (_type != 'sigil')
                      GoldButton(
                        label: 'Sellar entrada',
                        loading: _saving,
                        onPressed: _save,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_sealing)
            SealStamp(
              onDone: () {
                if (mounted) Navigator.pop(context, true);
              },
            ),
        ],
      ),
    );
  }
}

// ── Selector de tipo: sigilos-chip ──────────────────────────────────────────

class _TypeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _TypeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: entryTypeEs.entries.map((e) {
        final sel = e.key == value;
        return GestureDetector(
          onTap: () => onChanged(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: sel
                  ? ArcanumColors.gold.withValues(alpha: 0.16)
                  : Colors.transparent,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entryTypeGlyph[e.key] ?? '❦',
                  style: TextStyle(
                    fontSize: 14,
                    color: sel ? ArcanumColors.gold : ArcanumColors.ivoryMuted,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  e.value,
                  style: ArcanumText.body(
                    13.5,
                    color: sel ? ArcanumColors.gold : ArcanumColors.ivoryMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Página de escritura: campo sobre la textura del libro ───────────────────

/// El área de escritura como una página real: superficie de pergamino viva con
/// grano + filete dorado + un baseline tenue de renglones, para que redactar se
/// sienta ritual y no un TextField pelado.
class _WritingPage extends StatelessWidget {
  final TextEditingController controller;
  const _WritingPage({required this.controller});

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(14);
    return Container(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(
          children: [
            const Positioned.fill(
              child: ArcanumResin(mood: ArcanumMood.neutral, intensity: 0.55),
            ),
            // Filete superior dorado, como el canto del pliego.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      ArcanumColors.gold.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: TextField(
                controller: controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: ArcanumText.body(16.5).copyWith(height: 1.6),
                cursorColor: ArcanumColors.gold,
                decoration: InputDecoration(
                  isCollapsed: true,
                  hintText:
                      'Escribe tu rito, tu lectura, tu sueño…\nSe cifra en tu dispositivo antes de sellarse.',
                  hintStyle: ArcanumText.body(
                    15,
                    italic: true,
                    color: ArcanumColors.ivoryMuted,
                  ).copyWith(height: 1.6),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SigilInvite extends StatelessWidget {
  final VoidCallback onOpen, onKamea, onRosa, onPersonal, onCompare;
  const _SigilInvite({required this.onOpen, required this.onKamea, required this.onRosa, required this.onPersonal, required this.onCompare});

  @override
  Widget build(BuildContext context) => Center(
        // con tres puertas el invitado no cabe en un movil bajo: se desplaza
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('✦', style: TextStyle(fontSize: 40, color: ArcanumColors.gold.withValues(alpha: .8))),
              const SizedBox(height: 12),
              Text('Un sigilo no se escribe: se forja.', textAlign: TextAlign.center, style: ArcanumText.heading(22)),
              const SizedBox(height: 8),
              Text(
                'En el taller tu intención se reduce a letras y las letras se funden en un signo. Al guardarlo queda aquí, cifrado como el resto de tu grimorio.',
                textAlign: TextAlign.center,
                style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
              ),
              const SizedBox(height: 20),
              GoldButton(label: 'Abrir el taller', onPressed: onOpen),
              const SizedBox(height: 18),
              Text(
                'O traza un nombre sobre una figura histórica, sin ritual de carga: la tabla de Agrippa o el Lamen de la Rosa-Cruz.',
                textAlign: TextAlign.center,
                style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: onKamea,
                style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: ArcanumColors.gold),
                child: const Text('Abrir una kamea'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onRosa,
                style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: ArcanumColors.gold),
                child: const Text('Abrir una Rosa-Cruz'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onPersonal,
                style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: ArcanumColors.gold),
                child: const Text('Crear sello personal'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onCompare,
                style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: ArcanumColors.gold),
                child: const Text('Comparar tres sistemas'),
              ),
            ],
          ),
        ),
      );
}
