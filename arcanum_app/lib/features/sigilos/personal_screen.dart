// Sello nuevo en formato historico. La procedencia de la figura central sigue
// siendo la de su motor; el montaje es reconstruccion del taller.
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
import 'taller_panels.dart' show sectionTitle;

class PersonalScreen extends ConsumerStatefulWidget {
  final String? entryId;
  final PersonalDoc? initial;
  const PersonalScreen({super.key, this.entryId, this.initial});

  @override
  ConsumerState<PersonalScreen> createState() => PersonalScreenState();
}

class PersonalScreenState extends ConsumerState<PersonalScreen> {
  late final PersonalDoc doc = widget.initial ?? PersonalDoc();
  late final TextEditingController _name = TextEditingController(text: doc.displayedName);
  bool _saving = false, _transparent = false;
  late String? _savedId = widget.entryId;
  String? _savedSnapshot;

  @visibleForTesting
  PersonalDoc get debugDoc => doc;
  String get _snap => jsonEncode(doc.toJson());
  bool get _dirty => doc.ready && _snap != _savedSnapshot;

  @override
  void initState() { super.initState(); if (_savedId != null) _savedSnapshot = _snap; }
  @override
  void dispose() { _name.dispose(); super.dispose(); }
  void _toast(String text) => ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(text)));

  void _generate() {
    final text = _name.text.trim();
    if (text.isEmpty) { _toast('Escribe un nombre.'); return; }
    FocusScope.of(context).unfocus();
    setState(() {
      doc.name = text;
      switch (doc.source) {
        case 'letters':
          doc.letters.sigil..method = ReductionMethod.unique..mode = ComposeMode.fusion;
          doc.letters.generate(text);
        case 'rosa': doc.rosa.setName(text);
        case 'kamea': doc.kamea.setName(text);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final store = SigilStore(ref.read(arcanumApiProvider), ref.read(grimoireCryptoProvider), ref.read(userPlaceProvider));
      _savedId = await store.savePersonal(doc, entryId: _savedId);
      _savedSnapshot = _snap;
      _toast('Sello guardado en tu Grimorio.');
    } catch (error) {
      debugPrint('ARCANUM sello personal: fallo al guardar ($error).');
      _toast('No se pudo guardar. Revisa la conexión e inténtalo de nuevo.');
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _share({required bool png}) async {
    final ok = await compartirFamilia(
      png: png, transparent: _transparent, baseName: 'arcanum-sello-personal',
      scene: (transparent) {
        final old = doc.transparent;
        doc.transparent = transparent;
        try { return doc.scene(); } finally { doc.transparent = old; }
      },
      svg: (transparent) {
        final old = doc.transparent;
        doc.transparent = transparent;
        try { return doc.buildSVG(); } finally { doc.transparent = old; }
      },
    );
    if (!ok && mounted) _toast('No se pudo preparar el archivo para compartir.');
  }

  Future<void> _close() async {
    if ((!_dirty || await confirmarSalida(context, 'Los cambios de este sello se perderán.')) && mounted) Navigator.pop(context, _savedId != null);
  }

  Widget _canvas(double side) {
    final scene = doc.scene();
    return SizedBox.square(dimension: side, child: Semantics(
      image: true,
      label: doc.ready ? 'Sello personal de ${doc.displayedName}, figura de ${kPersonalSources[doc.source]}' : 'Sello personal sin figura',
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: SigilScenePainter(bg: scene.bg, fg: scene.fg, version: _snap))),
        if (!doc.ready) Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Escribe un nombre y traza su figura.', textAlign: TextAlign.center, style: ArcanumText.body(16, color: ArcanumColors.ivoryMuted)))),
      ]),
    ));
  }

  Widget _panel() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    sectionTitle('Figura central'),
    TextField(controller: _name, maxLength: 40, enableSuggestions: false, autocorrect: false, enableIMEPersonalizedLearning: false,
      style: ArcanumText.body(16), decoration: const InputDecoration(hintText: 'Tu nombre o una palabra'), onSubmitted: (_) => _generate()),
    Wrap(spacing: 6, runSpacing: 6, children: [
      familiaChip('Letras', doc.source == 'letters', () { setState(() => doc.source = 'letters'); _generate(); }),
      familiaChip('Rosa-Cruz', doc.source == 'rosa', () { setState(() => doc.source = 'rosa'); _generate(); }),
      familiaChip('Kamea', doc.source == 'kamea', () { setState(() => doc.source = 'kamea'); _generate(); }),
    ]),
    const SizedBox(height: 8),
    GoldButton(label: 'Trazar figura', onPressed: _generate),
    sectionTitle('Formato del sello'),
    Wrap(spacing: 6, runSpacing: 6, children: [
      familiaChip('Goetia', doc.template == 'goetia', () => setState(() => doc.setTemplate('goetia'))),
      familiaChip('Pentáculo', doc.template == 'pentaculo', () => setState(() => doc.setTemplate('pentaculo'))),
      familiaChip('Agrippa', doc.template == 'agrippa', () => setState(() => doc.setTemplate('agrippa'))),
    ]),
    Text('El formato se inspira en obras históricas. Este sello es una reconstrucción nueva, no un sello transmitido.', style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)),
    sectionTitle('Capas'),
    Wrap(spacing: 6, runSpacing: 6, children: [
      for (final (i, layer) in doc.layers.indexed) InputChip(label: Text(layer.name), onDeleted: () => setState(() => doc.layers.removeAt(i))),
      PopupMenuButton<LayerType>(tooltip: 'Añadir capa', onSelected: (type) => setState(() => doc.layers.add(Layer.create('p${DateTime.now().microsecondsSinceEpoch}', type))),
        itemBuilder: (_) => [for (final type in LayerType.values) PopupMenuItem(value: type, child: Text(type.label))],
        child: const Chip(label: Text('Añadir capa'))),
    ]),
    sectionTitle('Planeta'),
    Text(doc.source == 'kamea' ? 'La figura de Kamea exige el planeta de su tabla.' : 'Elige un planeta o usa el regente del día.', style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)),
    if (doc.source == 'kamea') Wrap(spacing: 6, runSpacing: 6, children: [for (final k in kKameas) familiaChip(k.name, doc.kamea.planet == k.id, () => setState(() => doc.kamea.planet = k.id))])
    else Wrap(spacing: 6, runSpacing: 6, children: [
      familiaChip('Hoy', doc.planetChoice == 'auto', () => setState(() => doc.planetChoice = 'auto')),
      for (final k in kKameas) familiaChip(k.name, doc.planetChoice == k.id, () => setState(() => doc.planetChoice = k.id)),
    ]),
    sectionTitle('Presentación'),
    Wrap(spacing: 6, runSpacing: 6, children: [
      familiaChip('Papel', doc.view == 'paper', () => setState(() => doc.view = 'paper')),
      familiaChip('Metal', doc.view == 'metal', () => setState(() => doc.view = 'metal')),
    ]),
    sectionTitle('Guardar'),
    Text('El nombre y las decisiones se guardan cifrados. El título del Grimorio no revela el nombre.', style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)),
    const SizedBox(height: 8),
    GoldButton(label: _savedId == null ? 'Guardar en el Grimorio' : 'Guardar cambios', loading: _saving, onPressed: doc.ready ? _save : null),
    sectionTitle('Compartir'),
    Row(children: [
      Expanded(child: familiaOutlined('Imagen (PNG)', doc.ready ? () => _share(png: true) : null)),
      const SizedBox(width: 8),
      Expanded(child: familiaOutlined('Vector (SVG)', doc.ready ? () => _share(png: false) : null)),
    ]),
    SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Fondo transparente al compartir', style: ArcanumText.body(15)),
      value: _transparent, activeThumbColor: ArcanumColors.gold, onChanged: (v) => setState(() => _transparent = v)),
  ]);

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) async { if (!didPop) await _close(); },
    child: Scaffold(backgroundColor: ArcanumColors.background,
      appBar: AppBar(backgroundColor: ArcanumColors.background, title: Text('Sello personal', style: ArcanumText.heading(20)),
        leading: IconButton(tooltip: 'Cerrar', icon: const Icon(Icons.close), onPressed: _close)),
      body: SafeArea(top: false, child: LayoutBuilder(builder: (context, box) {
        final landscape = box.maxWidth > box.maxHeight;
        final panel = ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [_panel()]);
        if (landscape) return Row(children: [_canvas(box.maxHeight), Expanded(child: panel)]);
        final side = box.maxWidth < box.maxHeight * .55 ? box.maxWidth : box.maxHeight * .55;
        return Column(children: [Center(child: _canvas(side)), Expanded(child: panel)]);
      })),
    ),
  );
}
