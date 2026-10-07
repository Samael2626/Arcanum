// Pestañas de la hoja del taller: Crear, Capas, Estilo y Guardar.
// Lo basico a la vista; los ajustes finos dentro de «Ajustes finos».
import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/widgets/gold_button.dart';

/// Ayuda y procedencia de cada composicion (MODES del prototipo).
const kModeInfo = {
  ComposeMode.fusion: ('Fusión', 'Ocultismo moderno',
      'Todas las letras en la misma caja, una encima de otra. Los trazos que coinciden se comparten. Es el monograma de Spare: el más compacto y el menos legible.'),
  ComposeMode.block: ('Bloque', 'Fuente histórica y decisión de ARCANUM',
      'Cada letra en su celda; las celdas vecinas comparten el borde. Monograma de bloque, como los bizantinos. El solape acerca las letras hacia la fusión.'),
  ComposeMode.cross: ('Cruz', 'Fuente histórica',
      'Vocales fundidas en el centro y consonantes en los brazos de una cruz, como el monograma KAROLVS de Carlomagno (769). El más legible.'),
};

const kMethodLabels = {
  ReductionMethod.cooper: 'Iniciales (Cooper)',
  ReductionMethod.novowels: 'Únicas sin vocales',
  ReductionMethod.unique: 'Letras únicas',
};

Widget sectionTitle(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
      child: Text(t.toUpperCase(), style: ArcanumText.label().copyWith(color: ArcanumColors.goldLabel)),
    );

Widget _chip(String label, bool on, VoidCallback onTap) => ChoiceChip(
      label: Text(label),
      selected: on,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: TextStyle(color: on ? ArcanumColors.background : ArcanumColors.ivory, fontSize: 14),
      selectedColor: ArcanumColors.gold,
      backgroundColor: ArcanumColors.surfaceHigh,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      side: const BorderSide(color: ArcanumColors.goldMuted),
    );

Widget _switch(String label, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: ArcanumText.body(15)),
      value: value,
      activeThumbColor: ArcanumColors.gold,
      onChanged: onChanged,
    );

// ── Crear ───────────────────────────────────────────────────────
class CrearPanel extends StatelessWidget {
  final CanvasController ctl;
  final TextEditingController intention;
  final VoidCallback onForge, onChanged;
  final bool letterColors;
  final ValueChanged<bool> onLetterColors;
  const CrearPanel({super.key, required this.ctl, required this.intention, required this.onForge, required this.onChanged, required this.letterColors, required this.onLetterColors});

