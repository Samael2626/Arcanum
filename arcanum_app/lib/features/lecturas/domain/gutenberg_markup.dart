/// Marcado de Project Gutenberg: lo que sobra fuera, lo que significa en cursiva.
///
/// Las transcripciones de Gutenberg son texto plano y marcan la cursiva del
/// original impreso rodeando la palabra con guiones bajos (`_asi_). Las notas
/// editoriales del propio Gutenberg van ademas entre corchetes. Sin limpiar,
/// el lector enseñaba literalmente `_Descript._]` al abrir Agrimony y `_o_` en
/// Plate 1: el marcado crudo delante del lector, en todos los capitulos.
///
/// Todo lo de aqui es puro y sin Flutter salvo el estilo: recibe texto y
/// devuelve texto o tramos. Se prueba sin pantalla.
library;

import 'package:flutter/foundation.dart';

/// Un tramo de texto y si va en cursiva.
@immutable
class MarkupRun {
  final String text;
  final bool italic;

  const MarkupRun(this.text, {this.italic = false});

  @override
  bool operator ==(Object other) =>
      other is MarkupRun && other.text == text && other.italic == italic;

  @override
  int get hashCode => Object.hash(text, italic);

  @override
  String toString() => italic ? '_${text}_' : text;
}

/// Un tramo en cursiva: `_texto_` sin saltos de linea en medio.
///
/// Se exige que abra y cierre en la misma linea para no tragarse medio parrafo
/// cuando aparece un guion bajo suelto, que en estos textos pasa.
final _enfasis = RegExp(r'_([^_\n]+)_');

/// La misma cursiva, con los corchetes de nota editorial alrededor.
///
/// Cubre las tres formas que deja la ingesta: `[_Descript._]` entera, y las dos
/// mitades sueltas `_Descript._]` y `[_Descript._`, que es como aparecian en el
/// aparato porque el corchete de apertura se pierde antes de llegar aqui.
final _corchetesDeNota = RegExp(r'\[(_[^_\n]+_)\]|(_[^_\n]+_)\]|\[(_[^_\n]+_)');

/// Quita los corchetes editoriales y deja intacto el marcado de cursiva.
///
/// Se aplica antes de paginar para que lo que se mide sea lo que se pinta. Los
/// guiones bajos siguen ahi a proposito: [runsDeMarcado] los necesita al pintar,
/// y son lo bastante estrechos como para que la medida solo peque de prudente.
String limpiarNotasEditoriales(String texto) => texto.replaceAllMapped(
      _corchetesDeNota,
      (m) => m.group(1) ?? m.group(2) ?? m.group(3)!,
    );

/// Parte el texto en tramos rectos y en cursiva.
///
/// Tolera el marcado a medias: el paginador corta por palabras, asi que un
/// `_asi_` puede quedar partido entre dos paginas. Un guion bajo sin pareja se
/// trata como texto normal en lugar de poner en cursiva lo que queda de pagina.
List<MarkupRun> runsDeMarcado(String texto) {
  final runs = <MarkupRun>[];
  var cursor = 0;

  for (final m in _enfasis.allMatches(texto)) {
    if (m.start > cursor) {
      runs.add(MarkupRun(texto.substring(cursor, m.start)));
    }
    runs.add(MarkupRun(m.group(1)!, italic: true));
    cursor = m.end;
  }
  if (cursor < texto.length) {
    runs.add(MarkupRun(texto.substring(cursor)));
  }
  return runs.isEmpty ? const [MarkupRun('')] : runs;
}
