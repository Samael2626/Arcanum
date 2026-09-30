// Documento del sigilo de letras: letras + capas + remates + estilo. Produce
// la escena (lienzo) y el SVG exportado desde la misma lista de grupos
// (lettersScene y buildSVG del prototipo, familia «letras»).
import 'dart:convert';

import 'geometry.dart';
import 'layers.dart';
import 'letter_sigil.dart';
import 'scene.dart';
import 'style.dart';
import 'terminals.dart';

class LettersScene {
  final List<SceneGroup> bg, fg;
  const LettersScene(this.bg, this.fg);
}

class SigilDoc {
  final LetterSigil sigil;
  List<Layer> layers;
  SigilStyle style;
  String terminals;
  Map<String, String> endStyles;
  double termScale;
  bool transparent;

  SigilDoc({LetterSigil? sigil, List<Layer>? layers, this.style = const SigilStyle(), this.terminals = 'none', Map<String, String>? endStyles,
      this.termScale = 100, this.transparent = false})
      : sigil = sigil ?? LetterSigil(),
        layers = layers ?? [],
        endStyles = endStyles ?? {};

  LayerCtx get ctx => LayerCtx.letters(sigil.intention);

  // la disposicion de capas es pura (capas + texto): se calcula una vez por
  // estado y la reusan pintado, toque, guias y radial
  String? _layKey;
  LayerLayout? _lay;
  LayerLayout get layout {
    final key = '${sigil.intention}|${jsonEncode([for (final l in layers) l.toJson()])}';
    if (key != _layKey) {
      _lay = layoutLayers(layers, ctx);
      _layKey = key;
    }
    return _lay!;
  }
  SigilTheme get theme => themeFor(style);

  /// Claves de lo que no cambia mientras se arrastra una letra: permiten
  /// guardar grabados el soporte y las capas.
  String get layoutKey {
    layout;
    return _layKey!;
  }

  String get styleKey => jsonEncode(style.toJson());

  /// Reduce y compone la intencion dentro del hueco que dejan los marcos.
  bool generate(String text) {
    // el hueco no depende del texto, solo de la geometria de los marcos
    final contentR = layoutLayers(layers, LayerCtx.letters(text)).contentR;
    final changed = sigil.intention != text;
    final ok = sigil.generate(text, contentR: contentR);
    if (changed) endStyles = {};
    return ok;
  }

  /// Tras tocar capas: el sigilo se vuelve a encuadrar en el hueco.
  void refit() {
    if (sigil.prims.isNotEmpty) sigil.view = sigil.fitView(layout.contentR);
  }

  void rebuild() => sigil.rebuild(contentR: layout.contentR);

  List<TerminalMark> terminalMarks(List<Prim> visible) =>
      terminalList(sigil, visible, general: terminals, perEnd: endStyles, scale: termScale);

  LettersScene scene({bool transparent = false}) {
    final th = theme, lw = kLineW * style.width / 100;
    final lay = layout;
    final visible = sigil.visible;
    final fg = <SceneGroup>[
      for (final p in lay.parts)
        if (p.layer.type != LayerType.symbol) SceneGroup(layer: p.layer.type.name, color: th.ink, prims: p.g.prims),
      SceneGroup(layer: 'core', color: th.ink, w: lw, cap: style.cap, sigil: true, items: [
        for (final p in visible) PathItem(sigil.primPath(p), units: p.units),
      ]),
    ];
    final marks = terminalMarks(visible);
    if (marks.isNotEmpty) {
      fg.add(SceneGroup(layer: 'terminals', color: th.ink, w: lw * .8, cap: style.cap, sigil: true, items: [
        for (final t in marks)
          for (final sh in t.shapes) PathItem(sh.d, fill: sh.fill),
      ]));
    }
    for (final p in lay.parts) {
      if (p.layer.type == LayerType.symbol) fg.add(SceneGroup(layer: 'symbol', color: th.ink, prims: p.g.prims));
    }
    return LettersScene(transparent ? const [] : bgScene(style, th), applyFx(fg.where((g) => !g.isEmpty).toList(), style, th));
  }

  /// SVG exportado: el mismo que dibuja el lienzo, sin marcas de edicion.
  String buildSVG() {
    final out = StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800" width="800" height="800">');
    if (!transparent) out.write(sceneSVG(bgScene(style, theme)));
    if (sigil.prims.isNotEmpty && sigil.view != null) out.write(sceneSVG(scene(transparent: true).fg));
    out.write('</svg>');
    return out.toString();
  }
}
