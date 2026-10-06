// Taller de sigilos: lienzo arriba (en horizontal, a la izquierda) y la hoja
// con las pestañas Crear · Capas · Estilo · Guardar. El motor y el lienzo
// vienen del paquete arcanum_sigilos, probados contra el prototipo HTML.
// Flujo: intencion -> reduccion -> composicion -> carga -> olvido.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/astro/user_place.dart';
import '../../core/crypto/grimoire_crypto.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import 'sigil_radial.dart';
import 'sigil_store.dart';
import 'taller_carga.dart';
import 'taller_fuentes.dart';
import 'taller_panels.dart';

class TallerScreen extends ConsumerStatefulWidget {
  /// Entrada del Grimorio que se sigue editando (null: sigilo nuevo).
  final String? entryId;
  final SigilEntry? initial;
  const TallerScreen({super.key, this.entryId, this.initial});

  @override
  ConsumerState<TallerScreen> createState() => TallerScreenState();
}

class TallerScreenState extends ConsumerState<TallerScreen> {
  late SigilDoc doc = widget.initial?.doc ?? SigilDoc();

  /// Cargas ya anotadas (y las nuevas, hasta que se guarden).
  late final List<SigilCharge> _charges = [...?widget.initial?.charges];
  late CanvasController ctl = CanvasController(doc);
  late final TextEditingController _intention = TextEditingController(text: doc.sigil.intention);
  final _repaint = ValueNotifier<int>(0);
  int _tab = 0;
  GridMode _grid = GridMode.none;
  bool _letterColors = false, _addOpen = false, _saving = false, _transparent = false;
  late String? _savedId = widget.entryId;
  String? _savedSnapshot;

  @visibleForTesting
  SigilDoc get debugDoc => doc;

  // historial: fotos del documento (lo que decide el usuario)
  final List<String> _past = [], _future = [];

  @override
  void initState() {
    super.initState();
    _commit();
    if (_savedId != null) _savedSnapshot = _saveSnap;
  }

  @override
  void dispose() {
    _intention.dispose();
    _repaint.dispose();
    super.dispose();
  }

  String get _snap => jsonEncode(doc.toJson());

  /// Lo que se compara con lo guardado: documento y numero de cargas.
  String get _saveSnap => '${_charges.length}|$_snap';
  bool get _dirty => doc.sigil.prims.isNotEmpty && _saveSnap != _savedSnapshot;

  void _commit() {
    final s = _snap;
    if (_past.isNotEmpty && _past.last == s) return;
    _past.add(s);
    if (_past.length > 100) _past.removeAt(0);
    _future.clear();
  }

  void _restore(String s) {
    final terminals = (ctl.termPick, ctl.hideMode, ctl.magnet);
    doc = SigilDoc.fromJson(jsonDecode(s) as Map<String, dynamic>);
    ctl = CanvasController(doc)
      ..termPick = terminals.$1
      ..hideMode = terminals.$2
      ..magnet = terminals.$3;
    _intention.text = doc.sigil.intention;
  }

  void _undo() {
    if (_past.length < 2) return;
    setState(() {
      _future.add(_past.removeLast());
      _restore(_past.last);
    });
  }

  void _redo() {
    if (_future.isEmpty) return;
    setState(() {
      final s = _future.removeLast();
      _past.add(s);
      _restore(s);
    });
  }

  /// Cualquier cambio: repinta, refresca la hoja y entra en el historial.
  void _changed() {
    setState(() {});
    _repaint.value++;
    if (!ctl.dragging) _commit();
  }

