/// Foto completa de la mesa: el equivalente de `serialize()` del prototipo.
///
/// Es INMUTABLE a proposito. En el prototipo la foto de deshacer compartia los
/// arrays de los montones con el estado vivo y se perdio una carta; aqui cada
/// cambio devuelve una mesa nueva y las listas no se pueden tocar, asi que una
/// foto guardada no cambia nunca.
///
/// Del mazo solo se guarda lo que el servidor deja ver (`ServerView`): el orden
/// vive en el backend. Lo demas es disposicion local: donde esta cada monton y
/// cada carta, la tirada, el sello y la camara.
library;

import 'dart:ui' show Offset;

import 'table_models.dart';

List<T> _frozen<T>(Iterable<T> items) => List.unmodifiable(items);

double _round(double v) => (v * 10).roundToDouble() / 10;

/// Camara de la mesa: inclinacion y giro en grados, zoom y desplazamiento en
/// unidades de mesa. Encuadre base a 30 grados, como el prototipo.
class TableCameraState {
  const TableCameraState({
    this.theta = 30,
    this.yaw = 0,
    this.zoom = 1,
    this.panX = 0,
    this.panY = 0,
  });

  final double theta;
  final double yaw;
  final double zoom;
  final double panX;
  final double panY;

  Map<String, dynamic> toJson() => {
    'theta': theta,
    'yaw': yaw,
    'zoom': zoom,
    'pan_x': panX,
    'pan_y': panY,
  };

  factory TableCameraState.fromJson(Map<String, dynamic> j) => TableCameraState(
    theta: (j['theta'] as num? ?? 30).toDouble(),
    yaw: (j['yaw'] as num? ?? 0).toDouble(),
    zoom: (j['zoom'] as num? ?? 1).toDouble(),
    panX: (j['pan_x'] as num? ?? 0).toDouble(),
    panY: (j['pan_y'] as num? ?? 0).toDouble(),
  );
}

/// Donde esta un monton sobre el paño (unidades de mesa, 600 x 900).
class PileLayout {
  const PileLayout({
    required this.pid,
    this.x = 300,
    this.y = 720,
    this.rot = 0,
  });

  final String pid;
  final double x;
  final double y;
  final double rot;

  PileLayout moved(double x, double y, [double? rot]) =>
      PileLayout(pid: pid, x: x, y: y, rot: rot ?? this.rot);

  Map<String, dynamic> toJson() => {
    'pid': pid,
    'x': _round(x),
    'y': _round(y),
    'rot': _round(rot),
  };

  factory PileLayout.fromJson(Map<String, dynamic> j) => PileLayout(
    pid: j['pid'] as String,
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    rot: (j['rot'] as num? ?? 0).toDouble(),
  );
}

/// Abanico abierto de un monton: una linea sobre la mesa, del monton
/// (`start`) hasta donde se solto el dedo (`end`), en unidades de mesa. Las
/// cartas que quedan en el monton se reparten a lo largo de ella.
class FanLayout {
  const FanLayout({required this.pid, required this.start, required this.end});

  final String pid;
  final Offset start;
  final Offset end;

  double get length => (end - start).distance;

  FanLayout to(Offset end) => FanLayout(pid: pid, start: start, end: end);

  Map<String, dynamic> toJson() => {
    'pid': pid,
    'start': [_round(start.dx), _round(start.dy)],
    'end': [_round(end.dx), _round(end.dy)],
  };

  factory FanLayout.fromJson(Map<String, dynamic> j) {
    Offset at(Object? v) {
      final l = (v as List).cast<num>();
      return Offset(l[0].toDouble(), l[1].toDouble());
    }

    return FanLayout(
      pid: j['pid'] as String,
      start: at(j['start']),
      end: at(j['end']),
    );
  }
}

/// Carta sacada y puesta en la mesa.
class TableCard {
  const TableCard({
    required this.face,
    this.x = 300,
    this.y = 480,
    this.rot = 0,
    this.scale = 1,
    this.slot,
    this.aside = false,
    this.faceUp = false,
    this.dir = -1,
    this.host,
    this.turned = false,
  });

