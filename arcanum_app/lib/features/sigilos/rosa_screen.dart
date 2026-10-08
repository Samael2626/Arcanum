// Rosa-Cruz: el nombre en hebreo trazado sobre el Lamen, como en el
// manuscrito F de Mathers. Familia historica aparte del sigilo de letras (no
// hereda el ritual de la magia del caos: sin carga ni olvido). El motor es
// RosaDoc, del paquete arcanum_sigilos, probado contra el prototipo.
import 'dart:convert';

import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/astro/user_place.dart';
import '../../core/crypto/grimoire_crypto.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/widgets/gold_button.dart';
import 'familia_ui.dart';
import 'sigil_store.dart';
import 'taller_fuentes.dart' show Procedencia, etiqueta;
import 'taller_panels.dart' show sectionTitle;

class RosaScreen extends ConsumerStatefulWidget {
  /// Entrada del Grimorio que se sigue editando (null: Rosa-Cruz nueva).
  final String? entryId;
  final RosaDoc? initial;
  const RosaScreen({super.key, this.entryId, this.initial});

  @override
  ConsumerState<RosaScreen> createState() => RosaScreenState();
}

class RosaScreenState extends ConsumerState<RosaScreen> {
  // el panel conserva su estado (y el foco del campo) si cambia de sitio
  final _panelKey = GlobalKey();
  late final RosaDoc doc = widget.initial ?? RosaDoc();
  late final TextEditingController _name = TextEditingController(text: doc.name);
  late final TextEditingController _hebrew = TextEditingController(text: doc.hebrew);
  bool _saving = false, _transparent = false;
  late String? _savedId = widget.entryId;
  String? _savedSnapshot;

  static const _styles = [('pergamino', 'Pergamino'), ('papel', 'Papel'), ('lacre', 'Lacre'), ('oro', 'Oro'), ('burdeos', 'Burdeos'), ('plata', 'Plata')];

  @visibleForTesting
  RosaDoc get debugDoc => doc;

  String get _snap => jsonEncode(doc.toJson());
  bool get _dirty => doc.hebrew.isNotEmpty && _snap != _savedSnapshot;

  @override
  void initState() {
    super.initState();
    if (_savedId != null) _savedSnapshot = _snap;
  }

