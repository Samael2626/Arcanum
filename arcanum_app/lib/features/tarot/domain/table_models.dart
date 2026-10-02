/// Tipos de la mesa de tarot tal y como los sirve el backend.
///
/// El orden del mazo NO esta aqui: el servidor solo cuenta cuantas cartas
/// quedan en cada monton y en que posiciones. Las cartas aparecen cuando se
/// sacan, con su sentido ya decidido por el servidor.
library;

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) parse) =>
    List.unmodifiable(
      (raw as List? ?? const []).cast<Map<String, dynamic>>().map(parse),
    );

class DeckInfo {
  const DeckInfo({
    required this.slug,
    required this.name,
    required this.description,
    required this.allowReversed,
    required this.art,
    required this.cardCount,
  });

  final String slug;
  final String name;
  final String description;
  final bool allowReversed;
  final String art;
  final int cardCount;

  factory DeckInfo.fromJson(Map<String, dynamic> j) => DeckInfo(
    slug: j['slug'] as String,
    name: j['name'] as String,
    description: j['description'] as String? ?? '',
    allowReversed: j['allow_reversed'] as bool? ?? true,
    art: j['art'] as String? ?? 'rws',
    cardCount: j['card_count'] as int? ?? 0,
  );
}

/// Hueco de una tirada: x, y en fraccion del area de tirada, giro en grados.
class SpreadSlotDef {
  const SpreadSlotDef({
    required this.x,
    required this.y,
    required this.rotation,
    required this.name,
    required this.meaning,
  });

  final double x;
  final double y;
  final int rotation;
  final String name;
  final String meaning;

  factory SpreadSlotDef.fromJson(Map<String, dynamic> j) => SpreadSlotDef(
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    rotation: j['rotation'] as int? ?? 0,
    name: j['name'] as String,
    meaning: j['meaning'] as String? ?? '',
  );
}

class SpreadDef {
  const SpreadDef({
    required this.slug,
    required this.name,
    required this.description,
    required this.cardScale,
    required this.labelByName,
    required this.slots,
  });

  final String slug;
  final String name;
  final String description;
  final double cardScale;

  /// true: el nombre del hueco se borda en el paño; false: solo su numero.
  final bool labelByName;
  final List<SpreadSlotDef> slots;

  int get cardCount => slots.length;

  factory SpreadDef.fromJson(Map<String, dynamic> j) => SpreadDef(
    slug: j['slug'] as String,
    name: j['name'] as String,
    description: j['description'] as String? ?? '',
    cardScale: (j['card_scale'] as num? ?? 1).toDouble(),
    labelByName: j['label_mode'] == 'name',
    slots: _list(j['slots'], SpreadSlotDef.fromJson),
  );
}

/// Cara de una carta ya sacada.
class CardFace {
  const CardFace({
    required this.slug,
    required this.reversed,
    this.name,
    this.nameEs,
    this.arcana,
    this.suit,
    this.number,
  });

  final String slug;
  final bool reversed;
  final String? name;
  final String? nameEs;
  final String? arcana;
  final String? suit;
  final int? number;

  factory CardFace.fromJson(Map<String, dynamic> j) => CardFace(
    slug: j['slug'] as String,
    reversed: j['reversed'] as bool? ?? false,
    name: j['name'] as String?,
    nameEs: j['name_es'] as String?,
    arcana: j['arcana'] as String?,
    suit: j['suit'] as String?,
    number: j['number'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'slug': slug,
    'reversed': reversed,
    'name': name,
    'name_es': nameEs,
    'arcana': arcana,
    'suit': suit,
    'number': number,
  };
}

class PileView {
  const PileView({required this.count, required this.positions});

  final int count;

  /// Posiciones que siguen ocupadas: el abanico pide cartas por posicion.
  final List<int> positions;

  factory PileView.fromJson(Map<String, dynamic> j) => PileView(
    count: j['count'] as int,
    positions: List.unmodifiable((j['positions'] as List).cast<int>()),
  );

  Map<String, dynamic> toJson() => {'count': count, 'positions': positions};
}

/// Estado publico de la mesa en el servidor.
class ServerView {
  const ServerView({
    required this.id,
    required this.status,
    required this.deck,
    required this.label,
    required this.total,
    required this.piles,
    required this.drawn,
    required this.expiresAt,
    this.interpretation,
  });

  final String id;

  /// open | interpreted | closed | abandoned
  final String status;
  final String deck;

  /// Lo que le paso al mazo por ultima vez ("barajado · cascada", "cortado"...).
  final String label;
  final int total;
  final Map<String, PileView> piles;