  @override
  Widget build(BuildContext context) {
    final sg = ctl.doc.sigil, mode = kModeInfo[sg.mode]!;
    void set(VoidCallback f) {
      f();
      onChanged();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      sectionTitle('Intención'),
      TextField(
        controller: intention,
        minLines: 1,
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
        // la intencion es intima y se suelta: el teclado no la sugiere, no la
        // corrige y no aprende de ella
        enableSuggestions: false,
        autocorrect: false,
        enableIMEPersonalizedLearning: false,
        style: ArcanumText.body(16),
        decoration: const InputDecoration(hintText: 'Una frase en presente, propia y sin daño a terceros'),
        onSubmitted: (_) => onForge(),
      ),
      const SizedBox(height: 10),
      GoldButton(label: 'Forjar', onPressed: onForge),
      sectionTitle('Composición'),
      Wrap(spacing: 8, children: [
        for (final m in ComposeMode.values)
          _chip(kModeInfo[m]!.$1, sg.mode == m, () => set(() {
                sg.mode = m;
                for (final l in sg.letters) {
                  l.user = LetterEdit();
                }
                sg.hidden = [];
                if (sg.letters.isNotEmpty) sg.applyLayout(contentR: ctl.doc.layout.contentR);
              })),
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text('${mode.$3} (${mode.$2}.)', style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted, italic: true)),
      ),
      if (sg.letters.isNotEmpty) ...[
        sectionTitle('Letras'),
        Text(
          sg.letters.map((l) => l.twin != null ? '${l.ch} (dentro de ${l.twin!.by})' : '${l.ch} ${(l.legible * 100).round()} %').join('   '),
          style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
        ),
        Text('Toca una letra en el lienzo para girarla, reflejarla o escalarla; arrástrala para moverla. Con dos dedos la escalas y la giras a la vez.', style: ArcanumText.body(12, color: ArcanumColors.goldMuted, italic: true)),
      ],
      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('Ajustes finos', style: ArcanumText.body(15, color: ArcanumColors.gold)),
          children: [
            Align(alignment: Alignment.centerLeft, child: sectionTitle('Reducción')),
            Wrap(spacing: 8, children: [
              for (final m in ReductionMethod.values)
                _chip(kMethodLabels[m]!, sg.method == m, () => set(() {
                      sg.method = m;
                      if (sg.intention.isNotEmpty) {
                        final t = sg.intention;
                        sg.intention = '';
                        ctl.doc.generate(t);
                      }
                    })),
            ]),
            _switch('Absorber letras gemelas (M/W, N/Z)', sg.absorb, (v) => set(() {
                  sg.absorb = v;
                  if (sg.letters.isNotEmpty) sg.applyLayout(contentR: ctl.doc.layout.contentR);
                })),
            if (sg.mode == ComposeMode.fusion)
              _switch('Encaje compacto', sg.compact, (v) => set(() {
                    sg.compact = v;
                    if (sg.letters.isNotEmpty) sg.applyLayout(contentR: ctl.doc.layout.contentR);
                  })),
            if (sg.mode == ComposeMode.block)
              Row(children: [
                Text('Solape', style: ArcanumText.body(14)),
                Expanded(
                  child: Slider(
                    value: sg.overlap,
                    max: .5,
                    activeColor: ArcanumColors.gold,
                    onChanged: (v) => set(() {
                      sg.overlap = v;
                      if (sg.letters.isNotEmpty) sg.applyLayout(contentR: ctl.doc.layout.contentR);
                    }),
                  ),
                ),
              ]),
            Align(alignment: Alignment.centerLeft, child: sectionTitle('Remates')),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in kTerminals)
                Tooltip(
                  message: t.name,
                  child: InkWell(
                    onTap: () => set(() {
                      if (ctl.termPick) {
                        ctl.termBrush = t.id;
                      } else {
                        ctl.doc.terminals = t.id;
                      }
                    }),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        border: Border.all(color: (ctl.termPick ? ctl.termBrush : ctl.doc.terminals) == t.id ? ArcanumColors.gold : ArcanumColors.surfaceHigh),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(child: TerminalIcon(t.id, color: ArcanumColors.goldLight)),
                    ),
                  ),
                ),
            ]),
            _switch('Uno a uno: toca las puntas en el lienzo', ctl.termPick, (v) => set(() {
                  ctl
                    ..termPick = v
                    ..hideMode = false
                    ..stampMode = false;
                  if (v && ctl.termBrush == 'none') ctl.termBrush = 'pattee';
                })),
            _switch('Ocultar trazos: toca un trazo en el lienzo', ctl.hideMode, (v) => set(() {
                  ctl
                    ..hideMode = v
                    ..termPick = false
                    ..stampMode = false;
                })),
            _switch('Colorear letras (solo en pantalla)', letterColors, onLetterColors),
          ],
        ),
      ),
    ]);
  }
}

// ── Capas ───────────────────────────────────────────────────────
class CapasPanel extends StatelessWidget {
  final CanvasController ctl;
  final VoidCallback onChanged, onAddSymbol;
  const CapasPanel({super.key, required this.ctl, required this.onChanged, required this.onAddSymbol});