  final CardFace face;
  final double x;
  final double y;
  final double rot;
  final double scale;

  /// Hueco de la tirada que ocupa, o null.
  final int? slot;

  /// Apartada a un lado de la tirada.
  final bool aside;
  final bool faceUp;

  /// Hacia donde giro al voltearse (-1 o 1), para que no gire al reves al restaurar.
  final int dir;

  /// Slug de la carta a la que aclara, o null.
  final String? host;

  /// El lector la giro 180 grados: su sentido es el contrario al que decidio
  /// el servidor. Viaja al interpretar para que la lectura lo respete.
  final bool turned;

  /// Sentido con el que se lee: el del servidor, invertido si se giro.
  bool get reversed => face.reversed != turned;

  String get slug => face.slug;

  TableCard copyWith({
    double? x,
    double? y,
    double? rot,
    double? scale,
    int? Function()? slot,
    bool? aside,
    bool? faceUp,
    int? dir,
    String? Function()? host,
    bool? turned,
  }) => TableCard(
    face: face,
    x: x ?? this.x,
    y: y ?? this.y,
    rot: rot ?? this.rot,
    scale: scale ?? this.scale,
    slot: slot != null ? slot() : this.slot,
    aside: aside ?? this.aside,
    faceUp: faceUp ?? this.faceUp,
    dir: dir ?? this.dir,
    host: host != null ? host() : this.host,
    turned: turned ?? this.turned,
  );

  Map<String, dynamic> toJson() => {
    'face': face.toJson(),
    'x': _round(x),
    'y': _round(y),
    'rot': _round(rot),
    'scale': scale,
    'slot': slot,
    'aside': aside,
    'face_up': faceUp,
    'dir': dir,
    'host': host,
    'turned': turned,
  };

  factory TableCard.fromJson(Map<String, dynamic> j) => TableCard(
    face: CardFace.fromJson(j['face'] as Map<String, dynamic>),
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    rot: (j['rot'] as num? ?? 0).toDouble(),
    scale: (j['scale'] as num? ?? 1).toDouble(),
    slot: j['slot'] as int?,
    aside: j['aside'] as bool? ?? false,
    faceUp: j['face_up'] as bool? ?? false,
    dir: j['dir'] as int? ?? -1,
    host: j['host'] as String?,
    turned: j['turned'] as bool? ?? false,
  );
}

/// Pregunta sellada: se escribe antes de tirar y se rompe al interpretar.
class Seal {
  const Seal({required this.text, this.open = false});

  final String text;
  final bool open;

  Map<String, dynamic> toJson() => {'text': text, 'open': open};

  factory Seal.fromJson(Map<String, dynamic> j) =>
      Seal(text: j['text'] as String? ?? '', open: j['open'] as bool? ?? false);
}

class TableState {
  TableState({
    this.server,
    this.activePid,
    Iterable<PileLayout> piles = const [],
    this.fan,
    Iterable<TableCard> cards = const [],
    this.spread,
    this.seal,
    this.camera = const TableCameraState(),
  }) : piles = _frozen(piles),
       cards = _frozen(cards);

  /// Version del formato guardado. Si cambia, lo guardado con otra se descarta.
  static const int version = 1;

  static final TableState empty = TableState();

  final ServerView? server;

  /// Monton principal: el que se llevo el mazo al abrirlo.
  final String? activePid;
  final List<PileLayout> piles;
  final FanLayout? fan;
  final List<TableCard> cards;
  final String? spread;
  final Seal? seal;
  final TableCameraState camera;

  bool get hasTable => server != null;
  String? get sessionId => server?.id;

  TableCard? card(String slug) {
    for (final c in cards) {
      if (c.slug == slug) return c;
    }
    return null;
  }

  TableCard? cardInSlot(int slot) {
    for (final c in cards) {
      if (c.slot == slot) return c;
    }
    return null;
  }

