/// Modelos de Lecturas: obras en dominio público leídas como texto.
///
/// Se leen del backend y se cachean en disco para funcionar sin conexión. El
/// texto original viaja siempre junto a la traducción: sin él no se puede
/// alternar ES/EN, verificar una traducción automática, ni mandar el pasaje
/// citable al oráculo.
library;

/// Cómo llegó la traducción de un párrafo. Se muestra al usuario: una
/// traducción automática debe declararse.
enum TranslationStatus {
  /// La tradujo el modelo y nadie la ha revisado.
  machine,

  /// Revisada por una persona.
  human;

  static TranslationStatus? parse(String? value) => switch (value) {
    'machine' => TranslationStatus.machine,
    'human' => TranslationStatus.human,
    _ => null,
  };

  String get label => switch (this) {
    TranslationStatus.machine => 'Traducción automática',
    TranslationStatus.human => 'Traducción revisada',
  };
}

/// Qué es un capítulo dentro de la obra. Culpeper no es homogéneo: mezcla
/// epístolas, entradas de planta, catálogos y un tratado de recetas.
enum ChapterKind {
  herb,
  appendix,
  catalogue,
  front,
  text;

  static ChapterKind parse(String? value) => switch (value) {
    'herb' => ChapterKind.herb,
    'appendix' => ChapterKind.appendix,
    'catalogue' => ChapterKind.catalogue,
    'front' => ChapterKind.front,
    _ => ChapterKind.text,
  };

  String get label => switch (this) {
    ChapterKind.herb => 'Hierbas',
    ChapterKind.appendix => 'Recetas y preparados',
    ChapterKind.catalogue => 'Catálogo de materia',
    ChapterKind.front => 'Preliminares',
    ChapterKind.text => 'Texto',
  };
}

/// Un párrafo: la unidad direccionable de toda la sección.
///
/// A su [anchor] apuntan los resaltados guardados y, más adelante, las
/// lecciones. Es estable entre reingestas: un resaltado de hace meses debe
/// seguir resolviendo al mismo texto.
class LibraryParagraph {
  final String anchor;
  final int position;
  final String textOriginal;
  final String? textEs;
  final TranslationStatus? translationStatus;

  const LibraryParagraph({
    required this.anchor,
    required this.position,
    required this.textOriginal,
    this.textEs,
    this.translationStatus,
  });

  /// El texto a mostrar. Cae al original si no hay traducción todavía: es
  /// preferible leer en inglés a ver un hueco sin explicación.
  String textFor({required bool spanish}) =>
      spanish ? (textEs ?? textOriginal) : textOriginal;

  bool get hasTranslation => textEs != null && textEs!.isNotEmpty;

  factory LibraryParagraph.fromJson(Map<String, dynamic> json) =>
      LibraryParagraph(
        anchor: json['anchor'] as String,
        position: json['position'] as int,
        textOriginal: json['text_original'] as String,
        textEs: json['text_es'] as String?,
        translationStatus: TranslationStatus.parse(
          json['translation_status'] as String?,
        ),
      );

  Map<String, dynamic> toJson() => {
    'anchor': anchor,
    'position': position,
    'text_original': textOriginal,
    'text_es': textEs,
    'translation_status': translationStatus?.name,
  };
}

/// Un capítulo con su texto. Es la unidad que se descarga y se cachea.
class LibraryChapter {
  final String slug;
  final String title;
  final ChapterKind kind;
  final int position;
  final Map<String, dynamic> meta;
  final String workSlug;
  final String workTitle;

  /// Aviso histórico. Viaja con el capítulo, no solo con la obra: si se entra
  /// directo a una entrada que afirma curar la peste, el encuadre debe estar.
  final String? advisory;

  final List<LibraryParagraph> paragraphs;

  const LibraryChapter({
    required this.slug,
    required this.title,
    required this.kind,
    required this.position,
    required this.meta,
    required this.workSlug,
    required this.workTitle,
    required this.paragraphs,
    this.advisory,
  });

