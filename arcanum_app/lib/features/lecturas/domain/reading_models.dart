/// La relación privada del usuario con lo que lee.
///
/// La Biblioteca es pública e igual para todos; esto es de cada cual y viaja
/// autenticado. Las notas de los pasajes van CIFRADAS con la misma clave del
/// Grimorio: el servidor guarda opacos y no puede leerlas.
library;

import 'package:flutter/foundation.dart';

import 'reading_position.dart';

/// Dónde se quedó el usuario en una obra. Una por obra.
@immutable
class ReadingProgress {
  final String id;
  final ResolvedPosition where;

  /// En qué idioma venía leyendo. Reanudar en castellano lo que se leía en el
  /// original rompe la continuidad.
  final bool spanish;
  final DateTime updatedAt;

  const ReadingProgress({
    required this.id,
    required this.where,
    required this.spanish,
    required this.updatedAt,
  });

  ReadingPosition get position => where.position;

  factory ReadingProgress.fromJson(Map<String, dynamic> json) => ReadingProgress(
    id: json['id'] as String,
    where: ResolvedPosition.fromJson(json['position'] as Map<String, dynamic>),
    spanish: (json['language'] as String? ?? 'es') == 'es',
    updatedAt:
        DateTime.tryParse(json['updated_at'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
  );
}

/// Un punto que el usuario marcó a mano. No mueve el progreso automático.
@immutable
class ReadingBookmark {
  final String id;
  final ResolvedPosition where;
  final String? label;
  final DateTime createdAt;

  const ReadingBookmark({
    required this.id,
    required this.where,
    required this.createdAt,
    this.label,
  });

  ReadingPosition get position => where.position;

  factory ReadingBookmark.fromJson(Map<String, dynamic> json) => ReadingBookmark(
    id: json['id'] as String,
    where: ResolvedPosition.fromJson(json['position'] as Map<String, dynamic>),
    label: json['label'] as String?,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
  );
}

/// Un pasaje guardado, con su nota personal ya descifrada en memoria.
///
/// [note] existe solo del lado del dispositivo: se descifra al leer y se cifra
/// antes de enviar. Nunca viaja en claro, ni se serializa a disco.
@immutable
class SavedPassage {
  final String id;
  final ResolvedPosition where;

  /// La cita tal y como se leyó. Copiada, no referenciada: si mañana se
  /// corrige la traducción, lo guardado sigue diciendo lo que el usuario vio.
  final String quote;
  final bool quoteInSpanish;

  /// Nota personal en claro, ya descifrada. `null` si no hay nota.
  final String? note;

  /// True si había nota pero esta clave no puede descifrarla — por ejemplo
  /// tras reinstalar la app en otro dispositivo. Se distingue de "sin nota"
  /// para poder decírselo al usuario en vez de fingir que nunca escribió nada.
  final bool noteUnreadable;

  final DateTime createdAt;

  const SavedPassage({
    required this.id,
    required this.where,
    required this.quote,
    required this.quoteInSpanish,
    required this.createdAt,
    this.note,
    this.noteUnreadable = false,
  });

  ReadingPosition get position => where.position;
  bool get hasNote => note != null && note!.trim().isNotEmpty;

  SavedPassage copyWith({String? note, bool? noteUnreadable}) => SavedPassage(
    id: id,
    where: where,
    quote: quote,
    quoteInSpanish: quoteInSpanish,
    createdAt: createdAt,
    note: note,
    noteUnreadable: noteUnreadable ?? this.noteUnreadable,
  );
}