  @override
  Widget build(BuildContext context) {
    final layers = ctl.doc.layers;
    void set(VoidCallback f) {
      f();
      ctl.doc.refit();
      onChanged();
    }

    final sel = ctl.selectedLayer;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      sectionTitle('Capas'),
      if (layers.isEmpty) Text('Sin capas. Añade una con el botón + del lienzo o carga una plantilla.', style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)),
      for (var i = 0; i < layers.length; i++)
        Material(
          color: layers[i].id == ctl.layerSel ? ArcanumColors.surfaceHigh : Colors.transparent,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Checkbox(value: layers[i].visible, activeColor: ArcanumColors.gold, onChanged: (v) => set(() => layers[i].visible = v ?? true)),
            title: Text(layers[i].type == LayerType.symbol ? 'Símbolo · ${stampName(layers[i].sym) ?? layers[i].sym}' : layers[i].name, style: ArcanumText.body(15)),
            onTap: () => set(() {
              ctl
                ..layerSel = layers[i].id == ctl.layerSel ? null : layers[i].id
                ..sel = null;
            }),
            trailing: layers[i].id != ctl.layerSel
                ? null
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(tooltip: 'Más afuera', icon: const Icon(Icons.arrow_upward), color: ArcanumColors.gold, onPressed: i == 0 ? null : () => set(() => ctl.moveLayer(layers[i].id, -1))),
                    IconButton(tooltip: 'Más adentro', icon: const Icon(Icons.arrow_downward), color: ArcanumColors.gold, onPressed: i == layers.length - 1 ? null : () => set(() => ctl.moveLayer(layers[i].id, 1))),
                    IconButton(tooltip: 'Quitar', icon: const Icon(Icons.delete_outline), color: ArcanumColors.gold, onPressed: () => set(() => ctl.removeLayer(layers[i].id))),
                  ]),
          ),
        ),
      if (sel != null) _LayerEditor(layer: sel, onChanged: () => set(() {})),
      sectionTitle('Plantillas (sustituyen las capas)'),
      Wrap(spacing: 8, children: [
        _chip('Goetia', false, () => set(() => _template(LayerType.ringLatin))),
        _chip('Pentáculo', false, () => set(() => _template(LayerType.ringHebrew))),
        _chip('Agrippa', false, () => set(() => _template(LayerType.caption))),
        _chip('Vaciar', false, () => set(() {
              layers.clear();
              ctl.layerSel = null;
            })),
      ]),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: onAddSymbol,
        icon: const GlyphIcon('♃', size: 20, color: ArcanumColors.gold),
        label: const Text('Añadir un símbolo'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: ArcanumColors.gold),
      ),
    ]);
  }

  void _template(LayerType t) {
    ctl.doc.layers.clear();
    ctl.addLayer(t);
    ctl.layerSel = null;
  }
}

class _LayerEditor extends StatelessWidget {
  final Layer layer;
  final VoidCallback onChanged;
  const _LayerEditor({required this.layer, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l = layer;
    void set(VoidCallback f) {
      f();
      onChanged();
    }

    final ring = l.type == LayerType.ringLatin || l.type == LayerType.ringHebrew;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 0, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (ring || l.type == LayerType.inscription)
          TextFormField(
            key: ValueKey('texto-${l.id}'),
            initialValue: l.text,
            style: ArcanumText.body(15),
            decoration: InputDecoration(hintText: ring ? 'Texto (vacío: la intención)' : 'Lema, nombre o frase'),
            onChanged: (v) => set(() => l.text = v),
          ),
        if (l.type == LayerType.caption) ...[
          TextFormField(key: ValueKey('titulo-${l.id}'), initialValue: l.title, style: ArcanumText.body(15), decoration: const InputDecoration(hintText: 'Título (vacío: automático)'), onChanged: (v) => set(() => l.title = v)),
          TextFormField(key: ValueKey('sub-${l.id}'), initialValue: l.sub, style: ArcanumText.body(15), decoration: const InputDecoration(hintText: 'Subtítulo (vacío: automático)'), onChanged: (v) => set(() => l.sub = v)),
        ],
        if (ring) ...[
          Wrap(spacing: 8, children: [
            for (final (k, n) in const [('none', 'Sin separador'), ('dot', 'Puntos'), ('cross', 'Cruces')]) _chip(n, l.sep == k, () => set(() => l.sep = k)),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: [
            _chip('Sin símbolo', l.symbol.isEmpty, () => set(() => l.symbol = '')),
            for (final p in kPlanetOrder)
              ChoiceChip(
                label: GlyphIcon(kPlanetGlyph[p]!, size: 18, color: l.symbol == p ? ArcanumColors.background : ArcanumColors.goldLight),
                selected: l.symbol == p,
                showCheckmark: false,
                tooltip: kPlanetNames[p],
                selectedColor: ArcanumColors.gold,
                backgroundColor: ArcanumColors.surfaceHigh,
                onSelected: (_) => set(() => l.symbol = p),
              ),
          ]),
        ],
        if (l.type == LayerType.star)
          Wrap(spacing: 8, children: [
            for (final n in const [5, 6, 7, 8, 9]) _chip('$n puntas', l.points == n, () => set(() => l.points = n)),
            _chip('Angulosa', l.shape == 'sharp', () => set(() => l.shape = 'sharp')),
            _chip('Ancha', l.shape == 'wide', () => set(() => l.shape = 'wide')),
          ]),
        if (l.type == LayerType.inscription)
          Wrap(spacing: 8, children: [
            for (final (k, n) in const [('upperArc', 'Arco superior'), ('lowerArc', 'Arco inferior'), ('top', 'Arriba'), ('bottom', 'Abajo')]) _chip(n, l.pos == k, () => set(() => l.pos = k)),
          ]),
        Text('En el lienzo: arrástrala para moverla y tócala para escalarla o girarla. Con dos dedos, las dos cosas a la vez.', style: ArcanumText.body(12, color: ArcanumColors.goldMuted, italic: true)),
      ]),
    );
  }
}