  /// Planeta regente, cuando la obra lo declara. Extraído del texto ORIGINAL
  /// en la ingesta, nunca de la traducción: es el puente con Materia Arcana y
  /// no puede depender de la calidad del traductor.
  String? get rulingPlanet => meta['ruling_planet'] as String?;

  /// Slug de la planta de Materia Arcana enlazada, si esta entrada es una
  /// hierba mapeada. Es el puente inverso: desde el capítulo de Culpeper de
  /// vuelta a la ficha de la planta.
  String? get materiaSlug => meta['materia_slug'] as String?;

  bool get hasTranslation => paragraphs.any((p) => p.hasTranslation);

  factory LibraryChapter.fromJson(Map<String, dynamic> json) => LibraryChapter(
    slug: json['slug'] as String,
    title: json['title'] as String,
    kind: ChapterKind.parse(json['kind'] as String?),
    position: json['position'] as int,
    meta: Map<String, dynamic>.from(json['meta'] as Map? ?? const {}),
    workSlug: json['work_slug'] as String,
    workTitle: json['work_title'] as String,
    advisory: json['advisory'] as String?,
    paragraphs: (json['paragraphs'] as List? ?? const [])
        .map((p) => LibraryParagraph.fromJson(p as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'slug': slug,
    'title': title,
    'kind': kind.name,
    'position': position,
    'meta': meta,
    'work_slug': workSlug,
    'work_title': workTitle,
    'advisory': advisory,
    'paragraphs': paragraphs.map((p) => p.toJson()).toList(),
  };
}

/// Entrada del índice de una obra: sin texto, para que la lista cargue rápido.
class LibraryChapterSummary {
  final String slug;
  final String title;
  final ChapterKind kind;
  final int position;
  final Map<String, dynamic> meta;
  final int paragraphCount;

  const LibraryChapterSummary({
    required this.slug,
    required this.title,
    required this.kind,
    required this.position,
    required this.meta,
    required this.paragraphCount,
  });

  String? get rulingPlanet => meta['ruling_planet'] as String?;

  factory LibraryChapterSummary.fromJson(Map<String, dynamic> json) =>
      LibraryChapterSummary(
        slug: json['slug'] as String,
        title: json['title'] as String,
        kind: ChapterKind.parse(json['kind'] as String?),
        position: json['position'] as int,
        meta: Map<String, dynamic>.from(json['meta'] as Map? ?? const {}),
        paragraphCount: json['paragraph_count'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'slug': slug,
    'title': title,
    'kind': kind.name,
    'position': position,
    'meta': meta,
    'paragraph_count': paragraphCount,
  };
}

/// Una obra con su índice de capítulos, todavía sin texto.
class LibraryWork {
  final String slug;
  final String title;
  final String author;
  final int? year;
  final String language;
  final String? sourceUrl;

  /// Por qué esta obra puede distribuirse. Se muestra en la ficha: la
  /// procedencia forma parte del contenido, no es letra pequeña.
  final String licenseNote;
  final String? advisory;
  final List<LibraryChapterSummary> chapters;

  const LibraryWork({
    required this.slug,
    required this.title,
    required this.author,
    required this.language,
    required this.licenseNote,
    required this.chapters,
    this.year,
    this.sourceUrl,
    this.advisory,
  });

  Iterable<LibraryChapterSummary> byKind(ChapterKind kind) =>
      chapters.where((c) => c.kind == kind);

  factory LibraryWork.fromJson(Map<String, dynamic> json) => LibraryWork(
    slug: json['slug'] as String,
    title: json['title'] as String,
    author: json['author'] as String,
    year: json['year'] as int?,
    language: json['language'] as String? ?? 'en',
    sourceUrl: json['source_url'] as String?,
    licenseNote: json['license_note'] as String,
    advisory: json['advisory'] as String?,
    chapters: (json['chapters'] as List? ?? const [])
        .map((c) => LibraryChapterSummary.fromJson(c as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'slug': slug,
    'title': title,
    'author': author,
    'year': year,
    'language': language,
    'source_url': sourceUrl,
    'license_note': licenseNote,
    'advisory': advisory,
    'chapters': chapters.map((c) => c.toJson()).toList(),
  };
}

/// El puente Materia → Culpeper: qué capítulo de las Lecturas trata una planta
/// de Materia Arcana, para ofrecer "lo que dijo Culpeper" dentro de su ficha.
///
/// Lo devuelve `GET /library/by-materia/{slug}`. La ficha muestra una tarjeta
/// con la comparación de regencias y un anticipo del pasaje; el capítulo entero
/// queda a un toque en `/saber/{workSlug}/{chapterSlug}`.
class CulpeperBridge {
  final String workSlug;
  final String workTitle;
  final String author;
  final int? year;
  final String chapterSlug;
  final String chapterTitle;

  /// Regentes según Culpeper. Lista: puede haber regencia compartida/disputada.
  final List<String> rulingPlanets;

  /// True si Culpeper NO coincide con la regencia de Materia Arcana. Se muestra
  /// en neutral, ambas con su referencia — no se "corrige" a ninguna.
  final bool discrepant;

  /// Anticipo: el pasaje donde el autor declara la regencia. Puede faltar.
  final String? excerpt;

  /// True si el extracto salió de la traducción ES; false si del original EN.
  final bool excerptIsTranslation;

  const CulpeperBridge({
    required this.workSlug,
    required this.workTitle,
    required this.author,
    required this.chapterSlug,
    required this.chapterTitle,
    required this.rulingPlanets,
    required this.discrepant,
    required this.excerptIsTranslation,
    this.year,
    this.excerpt,
  });

  factory CulpeperBridge.fromJson(Map<String, dynamic> json) => CulpeperBridge(
    workSlug: json['work_slug'] as String,
    workTitle: json['work_title'] as String,
    author: json['author'] as String,
    year: json['year'] as int?,
    chapterSlug: json['chapter_slug'] as String,
    chapterTitle: json['chapter_title'] as String,
    rulingPlanets: (json['ruling_planets'] as List? ?? const [])
        .map((e) => e as String)
        .toList(),
    discrepant: json['discrepant'] as bool? ?? false,
    excerpt: json['excerpt'] as String?,
    excerptIsTranslation: json['excerpt_is_translation'] as bool? ?? false,
  );
}

/// Ficha de obra para el índice general.
class LibraryWorkSummary {
  final String slug;
  final String title;
  final String author;
  final int? year;
  final String language;
  final int chapterCount;
  final int translatedChapters;

  const LibraryWorkSummary({
    required this.slug,
    required this.title,
    required this.author,
    required this.language,
    required this.chapterCount,
    required this.translatedChapters,
    this.year,
  });

  /// Una obra a medio traducir se puede leer igual; el cliente lo avisa en vez
  /// de mostrar huecos sin explicación.
  bool get fullyTranslated =>
      chapterCount > 0 && translatedChapters >= chapterCount;

  double get translationProgress =>
      chapterCount == 0 ? 0 : translatedChapters / chapterCount;

  factory LibraryWorkSummary.fromJson(Map<String, dynamic> json) =>
      LibraryWorkSummary(
        slug: json['slug'] as String,
        title: json['title'] as String,
        author: json['author'] as String,
        year: json['year'] as int?,
        language: json['language'] as String? ?? 'en',
        chapterCount: json['chapter_count'] as int? ?? 0,
        translatedChapters: json['translated_chapters'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'slug': slug,
    'title': title,
    'author': author,
    'year': year,
    'language': language,
    'chapter_count': chapterCount,
    'translated_chapters': translatedChapters,
  };
}