  List<TableCard> clarifiersOf(String slug) =>
      cards.where((c) => c.host == slug).toList();

  TableState copyWith({
    ServerView? Function()? server,
    String? Function()? activePid,
    Iterable<PileLayout>? piles,
    FanLayout? Function()? fan,
    Iterable<TableCard>? cards,
    String? Function()? spread,
    Seal? Function()? seal,
    TableCameraState? camera,
  }) => TableState(
    server: server != null ? server() : this.server,
    activePid: activePid != null ? activePid() : this.activePid,
    piles: piles ?? this.piles,
    fan: fan != null ? fan() : this.fan,
    cards: cards ?? this.cards,
    spread: spread != null ? spread() : this.spread,
    seal: seal != null ? seal() : this.seal,
    camera: camera ?? this.camera,
  );

  // ---------- servidor ----------

  /// Adopta la vista del servidor, que manda sobre lo local.
  ///
  /// Montones que el servidor ya no tiene desaparecen; los nuevos (un corte)
  /// aparecen junto al principal. Cartas que ya no estan fuera del mazo se
  /// quitan de la mesa, y las aclaratorias que colgaban de ellas se sueltan.
  /// Una carta sacada que la mesa no conocia no se inventa: la pone quien la saco.
  /// Las sacadas que el servidor tiene fuera y aqui no hay: pasa al volver sin
  /// la foto local (la app murio antes de guardar, otro movil). Se dejan sueltas
  /// boca abajo, en fila; sin ellas quedaban invisibles e inservibles.
  TableState withMissingDrawn(ServerView view) {
    final have = {for (final c in cards) c.slug};
    final missing = [
      for (final d in view.drawn)
        if (!have.contains(d.slug) && view.drawnFaces[d.slug] != null) d.slug,
    ];
    if (missing.isEmpty) return this;
    return copyWith(
      cards: [
        ...cards,
        for (var i = 0; i < missing.length; i++)
          TableCard(
            face: view.drawnFaces[missing[i]]!,
            x: 110 + (i % 5) * 95.0,
            y: 420 + (i ~/ 5) * 130.0,
            scale: .7,
          ),
      ],
    );
  }

  TableState withServer(ServerView view) {
    final byPid = {for (final p in piles) p.pid: p};
    final anchor = byPid[activePid] ?? const PileLayout(pid: '');
    var offset = 0;
    final nextPiles = [
      for (final pid in view.piles.keys)
        byPid[pid] ??
            PileLayout(
              pid: pid,
              x: (anchor.x + 110 * ++offset).clamp(60, 540).toDouble(),
              y: anchor.y,
            ),
    ];
    final out = view.drawnSlugs;
    final kept = cards.where((c) => out.contains(c.slug)).toList();
    final keptSlugs = {for (final c in kept) c.slug};
    return copyWith(
      server: () => view,
      activePid: () => view.piles.containsKey(activePid)
          ? activePid
          : (view.piles.isEmpty ? null : view.piles.keys.first),
      piles: nextPiles,
      fan: () => fan != null && view.piles.containsKey(fan!.pid) ? fan : null,
      cards: [
        for (final c in kept)
          c.host != null && !keptSlugs.contains(c.host)
              ? c.copyWith(host: () => null)
              : c,
      ],
    );
  }

  // ---------- cartas ----------
  TableState addCard(TableCard card) {
    if (this.card(card.slug) != null) return this;
    return copyWith(cards: [...cards, card]);
  }

  TableState updateCard(String slug, TableCard Function(TableCard) change) =>
      copyWith(cards: [for (final c in cards) c.slug == slug ? change(c) : c]);