// ── Estilo ──────────────────────────────────────────────────────
class EstiloPanel extends StatelessWidget {
  final SigilDoc doc;
  final VoidCallback onChanged;
  const EstiloPanel({super.key, required this.doc, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    void set(SigilStyle s) {
      doc.style = s;
      onChanged();
    }

    final st = doc.style;
    // cambiar de estilo no borra la caligrafia elegida (como en el prototipo)
    void setPreset(SigilStyle s) => set(s.copyWith(calli: st.calli));
    Widget swatch(SigilStyle s, String label, {String glyph = '✦'}) {
      final on = st.preset == s.preset;
      final bg = s.metal != null ? null : Color(0xFF000000 | int.parse(s.bg.substring(1), radix: 16));
      final grad = s.metal != null ? LinearGradient(colors: [_hex(kMetalTone[s.metal]!.$1), _hex(kMetalTone[s.metal]!.$2)]) : null;
      return Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: () => setPreset(s),
          child: SizedBox(
            width: 70,
            child: Column(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: bg, gradient: grad, shape: BoxShape.circle, border: Border.all(color: on ? ArcanumColors.goldLight : ArcanumColors.surfaceHigh, width: on ? 2 : 1)),
                child: Center(child: GlyphIcon(glyph, size: 22, color: _hex(s.ink))),
              ),
              const SizedBox(height: 3),
              Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: on ? ArcanumColors.gold : ArcanumColors.ivoryMuted, fontSize: 11, height: 1.15)),
            ]),
          ),
        ),
      );
    }

    final today = DateTime.now();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      sectionTitle('Estilos'),
      SizedBox(
        // circulo de 48 + nombre en dos lineas
        height: 100,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final k in kStylePresetLabels.keys) swatch(presetStyle(k, today: today), kStylePresetLabels[k]!),
        ]),
      ),
      sectionTitle('Relampagueantes: el color del planeta y su complementario'),
      SizedBox(
        // circulo de 48 + nombre en dos lineas
        height: 100,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final p in kPlanetOrder) swatch(flashStyle(p), kPlanetNames[p]!, glyph: kPlanetGlyph[p]!),
        ]),
      ),
      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('Ajustar', style: ArcanumText.body(15, color: ArcanumColors.gold)),
          children: [
            Align(alignment: Alignment.centerLeft, child: sectionTitle('Tinta')),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (n, c) in [...kInks, for (final p in kPlanetOrder) ('${kPlanetNames[p]} (${kPlanetColor[p]!.$1})', kPlanetColor[p]!.$2)])
                _dot(n, _hex(c), st.ink == c, () => set(st.copyWith(ink: c, preset: 'propio'))),
            ]),
            Align(alignment: Alignment.centerLeft, child: sectionTitle('Soporte')),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (n, c) in kGrounds) _dot(n, _hex(c), st.metal == null && st.bg == c, () => set(st.copyWith(bg: c, clearMetal: true, preset: 'propio'))),
              for (final p in kPlanetOrder)
                _dot('${kPlanetMetal[p]} (${kPlanetNames[p]})', _hex(kMetalTone[kPlanetMetal[p]]!.$1), st.metal == kPlanetMetal[p], () {
                  final m = metalStyle(p);
                  set(st.copyWith(bg: m.bg, metal: m.metal, metalPlanet: p, texture: 'none', preset: 'propio'));
                }),
            ]),
            _switch('Textura de pergamino', st.texture == 'pergamino', st.metal != null ? (_) {} : (v) => set(st.copyWith(texture: v ? 'pergamino' : 'none', preset: 'propio'))),
            Row(children: [
              Text('Grosor', style: ArcanumText.body(14)),
              Expanded(child: Slider(value: st.width, min: 50, max: 180, divisions: 26, label: '${st.width.round()} %', activeColor: ArcanumColors.gold, onChanged: (v) => set(st.copyWith(width: v, preset: 'propio')))),
            ]),
            Align(alignment: Alignment.centerLeft, child: sectionTitle('Caligrafía')),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final (k, n) in const [('none', 'Recta'), ('curva', 'Curva'), ('pluma', 'Pluma')])
                _chip(n, st.calli == k, () => set(st.copyWith(calli: k, preset: 'propio'))),
            ]),
            Text('Solo cambia cómo se pinta: los trazos, sus extremos y sus cruces son los mismos. Con Pluma, la línea doble no se aplica.',
                style: ArcanumText.body(12, color: ArcanumColors.goldMuted, italic: true)),
            _switch('Línea doble', st.line == 'double', (v) => set(st.copyWith(line: v ? 'double' : 'single', preset: 'propio'))),
            _switch('Punta recta', st.cap == 'square', (v) => set(st.copyWith(cap: v ? 'square' : 'round', preset: 'propio'))),
            _switch('Relieve (grabado)', st.relief, (v) => set(st.copyWith(relief: v, preset: 'propio'))),
            _switch('Resplandor', st.glow, (v) => set(st.copyWith(glow: v, preset: 'propio'))),
          ],
        ),
      ),
      Text(_styleSource(st), style: ArcanumText.body(12, color: ArcanumColors.goldMuted, italic: true)),
    ]);
  }

  static Widget _dot(String label, Color c, bool on, VoidCallback onTap) => Tooltip(
        message: label,
        child: Semantics(
          button: true,
          label: label,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(width: 44, height: 44, margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: on ? ArcanumColors.goldLight : ArcanumColors.surfaceHigh, width: on ? 3 : 1))),
          ),
        ),
      );

  static String _styleSource(SigilStyle st) {
    if (st.preset.startsWith('flash-')) {
      final p = st.preset.substring(6);
      return 'Relampagueante de ${kPlanetNames[p]}: campo en su color de la escala del Rey y signo en el complementario (Flying Roll XIV: «una tabla relampagueante es la que se hace en los colores complementarios»). Ocultismo moderno.'
          '${p == 'saturn' ? ' El ámbar de Saturno es reconstrucción: el índigo no está en esos pares.' : ''}';
    }
    if (st.metal != null) return 'Soporte de ${st.metal}, el metal de ${kPlanetNames[st.metalPlanet] ?? 'su planeta'} en la Goetia (p. 48): fuente histórica. El brillo y el relieve son del taller.';
    return 'Tintas, soportes y efectos: decisiones del taller.';
  }
}

