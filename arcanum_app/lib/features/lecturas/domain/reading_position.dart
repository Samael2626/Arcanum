/// La posición estable dentro de una obra.
///
/// Nunca un número de página. La paginación depende del tamaño de letra, del
/// ancho de lectura, del idioma y de la pantalla: la página 47 de un móvil no
/// es la 47 de una tablet, ni la de hoy será la de mañana si el usuario sube
/// dos puntos la tipografía. Estas cuatro coordenadas sobreviven a todo eso, y
/// el lector reconstruye con ellas la página visual.
///
/// Es el mismo contrato que habla el backend en `/reading`.
library;

import 'package:flutter/foundation.dart';

@immutable
class ReadingPosition {
  final String workSlug;
  final String chapterSlug;

  /// Ancla del párrafo, estable entre reingestas de la obra.
  final String paragraphAnchor;

  /// Qué trozo del párrafo, cuando es demasiado largo para una pantalla.
  /// 0 es el párrafo entero o su primer fragmento.
  final int fragmentIndex;

  const ReadingPosition({
    required this.workSlug,
    required this.chapterSlug,
    required this.paragraphAnchor,
    this.fragmentIndex = 0,
  });

  ReadingPosition copyWith({String? paragraphAnchor, int? fragmentIndex}) =>
      ReadingPosition(
        workSlug: workSlug,
        chapterSlug: chapterSlug,
        paragraphAnchor: paragraphAnchor ?? this.paragraphAnchor,
        fragmentIndex: fragmentIndex ?? this.fragmentIndex,
      );

  factory ReadingPosition.fromJson(Map<String, dynamic> json) =>
      ReadingPosition(
        workSlug: json['work_slug'] as String,
        chapterSlug: json['chapter_slug'] as String,
        paragraphAnchor: json['paragraph_anchor'] as String,
        fragmentIndex: json['fragment_index'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'work_slug': workSlug,
    'chapter_slug': chapterSlug,
    'paragraph_anchor': paragraphAnchor,
    'fragment_index': fragmentIndex,
  };

  @override
  bool operator ==(Object other) =>
      other is ReadingPosition &&
      other.workSlug == workSlug &&
      other.chapterSlug == chapterSlug &&
      other.paragraphAnchor == paragraphAnchor &&
      other.fragmentIndex == fragmentIndex;

  @override
  int get hashCode =>
      Object.hash(workSlug, chapterSlug, paragraphAnchor, fragmentIndex);

  @override
  String toString() =>
      'ReadingPosition($workSlug/$chapterSlug#$paragraphAnchor:$fragmentIndex)';
}

/// Posición devuelta por el backend, ya con los títulos resueltos.
///
/// Los trae la respuesta para que "Pasajes guardados" pueda pintar obra y
/// capítulo sin una petición por fila.
@immutable
class ResolvedPosition {
  final ReadingPosition position;
  final String workTitle;
  final String chapterTitle;

  const ResolvedPosition({
    required this.position,
    required this.workTitle,
    required this.chapterTitle,
  });

  factory ResolvedPosition.fromJson(Map<String, dynamic> json) =>
      ResolvedPosition(
        position: ReadingPosition.fromJson(json),
        workTitle: json['work_title'] as String,
        chapterTitle: json['chapter_title'] as String,
      );
}