  @override
  void dispose() {
    _name.dispose();
    _hebrew.dispose();
    super.dispose();
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  void _set(VoidCallback f) => setState(f);

  void _trace() {
    final text = _name.text.trim();
    if (text.isEmpty) {
      _toast('Escribe un nombre.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      doc.setName(text);
      _hebrew.text = doc.hebrew;
    });
    if (doc.hebrew.isEmpty) _toast('Ese nombre no deja ninguna letra hebrea. Escríbelo en hebreo o prueba la otra transcripción.');
  }

  // ── Guardar y compartir ───────────────────────────────────────
  Future<void> _save() async {
    final snapshot = _snap;
    setState(() => _saving = true);
    try {
      final store = SigilStore(ref.read(arcanumApiProvider), ref.read(grimoireCryptoProvider), ref.read(userPlaceProvider));
      _savedId = await store.saveRosa(doc, entryId: _savedId);
      _savedSnapshot = snapshot;
      _toast('Rosa-Cruz guardada en tu Grimorio.');
    } catch (e) {
      debugPrint('ARCANUM rosa: fallo al guardar ($e).');
      _toast('No se pudo guardar. Revisa la conexión e inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share({required bool png}) async {
    final ok = await compartirFamilia(
      png: png,
      transparent: _transparent,
      baseName: 'arcanum-rosa-cruz',
      scene: (t) => doc.scene(transparent: t),
      svg: (t) {
        final keep = doc.transparent;
        doc.transparent = t;
        final out = doc.buildSVG();
        doc.transparent = keep;
        return out;
      },
    );
    if (!ok && mounted) _toast('No se pudo preparar el archivo para compartir.');
  }

  Future<bool> _confirmLeave() async => !_dirty || await confirmarSalida(context, 'Los cambios de esta Rosa-Cruz se perderán.');

  // ── Piezas ────────────────────────────────────────────────────
  Widget _canvas(double side) {
    final s = doc.scene();
    return SizedBox.square(
      dimension: side,
      child: Semantics(
        image: true,
        label: doc.hebrew.isEmpty ? 'Lamen de la Rosa-Cruz, sin nombre trazado' : 'Rosa-Cruz con el nombre ${doc.name.isEmpty ? doc.hebrew : doc.name} trazado',
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: SigilScenePainter(bg: s.bg, fg: s.fg, version: _snap))),
          if (doc.hebrew.isEmpty)
            IgnorePointer(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Escribe un nombre y pulsa «Trazar sobre el Lamen».', textAlign: TextAlign.center, style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted, italic: true)),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _lectura() {
    final muted = ArcanumText.body(14, color: ArcanumColors.ivoryMuted), strong = ArcanumText.body(14, color: ArcanumColors.ivory);
    Widget row(String label, Widget value) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 82, child: Text(label, style: muted)),
            Expanded(child: value),
          ]),
        );
    final ws = doc.words, tokens = doc.tokens;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (doc.name.isNotEmpty) row('Nombre', Text(doc.name, style: strong)),
      if (tokens != null) ...[
        row('Regla', Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(doc.method == TranslitMethod.consonantal ? 'Consonántica' : 'Letra a letra', style: strong),
          etiqueta(Procedencia.rc),
          Text(' ${doc.method == TranslitMethod.consonantal ? kTranslitConsonantal : kTranslitFull}', style: muted),
        ])),
        row('Letras', Text(tokens.tokens.where((t) => t.latin != ' ').map((t) => '${t.latin}→${t.he.isEmpty ? '∅' : t.he}${t.note.isNotEmpty ? ' (${t.note})' : ''}').join(' · '), style: strong)),
      ] else
        row('Origen', Text('Hebreo escrito o corregido a mano.', style: strong)),
      row('Hebreo', Directionality(textDirection: TextDirection.rtl, child: Text(doc.hebrew.isEmpty ? '—' : doc.hebrew, style: strong))),
      row('Recorrido', Text(ws.any((w) => w.isNotEmpty) ? doc.recorrido : '—', style: strong)),
      row('Gematría', Text(doc.gematriaText, style: strong)),
      row('Marcas', Text(doc.marks.isEmpty ? '—.' : '${doc.marks.join('; ')}.', style: strong)),
      if (doc.colors && doc.trace.isNotEmpty) ...[
        row(
          'Colores',
          Directionality(
            textDirection: TextDirection.ltr,
            child: Wrap(spacing: 10, runSpacing: 4, children: [
              for (final he in doc.usedLetters)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(he, style: strong),
                  const SizedBox(width: 4),
                  Icon(Icons.square, size: 12, color: Color(0xFF000000 | int.parse(kRoseColors[he]!.$2.substring(1), radix: 16))),
                  const SizedBox(width: 4),
                  Flexible(child: Text(kRoseColors[he]!.$1, style: strong)),
                ]),
            ]),
          ),
        ),
        row('Síntesis', Text(doc.hebrew == 'מטטרון' ? 'Mathers da para Metatron «una cidra rojiza».' : 'El manuscrito solo da la síntesis de Metatron; el taller no inventa una fórmula para mezclar colores.', style: strong)),
      ],
      row('Letras', Text('${doc.hebrew.split('').where((c) => c != ' ').length}', style: strong)),
    ]);
  }

  Widget _panel() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      sectionTitle('Nombre'),
      TextField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        enableSuggestions: false,
        autocorrect: false,
        enableIMEPersonalizedLearning: false,
        style: ArcanumText.body(16),
        decoration: const InputDecoration(hintText: 'Tu nombre, o el de un ángel'),
        onSubmitted: (_) => _trace(),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        familiaChip('Consonántica', doc.method == TranslitMethod.consonantal, () => _set(() => doc.method = TranslitMethod.consonantal)),
        familiaChip('Letra a letra', doc.method == TranslitMethod.full, () => _set(() => doc.method = TranslitMethod.full)),
      ]),
      const SizedBox(height: 10),
      GoldButton(label: 'Trazar sobre el Lamen', onPressed: _trace),
      sectionTitle('Hebreo'),
      TextField(
        controller: _hebrew,
        textDirection: TextDirection.rtl,
        maxLength: 40,
        enableSuggestions: false,
        autocorrect: false,
        style: ArcanumText.body(18),
        onChanged: (v) => _set(() => doc.setHebrew(v)),
      ),
      sectionTitle('Dibujo'),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Ver el Lamen', style: ArcanumText.body(15)),
        subtitle: Text('Los 22 pétalos con su letra y su correspondencia.', style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted)),
        value: doc.diagram,
        activeThumbColor: ArcanumColors.gold,
        onChanged: (v) => _set(() => doc.diagram = v),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Colores de las letras', style: ArcanumText.body(15)),
        subtitle: Text('Escala del Rey de la Aurora Dorada; cada tramo degrada de una letra a la siguiente.', style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted)),
        value: doc.colors,
        activeThumbColor: ArcanumColors.gold,
        onChanged: (v) => _set(() => doc.colors = v),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Barra al final', style: ArcanumText.body(15)),
        subtitle: Text('Las figuras de Metatron y Elohim del manuscrito acaban en una barra corta.', style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted)),
        value: doc.endBar,
        activeThumbColor: ArcanumColors.gold,
        onChanged: (v) => _set(() => doc.endBar = v),
      ),
      sectionTitle('Estilo'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final (key, label) in _styles) familiaChip(label, doc.style.preset == presetStyle(key).preset, () => _set(() => doc.style = presetStyle(key))),
      ]),
      sectionTitle('Lectura'),
      _lectura(),
      const SizedBox(height: 6),
      Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: _showFuentes, child: const Text('Cómo se traza y qué es histórico'))),
      sectionTitle('Guardar'),
      Text('Se guarda en tu Grimorio, cifrado como el resto de tus entradas. El título dice «Rosa-Cruz», no el nombre que trazaste.', style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)),
      const SizedBox(height: 8),
      GoldButton(label: _savedId != null ? 'Guardar cambios' : 'Guardar en el Grimorio', loading: _saving, onPressed: doc.hebrew.isEmpty ? null : _save),
      sectionTitle('Compartir'),
      Row(children: [
        Expanded(child: familiaOutlined('Imagen (PNG)', doc.hebrew.isEmpty ? null : () => _share(png: true))),
        const SizedBox(width: 8),
        Expanded(child: familiaOutlined('Vector (SVG)', doc.hebrew.isEmpty ? null : () => _share(png: false))),
      ]),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Fondo transparente al compartir', style: ArcanumText.body(15)),
        value: _transparent,
        activeThumbColor: ArcanumColors.gold,
        onChanged: (v) => setState(() => _transparent = v),
      ),
    ]);
  }

  void _showFuentes() => showModalBottomSheet<void>(
        context: context,
        backgroundColor: ArcanumColors.surface,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .75,
          builder: (context, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: rosaFuentes(doc)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) Navigator.pop(context, _savedId != null);
      },
      child: Scaffold(
        backgroundColor: ArcanumColors.background,
        appBar: AppBar(
          backgroundColor: ArcanumColors.background,
          title: Text('Rosa-Cruz', style: ArcanumText.heading(20)),
          leading: IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close, color: ArcanumColors.ivoryMuted),
            onPressed: () async {
              if (await _confirmLeave() && context.mounted) Navigator.pop(context, _savedId != null);
            },
          ),
          actions: [IconButton(tooltip: 'Fuentes', icon: const Icon(Icons.menu_book_outlined), color: ArcanumColors.gold, onPressed: _showFuentes)],
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(builder: (context, box) {
            // orientacion de la pantalla, no del hueco libre: con el teclado abierto el
            // alto baja del ancho y el panel se rehacia (el campo perdia el foco)
            final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
            final panel = ListView(key: _panelKey, padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [_panel()]);
            if (landscape) return Row(children: [_canvas(box.maxHeight), Expanded(child: panel)]);
            final side = box.maxWidth < box.maxHeight * .55 ? box.maxWidth : box.maxHeight * .55;
            return Column(children: [Center(child: _canvas(side)), Expanded(child: panel)]);
          }),
        ),
      ),
    );
  }
}