Color _hex(String h) => Color(0xFF000000 | int.parse(h.substring(1), radix: 16));

// ── Guardar ─────────────────────────────────────────────────────
class GuardarPanel extends StatelessWidget {
  final bool saving, saved, canSave;
  final VoidCallback onCharge, onSave, onSharePng, onShareSvg;
  final bool transparent;
  final ValueChanged<bool> onTransparent;
  const GuardarPanel({super.key, required this.saving, required this.saved, required this.canSave, required this.onCharge, required this.onSave, required this.onSharePng, required this.onShareSvg, required this.transparent, required this.onTransparent});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      sectionTitle('Cargar'),
      Text('Contempla el sigilo con la respiración. Al terminar decides si lo guardas o lo olvidas.', style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: canSave ? onCharge : null, style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: ArcanumColors.gold), child: const Text('Cargar')),
      sectionTitle('Guardar'),
      Text('Se guarda en tu Grimorio, cifrado como el resto de tus entradas. El título no lleva la intención.', style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)),
      const SizedBox(height: 8),
      GoldButton(label: saved ? 'Guardar cambios' : 'Guardar en el Grimorio', loading: saving, onPressed: canSave ? onSave : null),
      sectionTitle('Compartir'),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: canSave ? onSharePng : null, style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: ArcanumColors.gold), child: const Text('Imagen (PNG)'))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton(onPressed: canSave ? onShareSvg : null, style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: ArcanumColors.gold), child: const Text('Vector (SVG)'))),
      ]),
      _switch('Fondo transparente al compartir', transparent, onTransparent),
    ]);
  }
}
