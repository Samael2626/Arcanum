// Kamea: el nombre en hebreo trazado sobre la tabla planetaria de Agrippa.
// Familia historica aparte del sigilo de letras (no hereda el ritual de la
// magia del caos: sin carga ni olvido). El motor es KameaDoc, del paquete
// arcanum_sigilos, probado contra el prototipo.
import 'dart:convert';
import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class KameaScreen extends ConsumerStatefulWidget {
  /// Entrada del Grimorio que se sigue editando (null: kamea nueva).
  final String? entryId;
  final KameaDoc? initial;
  const KameaScreen({super.key, this.entryId, this.initial});

  @override
  ConsumerState<KameaScreen> createState() => KameaScreenState();
}

class KameaScreenState extends ConsumerState<KameaScreen> {
  // el panel conserva su estado (y el foco del campo) si cambia de sitio
  final _panelKey = GlobalKey();
  late final KameaDoc doc = widget.initial ?? KameaDoc();
  late final TextEditingController _name = TextEditingController(text: doc.name);
  late final TextEditingController _hebrew = TextEditingController(text: doc.hebrew);
  TranslitMethod _translit = TranslitMethod.consonantal;
  bool _saving = false, _transparent = false;
  late String? _savedId = widget.entryId;
  String? _savedSnapshot;

  static const _styles = [('pergamino', 'Pergamino'), ('papel', 'Papel'), ('lacre', 'Lacre'), ('oro', 'Oro'), ('burdeos', 'Burdeos'), ('plata', 'Plata')];