/// Reglas de transcripcion al hebreo, en palabras (reconstruccion del taller).
const kTranslitConsonantal =
    'Como se escribe el hebreo: vocal inicial = Álef (Yod si es i); a y e interiores no se escriben; i = Yod; o, u = Vav; a final = He. Letras dobles latinas se escriben una vez. Finales (ך ם ן ף ץ) al acabar la palabra.';
const kTranslitFull = 'Cada letra latina, vocales incluidas, con su letra hebrea: a = Álef, e/i/y = Yod, o = Ayin, u = Vav.';

/// Procedencia de la Rosa-Cruz en lenguaje llano: que es del manuscrito y que se reconstruyo.
List<Widget> rosaFuentes(RosaDoc doc) {
  final body = ArcanumText.body(15), muted = ArcanumText.body(14, color: ArcanumColors.ivoryMuted);
  Widget line(String text, [List<Procedencia> p = const [], String? original]) {
    final w = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [Text(text, style: body), ...p.map(etiqueta)]),
    );
    return original == null ? w : Tooltip(message: original, child: w);
  }

  final g = gematria(doc.hebrew);
  return [
    Text('Rosa-Cruz', style: ArcanumText.heading(24)),
    const SizedBox(height: 6),
    Text('${doc.name.isEmpty ? '—' : doc.name} → ${doc.hebrew.isEmpty ? '—' : doc.hebrew} · gematría ${g.std}', style: muted),
    sectionTitle('Cómo se traza (manuscrito F de Mathers)'),
    line('1. Círculo en la letra inicial: «comienza con un círculo en el lugar de la letra inicial sobre la Rosa».', [], 'Original en inglés: commence with a circle at the point of the initial letter on the Rose'),
    line('2. Línea desde ese círculo hasta la siguiente letra, y así hasta acabar el nombre.'),
    line('3. Dos letras iguales seguidas: «un quiebro u onda en la línea en ese punto».', [], 'Original en inglés: a crook or wave in the line at that point'),
    line(
      '4. Letra del nombre por la que la línea pasa hacia otra, como Resh en Metatron: «un lazo en la línea en ese punto». Aquí se marca en dos casos: cuando la línea pasa casi recta por una letra del recorrido (giro menor de 15°) y cuando un trazo pasa a menos de 48 px de una letra del nombre que aún no ha visitado, que no sea la primera ni la última; el lazo va sobre la línea, en el punto más cercano a la letra, como en la lámina de Haniel. Calibrado con las ocho láminas del manuscrito.',
      [Procedencia.ar],
      'Original en inglés: a noose in the line at that point',
    ),
    line('5. Cada palabra es un sigilo aparte, con su círculo y su barra, como YHVH y TZABAOTH en la lámina de Netzach.', [Procedencia.om]),
    line(
      '6. Colores: «en los colores respectivos de las letras, y sumarlos en una síntesis de color». Son los de la escala del Rey (caminos 11 a 32); los cinco de Metatron coinciden con el manuscrito. Que cada tramo degrade de una letra a la siguiente es elección del taller.',
      [Procedencia.rc],
      'Original en inglés: in the respective colours of the letters and add these together to form a synthesis of colour',
    ),
    line('7. Final: el texto no menciona ninguna marca, pero las figuras del propio manuscrito (Metatron y Elohim) terminan en una barra corta. Va activada.', [Procedencia.om]),
    line('8. Si un trazo repasa una línea ya dibujada, se aparta un poco para que se vea, como en la figura de Elohim del manuscrito.', [Procedencia.ar]),
    sectionTitle('Fuentes'),
    line('Mathers (firmaba G.H. Frater D.D.C.F.), manuscrito F, Sigilos de la Rosa.', [Procedencia.om], 'Título original: Sigils from the Rose'),
    line(
      'Aurora Dorada (Golden Dawn), grado 5=6, El Lamen de la Rosa-Cruz: las tres madres; las siete dobles en el orden Pe, Resh, Bet, Dálet, Guímel, Tav y Kaf; el zodiaco con He arriba.',
      [Procedencia.om],
      'Título original: The Rose Cross Lamen',
    ),
    line('Dibujo del Lamen de la Rosa-Cruz en Wikimedia Commons: posición y sentido de los tres anillos.'),
    line('Paso del latín al hebreo: reconstrucción de este taller; por eso el hebreo se puede corregir.', [Procedencia.rc]),
    Padding(padding: const EdgeInsets.only(top: 10), child: Text('Mantén pulsado un texto traducido para ver el original.', style: ArcanumText.body(12, color: ArcanumColors.goldMuted, italic: true))),
  ];
}