  /// slug -> invertida, en el orden en que salieron.
  final List<({String slug, bool reversed})> drawn;
  final DateTime expiresAt;
  final Interpretation? interpretation;

  bool get isActive => status == 'open' || status == 'interpreted';
  Set<String> get drawnSlugs => {for (final d in drawn) d.slug};

  factory ServerView.fromJson(Map<String, dynamic> j) {
    final interp = j['interpretation'] as Map<String, dynamic>?;
    return ServerView(
      id: j['id'] as String,
      status: j['status'] as String,
      deck: j['deck'] as String,
      label: j['state'] as String? ?? '',
      total: j['total'] as int,
      piles: Map.unmodifiable({
        for (final e in (j['piles'] as Map<String, dynamic>).entries)
          e.key: PileView.fromJson(e.value as Map<String, dynamic>),
      }),
      drawn: List.unmodifiable(
        (j['drawn'] as List).cast<Map<String, dynamic>>().map(
          (d) => (slug: d['slug'] as String, reversed: d['reversed'] as bool),
        ),
      ),
      expiresAt: DateTime.parse(j['expires_at'] as String),
      interpretation: interp == null ? null : Interpretation.fromJson(interp),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status,
    'deck': deck,
    'state': label,
    'total': total,
    'piles': {for (final e in piles.entries) e.key: e.value.toJson()},
    'drawn': [
      for (final d in drawn) {'slug': d.slug, 'reversed': d.reversed},
    ],
    'expires_at': expiresAt.toUtc().toIso8601String(),
    'interpretation': interpretation?.toJson(),
  };
}

class InterpretedCard {
  const InterpretedCard({
    required this.face,
    required this.position,
    required this.meaning,
    this.slot,
    this.clarifies,
    this.positionMeaning,
  });

  final CardFace face;
  final int? slot;
  final int? clarifies;
  final String position;
  final String? positionMeaning;
  final String meaning;

  bool get isClarifier => clarifies != null;

  factory InterpretedCard.fromJson(Map<String, dynamic> j) => InterpretedCard(
    face: CardFace.fromJson(j),
    slot: j['slot'] as int?,
    clarifies: j['clarifies'] as int?,
    position: j['position'] as String,
    positionMeaning: j['position_meaning'] as String?,
    meaning: j['meaning'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    ...face.toJson(),
    'slot': slot,
    'clarifies': clarifies,
    'position': position,
    'position_meaning': positionMeaning,
    'meaning': meaning,
  };
}

/// Lectura de Tradicion devuelta al interpretar.
class Interpretation {
  const Interpretation({
    required this.spread,
    required this.spreadName,
    required this.cards,
    this.question,
    this.moonPhase,
    this.moonIllumination,
    this.planetaryHour,
    this.readAt,
  });

  final String spread;
  final String spreadName;
  final String? question;
  final String? moonPhase;

  /// Fraccion iluminada de la Luna al interpretar (0..1).
  final double? moonIllumination;
  final String? planetaryHour;

  /// Instante del cielo anotado: el de interpretar, en UTC.
  final DateTime? readAt;
  final List<InterpretedCard> cards;

  /// «Luna creciente · 63 % iluminada · hora de Venus · 2 de octubre de 2026, 21:14».
  /// Solo lo que haya: sin lugar confirmado no hay hora planetaria.
  String? get skyLine {
    final at = readAt?.toLocal();
    final parts = [
      ?moonPhase,
      if (moonIllumination != null)
        '${(moonIllumination! * 100).round()} % iluminada',
      if (planetaryHour != null) 'hora de $planetaryHour',
      if (at != null)
        '${at.day} de ${_months[at.month - 1]} de ${at.year}, '
            '${_two(at.hour)}:${_two(at.minute)}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  factory Interpretation.fromJson(Map<String, dynamic> j) => Interpretation(
    spread: j['spread'] as String,
    spreadName: j['spread_name'] as String? ?? '',
    question: j['question'] as String?,
    moonPhase: j['moon_phase'] as String?,
    moonIllumination: (j['moon_illumination'] as num?)?.toDouble(),
    planetaryHour: j['planetary_hour'] as String?,
    readAt: DateTime.tryParse(j['read_at'] as String? ?? ''),
    cards: _list(j['cards'], InterpretedCard.fromJson),
  );

  Map<String, dynamic> toJson() => {
    'spread': spread,
    'spread_name': spreadName,
    'question': question,
    'moon_phase': moonPhase,
    'moon_illumination': moonIllumination,
    'planetary_hour': planetaryHour,
    'read_at': readAt?.toUtc().toIso8601String(),
    'cards': [for (final c in cards) c.toJson()],
  };
}