  @visibleForTesting
  KameaDoc get debugDoc => doc;

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
      doc.setName(text, translit: _translit);
      _hebrew.text = doc.hebrew;
    });
    if (doc.hebrew.isEmpty) _toast('Ese nombre no deja ninguna letra hebrea. Escríbelo en hebreo o prueba la otra transcripción.');
  }

  void _preset(KameaName n) => setState(() {
        doc.name = n.latin;
        doc.hebrew = n.hebrew;
        _name.text = n.latin;
        _hebrew.text = n.hebrew;
      });

  // ── Guardar y compartir ───────────────────────────────────────
  Future<void> _save() async {
    final snapshot = _snap;
    setState(() => _saving = true);
    try {
      final store = SigilStore(ref.read(arcanumApiProvider), ref.read(grimoireCryptoProvider), ref.read(userPlaceProvider));
      _savedId = await store.saveKamea(doc, entryId: _savedId);
      _savedSnapshot = snapshot;
      _toast('Kamea guardada en tu Grimorio.');
    } catch (e) {
      debugPrint('ARCANUM kamea: fallo al guardar ($e).');
      _toast('No se pudo guardar. Revisa la conexión e inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share({required bool png}) async {
    final ok = await compartirFamilia(
      png: png,
      transparent: _transparent,
      baseName: 'arcanum-kamea',
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

  Future<bool> _confirmLeave() async => !_dirty || await confirmarSalida(context, 'Los cambios de esta kamea se perderán.');

  // ── Piezas ────────────────────────────────────────────────────
  Widget _chip(String label, bool on, VoidCallback onTap) => familiaChip(label, on, onTap);

  Widget _outlined(String label, VoidCallback? onTap) => familiaOutlined(label, onTap);

  Widget _canvas(double side) {
    final s = doc.scene();
    return SizedBox.square(
      dimension: side,
      child: Semantics(
        image: true,
        label: doc.hebrew.isEmpty ? 'Tabla de ${doc.def.name}, sin nombre trazado' : 'Kamea de ${doc.def.name} con el nombre ${doc.name.isEmpty ? doc.hebrew : doc.name} trazado',
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: SigilScenePainter(bg: s.bg, fg: s.fg, version: _snap))),
          if (doc.hebrew.isEmpty)
            IgnorePointer(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Escribe un nombre o elige uno de los de Agrippa.', textAlign: TextAlign.center, style: ArcanumText.body(16, color: ArcanumColors.ivoryMuted, italic: true)),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _lectura() {
    final k = doc.def, muted = ArcanumText.body(14, color: ArcanumColors.ivoryMuted), strong = ArcanumText.body(14, color: ArcanumColors.ivory);
    final preset = k.names.where((n) => n.hebrew == doc.hebrew).firstOrNull;
    Widget row(String label, Widget value) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 82, child: Text(label, style: muted)),
            Expanded(child: value),
          ]),
        );
    final steps = doc.words;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (preset != null) ...[
        row('Nombre', Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [Text('${preset.latin}, ${preset.role.toLowerCase()} de ${k.name} según Agrippa', style: strong), etiqueta(Procedencia.hp)])),
        row('Figura', Text('${kVerdictText[preset.verdict]}${doc.reduce == KameaReduce.agrippa ? '' : ' (con la reducción «Como Agrippa»)'}', style: strong)),
      ],
      row('Tabla', Text('${k.sym} ${k.name}: ${k.n}×${k.n}, cada línea suma ${doc.lineSum}, en total ${doc.total}.', style: strong)),
      row(
        'Casillas',
        steps.isEmpty
            ? Text('—', style: strong)
            : Directionality(
                textDirection: TextDirection.ltr,
                child: Wrap(spacing: 10, runSpacing: 4, children: [
                  for (final (i, w) in steps.indexed) ...[
                    if (i > 0) Text('|', style: muted),
                    for (final st in w) Text('${st.ch} ${st.v}${st.reduced ? ' → ${st.cell}' : ''}', style: strong),
                  ],
                ]),
              ),
      ),
      row('Reducción', Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(doc.reduce.label, style: strong),
        etiqueta(doc.reduce == KameaReduce.agrippa ? Procedencia.ar : Procedencia.rc),
        Text(' ${doc.reduce.rule}', style: muted),
      ])),
      row('Suma', Text('${doc.sum}${doc.echo.isEmpty ? '' : ' · ${doc.echo}'}', style: strong)),
    ]);
  }

  Widget _panel() {
    final k = doc.def;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      sectionTitle('Tabla'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final p in kKameas) _chip('${p.sym} ${p.name}', p.id == doc.planet, () => _set(() => doc.planet = p.id)),
      ]),
      sectionTitle('Nombre'),
      TextField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        enableSuggestions: false,
        autocorrect: false,
        enableIMEPersonalizedLearning: false,
        style: ArcanumText.body(16),
        decoration: const InputDecoration(hintText: 'Tu nombre, o el de un espíritu'),
        onSubmitted: (_) => _trace(),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        _chip('Consonántica', _translit == TranslitMethod.consonantal, () => _set(() => _translit = TranslitMethod.consonantal)),
        _chip('Letra a letra', _translit == TranslitMethod.full, () => _set(() => _translit = TranslitMethod.full)),
      ]),
      const SizedBox(height: 10),
      GoldButton(label: 'Trazar sobre la tabla', onPressed: _trace),
      sectionTitle('Nombres de Agrippa'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final n in k.names) _outlined('${n.role}: ${n.latin}', () => _preset(n)),
      ]),
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
      sectionTitle('Trazo'),
      Text('Números mayores que la tabla', style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final r in KameaReduce.values) _chip(r.label, doc.reduce == r, () => _set(() => doc.reduce = r)),
      ]),
      const SizedBox(height: 10),
      Text('Extremos', style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        _chip('Círculos (Agrippa)', doc.ends == KameaEnds.agrippa, () => _set(() => doc.ends = KameaEnds.agrippa)),
        _chip('Barra (Aurora Dorada)', doc.ends == KameaEnds.gd, () => _set(() => doc.ends = KameaEnds.gd)),
      ]),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Ver la tabla numerada', style: ArcanumText.body(15)),
        subtitle: Text('Sin tabla se dibuja como lámina, a la manera de Agrippa.', style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted)),
        value: doc.grid,
        activeThumbColor: ArcanumColors.gold,
        onChanged: (v) => _set(() => doc.grid = v),
      ),
      sectionTitle('Estilo'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final (key, label) in _styles) _chip(label, doc.style.preset == presetStyle(key).preset, () => _set(() => doc.style = presetStyle(key))),
      ]),
      sectionTitle('Lectura'),
      _lectura(),
      const SizedBox(height: 6),
      Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: _showFuentes, child: const Text('Qué es histórico y qué no'))),
      sectionTitle('Guardar'),
      Text('Se guarda en tu Grimorio, cifrado como el resto de tus entradas. El título nombra la tabla, no el nombre que trazaste.', style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)),
      const SizedBox(height: 8),
      GoldButton(label: _savedId != null ? 'Guardar cambios' : 'Guardar en el Grimorio', loading: _saving, onPressed: doc.hebrew.isEmpty ? null : _save),
      sectionTitle('Compartir'),
      Row(children: [
        Expanded(child: _outlined('Imagen (PNG)', doc.hebrew.isEmpty ? null : () => _share(png: true))),
        const SizedBox(width: 8),
        Expanded(child: _outlined('Vector (SVG)', doc.hebrew.isEmpty ? null : () => _share(png: false))),
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

  Future<void> _copyLink() async {
    await Clipboard.setData(const ClipboardData(text: kAgrippaUrl));
    if (mounted) _toast('Enlace copiado.');
  }

  void _showFuentes() => showModalBottomSheet<void>(
        context: context,
        backgroundColor: ArcanumColors.surface,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .75,
          builder: (context, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: kameaFuentes(doc.def, _copyLink)),
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
          title: Text('Kamea', style: ArcanumText.heading(20)),
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

/// Procedencia de la kamea en lenguaje llano: que es historico y que se reconstruyo.
List<Widget> kameaFuentes(KameaDef k, [VoidCallback? onCopyLink]) {
  final body = ArcanumText.body(15), muted = ArcanumText.body(14, color: ArcanumColors.ivoryMuted);
  Widget line(String text, [List<Procedencia> p = const []]) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [Text(text, style: body), ...p.map(etiqueta)]),
      );
  return [
    Text('Kamea de ${k.name}', style: ArcanumText.heading(24)),
    const SizedBox(height: 6),
    line('Tabla de ${k.n}×${k.n}, tal como la imprime Agrippa.', [Procedencia.hp]),
    sectionTitle('Qué es histórico y qué no'),
    Tooltip(
      message: 'Título original: De occulta philosophia',
      child: line('Las siete tablas, los nombres de inteligencias y espíritus y sus números: Agrippa, Filosofía oculta (1533), libro II, cap. 22.', [Procedencia.hp]),
    ),
    line('Cada nombre suma el número que Agrippa le da, contando las letras finales de 500 a 900, como hace él (Bne Serafim 1252).', [Procedencia.hp]),
    Tooltip(
      message: 'Original en inglés: the wise searcher, and he which shall understand the verifying of these tables, shall easily find out',
      child: line('Cómo se traza el sello sobre la tabla: Agrippa no lo explica; dice que «el buscador sabio […] lo descubrirá fácilmente». El recorrido de casilla en casilla es una reconstrucción.', [Procedencia.rc]),
    ),
    line('Círculo en los dos extremos y horquilla cuando el trazo vuelve sobre sí mismo: así están dibujados los caracteres de Agrippa.', [Procedencia.hp]),
    line('Números mayores que la tabla: se reducen quitando ceros o por Aiq Bekar. Comparando con sus 15 figuras, Agrippa usa Aiq Bekar hasta 6×6 y quita ceros desde 7×7: así coinciden 8 figuras con claridad y 6 en su estructura. Grafiel no sale con ningún método.', [Procedencia.ar]),
    sectionTitle('Erratas de la edición inglesa de 1651'),
    Text('• Luna, fila 1, columna 8: pone «45», que ya está en la fila 9 y deja la fila en 360. El único número que falta es 54.', style: muted),
    Text('• Kedemel: pone «157», pero קדמאל suma 175, que es la línea de Venus.', style: muted),
    Text('• Bne Serafim: la transcripción trae בסי; solo בני da el 1252 impreso.', style: muted),
    sectionTitle('Grafiel, sin reproducir'),
    Text(
      'Su figura en Agrippa es un circuito cerrado de cinco vértices. גראפיאל pasa dos veces por el Álef y no puede dibujar eso; un Grafiel sin el segundo Álef (ג ר א פ י ל) sí daría cinco vértices cerrados, pero ninguna orientación de la tabla reproduce la forma. Queda como indicio, no como regla.',
      style: muted,
    ),
    sectionTitle('Nombre que no se incluye'),
    Text(
      'La inteligencia de las inteligencias de la Luna, Malkah be-Tarshishim…, llega corrupta en Agrippa (Donald Tyson propuso una restauración en su edición anotada). Cinco grafías hebreas distintas suman su 3321; sin la fuente que decide entre ellas, el taller no elige ninguna.',
      style: muted,
    ),
    const SizedBox(height: 10),
    TextButton(onPressed: onCopyLink, child: const Text('Copiar el enlace a las láminas originales (Agrippa, libro II, cap. 22)')),
  ];
}