  void _forge() {
    final text = _intention.text.trim();
    if (text.isEmpty) {
      _toast('Escribe una intención.');
      return;
    }
    FocusScope.of(context).unfocus();
    final ok = doc.generate(text);
    ctl
      ..sel = null
      ..layerSel = null;
    if (!ok) _toast('La intención no deja ninguna letra latina. Prueba otra reducción o escríbela de otra forma.');
    _changed();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  // ── Simbolos ──────────────────────────────────────────────────
  Future<void> _pickSymbol() async {
    final sym = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: ArcanumColors.surface,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .6,
        builder: (context, scroll) => ListView(controller: scroll, padding: const EdgeInsets.all(16), children: [
          Text('Símbolo', style: ArcanumText.heading(22)),
          Text('Elige uno y toca el lienzo donde quieras ponerlo.', style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)),
          for (final (group, items) in kStampCatalog) ...[
            sectionTitle(group),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final (s, name) in items)
                Tooltip(
                  message: name,
                  child: Semantics(
                    button: true,
                    label: name,
                    child: InkWell(
                      onTap: () => Navigator.pop(context, s),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(border: Border.all(color: ArcanumColors.surfaceHigh), borderRadius: BorderRadius.circular(6)),
                        child: Center(child: GlyphIcon(s, size: 28, color: ArcanumColors.goldLight)),
                      ),
                    ),
                  ),
                ),
            ]),
          ],
        ]),
      ),
    );
    if (sym == null || !mounted) return;
    ctl
      ..stampSym = sym
      ..stampMode = true
      ..termPick = false
      ..hideMode = false;
    _toast('${stampName(sym) ?? sym}: toca el lienzo para colocarlo.');
    setState(() {});
  }

  // ── Guardar, cargar, compartir ────────────────────────────────
  SigilStore get _store =>
      SigilStore(ref.read(arcanumApiProvider), ref.read(grimoireCryptoProvider), ref.read(userPlaceProvider), preview: ref.read(sigilPreviewProvider));

  Future<bool> _save() async {
    if (_saving) return false;
    setState(() => _saving = true);
    // la foto se toma ANTES de enviar: lo que se mueva durante el envio sigue
    // contando como cambio sin guardar
    final snap = _saveSnap;
    final entry = SigilEntry(SigilDoc.fromJson(doc.toJson()), charges: [..._charges]);
    try {
      _savedId = await _store.save(entry, entryId: _savedId);
      _savedSnapshot = snap;
      _toast('Sigilo guardado en tu Grimorio.');
      return true;
    } catch (e) {
      debugPrint('ARCANUM taller: fallo al guardar el sigilo ($e).');
      _toast('No se pudo guardar. Revisa la conexión e inténtalo de nuevo.');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _charge() async {
    final r = await Navigator.push<ChargeResult>(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => TallerCarga(doc: doc)));
    if (!mounted || r == null) return;
    if (r.end == ChargeEnd.keep) {
      _charges.add(await _store.chargeNow(r.seconds));
      if (mounted) await _save();
      return;
    }
    final saved = _savedId != null;
    if (!await confirmRelease(context, saved: saved) || !mounted) return;
    if (saved) {
      // la intencion se borra de la entrada; el dibujo queda con la fecha
      final charge = await _store.chargeNow(r.seconds);
      final out = releasedCopy(SigilEntry(doc, charges: [..._charges, charge]), DateTime.now());
      setState(() => _saving = true);
      try {
        await _store.save(out, entryId: _savedId);
      } catch (e) {
        debugPrint('ARCANUM taller: fallo al soltar el sigilo ($e).');
        _toast('No se pudo soltar: la intención sigue guardada. Revisa la conexión e inténtalo de nuevo.');
        return;
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
    if (!mounted) return;
    _savedSnapshot = _saveSnap;
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.pop(context, saved);
    messenger?.showSnackBar(const SnackBar(content: Text('Soltado. No lo busques.')));
  }

  Future<ui.Image> _render(int px) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(px / kSize);
    final s = doc.scene(transparent: _transparent);
    paintScene(c, s.bg);
    paintScene(c, s.fg);
    return rec.endRecording().toImage(px, px);
  }

  Future<void> _share({required bool png}) async {
    try {
      final dir = await getTemporaryDirectory();
      final String path;
      if (png) {
        final img = await _render(1600);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        img.dispose();
        path = '${dir.path}/arcanum-sigilo.png';
        await File(path).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
      } else {
        final keep = doc.transparent;
        doc.transparent = _transparent;
        // texto en trazos: se ve igual en cualquier programa, sin fuentes
        final svg = doc.buildSVG(outlineText: true);
        doc.transparent = keep;
        path = '${dir.path}/arcanum-sigilo.svg';
        await File(path).writeAsString(svg, flush: true);
      }
      await SharePlus.instance.share(ShareParams(files: [XFile(path, mimeType: png ? 'image/png' : 'image/svg+xml')]));
    } catch (e) {
      debugPrint('ARCANUM taller: no se pudo compartir ($e).');
      _toast('No se pudo preparar el archivo para compartir.');
    }
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ArcanumColors.surface,
        title: Text('¿Salir sin guardar?', style: ArcanumText.heading(22)),
        content: Text('Los cambios de este sigilo se perderán.', style: ArcanumText.body(15)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Seguir aquí')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salir')),
        ],
      ),
    );
    return leave == true;
  }

  // ── Pantalla ──────────────────────────────────────────────────
  Widget _canvasArea(double side) {
    final empty = doc.sigil.prims.isEmpty;
    return SizedBox.square(
      dimension: side,
      child: Stack(clipBehavior: Clip.hardEdge, children: [
        SigilCanvas(controller: ctl, grid: _grid, letterColors: _letterColors, repaint: _repaint, onChanged: _changed),
        if (empty)
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Escribe tu intención y pulsa «Forjar».', textAlign: TextAlign.center, style: ArcanumText.body(16, color: ArcanumColors.ivoryMuted, italic: true)),
              ),
            ),
          ),
        if (!empty) SelectionRadial(ctl: ctl, side: side, onEdited: _changed),
        if (!empty)
          Positioned.fill(
            child: AddRadial(
              open: _addOpen,
              onToggle: (v) => setState(() => _addOpen = v),
              onAdd: (t) {
                ctl.addLayer(t);
                _changed();
              },
              onSymbol: _pickSymbol,
              side: side,
            ),
          ),
      ]),
    );
  }

  Widget _panel() => switch (_tab) {
        0 => CrearPanel(ctl: ctl, intention: _intention, onForge: _forge, onChanged: _changed, letterColors: _letterColors, onLetterColors: (v) => setState(() => _letterColors = v)),
        1 => CapasPanel(ctl: ctl, onChanged: _changed, onAddSymbol: _pickSymbol),
        2 => EstiloPanel(doc: doc, onChanged: _changed),
        _ => GuardarPanel(
            saving: _saving,
            saved: _savedId != null,
            canSave: doc.sigil.prims.isNotEmpty,
            onCharge: _charge,
            onSave: _save,
            onSharePng: () => _share(png: true),
            onShareSvg: () => _share(png: false),
            transparent: _transparent,
            onTransparent: (v) => setState(() => _transparent = v),
          ),
      };

  static const _tabs = [(Icons.edit_outlined, 'Crear'), (Icons.layers_outlined, 'Capas'), (Icons.water_drop_outlined, 'Estilo'), (Icons.save_alt, 'Guardar')];

  Widget _tabBar() => Row(children: [
        for (var i = 0; i < _tabs.length; i++)
          Expanded(
            child: Semantics(
              selected: _tab == i,
              button: true,
              label: _tabs[i].$2,
              child: InkWell(
                onTap: () => setState(() => _tab = i),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _tab == i ? ArcanumColors.gold : ArcanumColors.surfaceHigh, width: 2))),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(_tabs[i].$1, size: 22, color: _tab == i ? ArcanumColors.gold : ArcanumColors.ivoryMuted),
                    Text(_tabs[i].$2, style: TextStyle(fontSize: 12, color: _tab == i ? ArcanumColors.gold : ArcanumColors.ivoryMuted)),
                  ]),
                ),
              ),
            ),
          ),
      ]);

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
          title: Text('Taller', style: ArcanumText.heading(20)),
          leading: IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close, color: ArcanumColors.ivoryMuted),
            onPressed: () async {
              if (await _confirmLeave() && context.mounted) Navigator.pop(context, _savedId != null);
            },
          ),
          actions: [
            IconButton(tooltip: 'Deshacer', icon: const Icon(Icons.undo), color: ArcanumColors.gold, onPressed: _past.length < 2 ? null : _undo),
            IconButton(tooltip: 'Rehacer', icon: const Icon(Icons.redo), color: ArcanumColors.gold, onPressed: _future.isEmpty ? null : _redo),
            IconButton(
              tooltip: switch (_grid) { GridMode.none => 'Rejilla: no', GridMode.polar => 'Rejilla polar', GridMode.square => 'Rejilla cuadrada' },
              icon: Icon(switch (_grid) { GridMode.none => Icons.grid_off, GridMode.polar => Icons.track_changes, GridMode.square => Icons.grid_on }),
              color: ArcanumColors.gold,
              onPressed: () => setState(() => _grid = GridMode.values[(_grid.index + 1) % 3]),
            ),
            IconButton(tooltip: 'Fuentes', icon: const Icon(Icons.menu_book_outlined), color: ArcanumColors.gold, onPressed: () => showTallerFuentes(context, doc)),
          ],
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(builder: (context, box) {
            final landscape = box.maxWidth > box.maxHeight;
            final panel = ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [_panel()]);
            if (landscape) {
              final side = box.maxHeight;
              return Row(children: [
                _canvasArea(side),
                Expanded(child: Column(children: [_tabBar(), Expanded(child: panel)])),
              ]);
            }
            // el lienzo deja sitio para la hoja: como mucho el 55 % del alto
            final side = box.maxWidth < box.maxHeight * .55 ? box.maxWidth : box.maxHeight * .55;
            return Column(children: [
              Center(child: _canvasArea(side)),
              _tabBar(),
              Expanded(child: panel),
            ]);
          }),
        ),
      ),
    );
  }
}