  /// Pone una carta en un hueco. Si estaba ocupado, la que habia pasa al hueco
  /// que deja libre la que llega (intercambio), o queda suelta si no venia de uno.
  TableState putInSlot(String slug, int slot) {
    final moving = card(slug);
    if (moving == null) return this;
    final occupant = cardInSlot(slot);
    return copyWith(
      cards: [
        for (final c in cards)
          if (c.slug == slug)
            c.copyWith(slot: () => slot, aside: false, host: () => null)
          else if (occupant != null && c.slug == occupant.slug)
            c.copyWith(slot: () => moving.slot)
          else
            c,
      ],
    );
  }

  /// Convierte una carta en aclaratoria de otra que esta en un hueco.
  TableState clarify(String slug, String hostSlug) {
    final host = card(hostSlug);
    if (host == null || host.slot == null || slug == hostSlug) return this;
    return updateCard(
      slug,
      (c) => c.copyWith(host: () => hostSlug, slot: () => null, aside: false),
    );
  }

  // ---------- interpretar ----------

  /// Lo que pide `/interpret`: cada carta en su hueco y las aclaratorias con
  /// el hueco al que aclaran. El sentido no se manda: lo decidio el servidor.
  List<Map<String, dynamic>> placements() {
    final slotOf = {
      for (final c in cards)
        if (c.slot != null) c.slug: c.slot!,
    };
    return [
      for (final c in cards)
        if (c.slot != null)
          {'slug': c.slug, 'slot': c.slot, if (c.turned) 'turned': true},
      for (final c in cards)
        if (c.host != null && slotOf.containsKey(c.host))
          {
            'slug': c.slug,
            'clarifies': slotOf[c.host],
            if (c.turned) 'turned': true,
          },
    ];
  }

  /// Todos los huecos llenos y desvelados.
  bool readyToInterpret(SpreadDef def) =>
      spread == def.slug &&
      List.generate(
        def.cardCount,
        (i) => cardInSlot(i),
      ).every((c) => c != null && c.faceUp);

  // ---------- persistencia ----------
  Map<String, dynamic> toJson() => {
    'v': version,
    'server': server?.toJson(),
    'active_pid': activePid,
    'piles': [for (final p in piles) p.toJson()],
    'fan': fan?.toJson(),
    'cards': [for (final c in cards) c.toJson()],
    'spread': spread,
    'seal': seal?.toJson(),
    'camera': camera.toJson(),
  };

  /// null si la foto es de otra version o esta rota: mejor mesa vacia que una
  /// mesa a medias.
  static TableState? fromJson(Map<String, dynamic> j) {
    if (j['v'] != version) return null;
    try {
      final server = j['server'] as Map<String, dynamic>?;
      return TableState(
        server: server == null ? null : ServerView.fromJson(server),
        activePid: j['active_pid'] as String?,
        piles: (j['piles'] as List).cast<Map<String, dynamic>>().map(
          PileLayout.fromJson,
        ),
        fan: j['fan'] == null
            ? null
            : FanLayout.fromJson(j['fan'] as Map<String, dynamic>),
        cards: (j['cards'] as List).cast<Map<String, dynamic>>().map(
          TableCard.fromJson,
        ),
        spread: j['spread'] as String?,
        seal: j['seal'] == null
            ? null
            : Seal.fromJson(j['seal'] as Map<String, dynamic>),
        camera: TableCameraState.fromJson(
          j['camera'] as Map<String, dynamic>? ?? const {},
        ),
      );
    } on Object {
      return null;
    }
  }
}

/// Si una interpretacion sigue siendo la de esta mesa: las mismas cartas en los
/// mismos huecos (o aclarando a los mismos). Tras recoger y hacer otra tirada,
/// el bordado reabria la vieja como si fuera de las cartas nuevas (06-oct).
extension InterpretationOnTable on Interpretation {
  bool describes(TableState table) {
    String key(String slug, int? slot, int? clarifies) =>
        '$slug|$slot|$clarifies';
    final now = {
      for (final p in table.placements())
        key(p['slug'] as String, p['slot'] as int?, p['clarifies'] as int?),
    };
    final read = {for (final c in cards) key(c.face.slug, c.slot, c.clarifies)};
    return now.length == read.length && now.containsAll(read);
  }
}
