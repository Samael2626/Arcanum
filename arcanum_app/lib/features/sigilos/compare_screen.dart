// Ejercicio del mismo nombre en tres sistemas; la lamina es decision [AR].
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

class CompareScreen extends ConsumerStatefulWidget {
  final String? entryId;
  final CompareDoc? initial;
  const CompareScreen({super.key, this.entryId, this.initial});
  @override
  ConsumerState<CompareScreen> createState() => CompareScreenState();
}

class CompareScreenState extends ConsumerState<CompareScreen> {
  late final CompareDoc doc = widget.initial ?? CompareDoc();
  late final TextEditingController _name = TextEditingController(
    text: doc.name,
  );
  late String? _savedId = widget.entryId;
  String? _savedSnapshot;
  bool _saving = false, _transparent = false;

  @visibleForTesting
  CompareDoc get debugDoc => doc;
  String get _snap => jsonEncode(doc.toJson());
  bool get _nameChanged => _name.text.trim() != doc.name;
  bool get _dirty => _nameChanged || (doc.ready && _snap != _savedSnapshot);

  @override
  void initState() {
    super.initState();
    if (_savedId != null) _savedSnapshot = _snap;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  void _generate() {
    final value = _name.text.trim();
    if (value.isEmpty) {
      _toast('Escribe un nombre.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => doc.generate(value));
  }

  Future<void> _save() async {
    if (!doc.ready || _nameChanged) return;
    final snapshot = _snap;
    setState(() => _saving = true);
    try {
      final store = SigilStore(
        ref.read(arcanumApiProvider),
        ref.read(grimoireCryptoProvider),
        ref.read(userPlaceProvider),
      );
      _savedId = await store.saveCompare(doc, entryId: _savedId);
      _savedSnapshot = snapshot;
      _toast('Comparación guardada en tu Grimorio.');
    } catch (error) {
      debugPrint('ARCANUM comparar: fallo al guardar ($error).');
      _toast('No se pudo guardar. Revisa la conexión e inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share({required bool png}) async {
    final ok = await compartirFamilia(
      png: png,
      transparent: _transparent,
      baseName: 'arcanum-comparar',
      scene: (transparent) {
        final old = doc.transparent;
        doc.transparent = transparent;
        try {
          return doc.scene();
        } finally {
          doc.transparent = old;
        }
      },
      svg: (transparent) {
        final old = doc.transparent;
        doc.transparent = transparent;
        try {
          return doc.buildSVG();
        } finally {
          doc.transparent = old;
        }
      },
    );
    if (!ok && mounted) {
      _toast('No se pudo preparar el archivo para compartir.');
    }
  }

  Future<void> _close() async {
    if ((!_dirty ||
            await confirmarSalida(
              context,
              'Los cambios de esta comparación se perderán.',
            )) &&
        mounted) {
      Navigator.pop(context, _savedId != null);
    }
  }

  Widget _canvas(double side) {
    final scene = doc.scene();
    return SizedBox.square(
      dimension: side,
      child: Semantics(
        image: true,
        label: doc.ready
            ? '${doc.name} en Letras, Rosa-Cruz y Kamea de ${doc.kamea.def.name}'
            : 'Comparación sin figuras',
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: SigilScenePainter(
                  bg: scene.bg,
                  fg: scene.fg,
                  version: _snap,
                ),
              ),
            ),
            if (!doc.ready)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Escribe un nombre y compara las tres figuras.',
                    textAlign: TextAlign.center,
                    style: ArcanumText.body(
                      16,
                      color: ArcanumColors.ivoryMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _panel() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      sectionTitle('El mismo nombre en tres sistemas'),
      TextField(
        controller: _name,
        maxLength: 40,
        enableSuggestions: false,
        autocorrect: false,
        enableIMEPersonalizedLearning: false,
        style: ArcanumText.body(16),
        decoration: const InputDecoration(hintText: 'Nombre o palabra'),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _generate(),
      ),
      GoldButton(label: 'Comparar', onPressed: _generate),
      if (_nameChanged && doc.ready)
        Text('Vuelve a comparar el nombre editado antes de guardar o compartir.',
          style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)),
      sectionTitle('Kamea'),
      Text(
        'La tabla cambia la figura de Kamea; las tres construcciones usan el mismo nombre.',
        style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
      ),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          familiaChip('Hoy', doc.planetChoice == 'auto', () {
            setState(() => doc.planetChoice = 'auto');
            if (doc.name.isNotEmpty) _generate();
          }),
          for (final k in kKameas)
            familiaChip(k.name, doc.planetChoice == k.id, () {
              setState(() => doc.planetChoice = k.id);
              if (doc.name.isNotEmpty) _generate();
            }),
        ],
      ),
      if (doc.ready) ...[
        sectionTitle('Recorridos'),
        Text(
          'Letras: ${doc.letters.sigil.letters.map((l) => l.ch).join(' ')}',
          style: ArcanumText.body(15),
        ),
        Text('Hebreo: ${doc.rosa.hebrew}', style: ArcanumText.body(15)),
        Text(
          'Rosa-Cruz: ${doc.rosa.trace.length} pétalos · Kamea: ${doc.kamea.words.expand((w) => w).length} casillas',
          style: ArcanumText.body(15),
        ),
      ],
      sectionTitle('Guardar'),
      Text(
        'El nombre se guarda cifrado; el título del Grimorio no lo revela.',
        style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
      ),
      const SizedBox(height: 8),
      GoldButton(
        label: _savedId == null ? 'Guardar en el Grimorio' : 'Guardar cambios',
        loading: _saving,
        onPressed: doc.ready && !_nameChanged ? _save : null,
      ),
      sectionTitle('Compartir'),
      Row(
        children: [
          Expanded(
            child: familiaOutlined(
              'Imagen (PNG)',
              doc.ready && !_nameChanged ? () => _share(png: true) : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: familiaOutlined(
              'Vector (SVG)',
              doc.ready && !_nameChanged ? () => _share(png: false) : null,
            ),
          ),
        ],
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          'Fondo transparente al compartir',
          style: ArcanumText.body(15),
        ),
        value: _transparent,
        activeThumbColor: ArcanumColors.gold,
        onChanged: (v) => setState(() => _transparent = v),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) async {
      if (!didPop) await _close();
    },
    child: Scaffold(
      backgroundColor: ArcanumColors.background,
      appBar: AppBar(
        backgroundColor: ArcanumColors.background,
        title: Text('Comparar', style: ArcanumText.heading(20)),
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.close),
          onPressed: _close,
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, box) {
            final landscape = box.maxWidth > box.maxHeight;
            final panel = ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [_panel()],
            );
            if (landscape) {
              return Row(
                children: [
                  _canvas(box.maxHeight),
                  Expanded(child: panel),
                ],
              );
            }
            final side = box.maxWidth < box.maxHeight * .55
                ? box.maxWidth
                : box.maxHeight * .55;
            return Column(
              children: [
                Center(child: _canvas(side)),
                Expanded(child: panel),
              ],
            );
          },
        ),
      ),
    ),
  );
}
