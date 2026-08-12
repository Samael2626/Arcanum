/// Paginación real de un capítulo: fragmentos que caben en una pantalla.
///
/// No es una lista larga disfrazada de libro. Cada página se compone midiendo
/// el texto contra el alto disponible, así que nunca hay recorte, ni scroll
/// escondido, ni una línea que se pierda al pasar de página.
///
/// Todo lo de aquí es puro: recibe una función de medida y devuelve datos. La
/// medida real la pone el lector con un `TextPainter`; los tests ponen una
/// falsa y comprueban el reparto sin necesitar pantalla.
library;

import 'package:flutter/foundation.dart';

/// Un párrafo tal y como llega de la obra.
@immutable
class ParagraphSource {
  final String anchor;
  final String text;

  const ParagraphSource({required this.anchor, required this.text});
}

/// Un trozo de párrafo que cabe entero en una página.
///
/// [fragmentIndex] es el índice DENTRO de su párrafo, no dentro del capítulo:
/// junto al ancla forma la posición estable que se guarda en el servidor.
@immutable
class ReaderFragment {
  final String anchor;
  final int fragmentIndex;
  final String text;

  /// True si el párrafo original se partió y este no es su primer trozo. El
  /// lector lo usa para no volver a sangrar el arranque a media frase.
  final bool isContinuation;

  /// True si tras este fragmento el párrafo continúa en la página siguiente.
  final bool continuesAfter;

  const ReaderFragment({
    required this.anchor,
    required this.fragmentIndex,
    required this.text,
    this.isContinuation = false,
    this.continuesAfter = false,
  });
}

/// Una página: los fragmentos que caben juntos en la pantalla.
@immutable
class ReaderPage {
  final List<ReaderFragment> fragments;

  const ReaderPage(this.fragments);

  bool get isEmpty => fragments.isEmpty;

  /// El fragmento que define la posición de la página: el primero.
  ReaderFragment get first => fragments.first;
}

/// Mide el alto que ocuparía [text]. La pone el lector con la tipografía real.
typedef MeasureText = double Function(String text);

/// Reparte un capítulo en páginas.
///
/// [pageHeight] es el alto útil, ya descontadas cabecera y barra inferior.
/// [paragraphSpacing] es el hueco entre párrafos, que también ocupa sitio y por
/// eso entra en la cuenta: ignorarlo es justo lo que produce el desbordamiento
/// de la última línea.
List<ReaderPage> paginateChapter({
  required List<ParagraphSource> paragraphs,
  required MeasureText measure,
  required double pageHeight,
  double paragraphSpacing = 0,
}) {
  if (pageHeight <= 0) {
    // Todavía no hay layout: una sola página con todo, que es lo que se pinta
    // durante el primer frame antes de conocer el tamaño real.
    return [
      ReaderPage([
        for (var i = 0; i < paragraphs.length; i++)
          ReaderFragment(
            anchor: paragraphs[i].anchor,
            fragmentIndex: 0,
            text: paragraphs[i].text,
          ),
      ]),
    ];
  }

  final pages = <ReaderPage>[];
  var current = <ReaderFragment>[];
  var used = 0.0;

  void flush() {
    if (current.isNotEmpty) {
      pages.add(ReaderPage(List.unmodifiable(current)));
      current = <ReaderFragment>[];
      used = 0.0;
    }
  }

  for (final paragraph in paragraphs) {
    final pieces = _splitToFit(paragraph.text, measure, pageHeight);

    for (var i = 0; i < pieces.length; i++) {
      final piece = pieces[i];
      final height = measure(piece);
      final spacing = current.isEmpty ? 0.0 : paragraphSpacing;

      // Si no cabe, la página se cierra aquí. Nunca se recorta el fragmento:
      // ya viene medido para caber por si solo en una pagina vacia.
      if (current.isNotEmpty && used + spacing + height > pageHeight) {
        flush();
      }

      current.add(
        ReaderFragment(
          anchor: paragraph.anchor,
          fragmentIndex: i,
          text: piece,
          isContinuation: i > 0,
          continuesAfter: i < pieces.length - 1,
        ),
      );
      used += (current.length == 1 ? 0.0 : paragraphSpacing) + height;
    }
  }
  flush();

  // Un capítulo sin párrafos sigue siendo una página: la de su cierre.
  return pages.isEmpty ? [const ReaderPage([])] : pages;
}

/// Parte un texto en trozos que quepan, cortando SOLO entre palabras.
///
/// Nunca parte una palabra por la mitad: se corta en los espacios, así que no
/// aparecen letras sueltas al final de una página. Y no se pierde nada — unir
/// los trozos con un espacio devuelve el texto original normalizado, que es lo
/// que comprueba el test.
List<String> _splitToFit(String text, MeasureText measure, double maxHeight) {
  final normalized = text.trim();
  if (normalized.isEmpty) return const [''];
  if (measure(normalized) <= maxHeight) return [normalized];

  final words = normalized.split(RegExp(r'\s+'));
  final pieces = <String>[];
  var start = 0;

  while (start < words.length) {
    // Búsqueda binaria del último corte que cabe. Lineal palabra a palabra
    // costaria una medida por palabra, y Culpeper tiene parrafos de miles.
    var low = start + 1;
    var high = words.length;
    var best = start + 1;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (measure(words.sublist(start, mid).join(' ')) <= maxHeight) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    // Al menos una palabra por trozo: garantiza que el bucle avanza aunque una
    // palabra sola no quepa (una URL enorme, por ejemplo).
    pieces.add(words.sublist(start, best).join(' '));
    start = best;
  }
  return pieces;
}

/// En qué página cae una posición guardada.
///
/// Aquí es donde la posición estable se convierte en página visual. Si el
/// fragmento exacto ya no existe — el usuario cambió el tamaño de letra y el
/// párrafo ahora se parte en menos trozos — cae al último fragmento de ese
/// párrafo en vez de mandarlo al principio del capítulo: reanudar en el
/// párrafo correcto importa mucho más que el trozo exacto.
///
/// Devuelve 0 si el ancla no aparece: es un capítulo distinto o una obra
/// reingestada, y empezar por el principio es la única respuesta honesta.
int pageIndexForPosition(
  List<ReaderPage> pages, {
  required String paragraphAnchor,
  int fragmentIndex = 0,
}) {
  var fallback = -1;

  for (var p = 0; p < pages.length; p++) {
    for (final fragment in pages[p].fragments) {
      if (fragment.anchor != paragraphAnchor) continue;
      if (fragment.fragmentIndex == fragmentIndex) return p;
      fallback = p;
    }
  }
  return fallback >= 0 ? fallback : 0;
}
