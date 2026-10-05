/// «Lectura revelada» (D7): la interpretacion de la mesa, una carta por
/// pantalla. Cada carta entra volteandose con su lamina, sobre la atmosfera de
/// su elemento y su propia lamina desenfocada; arriba asoma la tirada con la
/// carta actual encendida. Al final, la sintesis y «Cerrar el circulo».
library;

import 'package:flutter/material.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../shared/revelado/atmosphere.dart';
import '../../../shared/revelado/element_motion.dart';
import '../../../shared/revelado/reveal_pager.dart';
import '../../oraculo/widgets/tarot_card.dart';
import '../domain/table_models.dart';

/// Cara dibujable de una carta de la mesa.
TarotFace tarotFaceOf(CardFace f) => TarotFace.resolve({
  'slug': f.slug,
  'name': f.commonName,
  'arcana': f.arcana,
  'suit': f.suit,
  'number': f.number,
});

class LecturaRevelada extends StatefulWidget {
  const LecturaRevelada({
    super.key,
    required this.reading,
    required this.spread,
    required this.onCloseCircle,
    required this.onBack,
    this.entrance = const [],
  });

  /// Donde estaba cada carta en la mesa, en pantalla (mismo orden que
  /// `reading.cards`; null si no se sabe). Al abrir, las cartas vuelan de
  /// ahi a su hueco de la tirada de arriba mientras la lectura aparece.
  final List<Rect?> entrance;

  final Interpretation reading;

  /// Tirada de la lectura, para dibujarla arriba. Lectura libre: null.
  final SpreadDef? spread;
  final VoidCallback onCloseCircle;

  /// Volver a la mesa sin cerrar el circulo.
  final VoidCallback onBack;

  static const double headerHeight = 132;

  /// Cuanto tarda una carta en volar y cuanto espera cada una a la anterior.
  static const Duration flight = Duration(milliseconds: 650);
  static const Duration stagger = Duration(milliseconds: 60);

  @override
  State<LecturaRevelada> createState() => _LecturaReveladaState();
}

class _LecturaReveladaState extends State<LecturaRevelada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  bool _started = false;

  Interpretation get reading => widget.reading;
  SpreadDef? get spread => widget.spread;

  bool get _flies => widget.entrance.any((r) => r != null);

  @override
  void initState() {
    super.initState();
    final n = widget.entrance.length;
    _intro = AnimationController(
      vsync: this,
      duration:
          LecturaRevelada.flight +
          LecturaRevelada.stagger * (n > 0 ? n - 1 : 0),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!_flies || MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // la lectura aparece mientras las cartas vuelan: la mesa se ve debajo
        FadeTransition(
          opacity: CurvedAnimation(
            parent: _intro,
            curve: const Interval(0, .5, curve: Curves.easeOut),
          ),
          child: _reading(context),
        ),
        AnimatedBuilder(
          animation: _intro,
          builder: (context, _) => _intro.isAnimating
              ? IgnorePointer(
                  child: _Flight(
                    t: _intro.value,
                    total: _intro.duration!,
                    entrance: widget.entrance,
                    cards: reading.cards,
                    spread: spread,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _reading(BuildContext context) {
    final onBack = widget.onBack;
    final onCloseCircle = widget.onCloseCircle;
    const headerHeight = LecturaRevelada.headerHeight;
    final cards = reading.cards;
    final faces = [for (final c in cards) tarotFaceOf(c.face)];
    final last = cards.length; // la sintesis va despues de las cartas
    return Material(
      color: ArcanumColors.background,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: 'Interpretación: ${reading.spreadName}',
        child: RevealPager(
          count: cards.length + 1,
          headerHeight: headerHeight,
          header: (context, current, go) => _SpreadStrip(
            spread: spread,
            title: reading.spreadName,
            cards: cards,
            current: current,
            go: go,
            onBack: onBack,
          ),
          background: (context, i) {
            if (i == last) {
              return const Atmosphere(
                edge: ArcanumColors.background,
                core: ArcanumColors.surfaceHigh,
                glow: ArcanumColors.goldMuted,
              );
            }
            final a = tarotAtmosphere(faces[i]);
            return Atmosphere(
              edge: a.edge,
              core: a.core,
              glow: a.glow,
              art: faces[i].rwsAsset,
              reversed: cards[i].face.reversed,
              motion: MotionKind.fromName(a.motion),
              accent: a.accent,
            );
          },
          page: (context, i, active) => i == last
              ? _Synthesis(
                  reading: reading,
                  faces: faces,
                  active: active,
                  onCloseCircle: onCloseCircle,
                )
              : _CardPage(
                  card: cards[i],
                  face: faces[i],
                  number: i + 1,
                  active: active,
                  first: i == 0,
                ),
        ),
      ),
    );
  }
}

/// Las cartas volando de la mesa a su hueco de la tirada de arriba.
class _Flight extends StatelessWidget {
  const _Flight({
    required this.t,
    required this.total,
    required this.entrance,
    required this.cards,
    required this.spread,
  });

  final double t;
  final Duration total;
  final List<Rect?> entrance;
  final List<InterpretedCard> cards;
  final SpreadDef? spread;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final top = MediaQuery.paddingOf(context).top;
      final ms = total.inMilliseconds;
      return Stack(
        children: [
          for (var i = 0; i < cards.length && i < entrance.length; i++)
            if (entrance[i] case final from?)
              _card(
                i,
                from,
                _SpreadStrip.target(spread, cards[i], box.maxWidth, top),
                ((t * ms - i * LecturaRevelada.stagger.inMilliseconds) /
                        LecturaRevelada.flight.inMilliseconds)
                    .clamp(0.0, 1.0),
              ),
        ],
      );
    },
  );

  Widget _card(int i, Rect from, ({Offset at, double rotation}) to, double k) {
    final e = Curves.easeInOutCubic.transform(k);
    final size = Size.lerp(from.size, _MiniSlot.size, e)!;
    final at = Offset.lerp(from.center, to.at, e)!;
    final rev = cards[i].face.reversed ? 3.14159265 : 0.0;
    return Positioned(
      left: at.dx - size.width / 2,
      top: at.dy - size.height / 2,
      width: size.width,
      height: size.height,
      // al llegar se funde con su hueco
      child: Opacity(
        opacity: k < .85 ? 1 : (1 - k) / .15,
        child: Transform.rotate(
          angle: rev + to.rotation * 3.14159265 / 180 * e,
          child: TarotCardFaceArt(face: tarotFaceOf(cards[i].face), size: size),
        ),
      ),
    );
  }
}

/// Una carta: numero, posicion, lamina volteandose, nombre, sentido, lo que
/// significa la posicion y lo que dice la carta en ella.
class _CardPage extends StatelessWidget {
  const _CardPage({
    required this.card,
    required this.face,
    required this.number,
    required this.active,
    required this.first,
  });

  final InterpretedCard card;
  final TarotFace face;
  final int number;
  final bool active;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final accent = tarotAtmosphere(face).accent;
    final rev = card.face.reversed;
    final name = card.face.commonName;
    final gd = card.face.goldenDawnTitle;
    return Semantics(
      container: true,
      label:
          '$number. ${card.position}. $name, ${rev ? 'invertida' : 'al derecho'}.',
      child: Stack(
        children: [
          Positioned(
            right: 16,
            top: 0,
            child: ExcludeSemantics(
              child: Text(
                '$number',
                style: TextStyle(
                  fontSize: 96,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: accent.withValues(alpha: .16),
                ),
              ),
            ),
          ),
          // no es la vista principal: si el texto cabe, el gesto vertical
          // pasa a la carta siguiente; solo se desplaza si no cabe
          SingleChildScrollView(
            primary: false,
            // sin rebote: al llegar al borde avisa, y el pager pasa de carta
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RevealIn(
                  active: active,
                  child: Text(
                    '$number · ${card.position}'.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 2.2,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    RevealFlip(
                      active: active,
                      reversed: rev,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            const BoxShadow(
                              color: Colors.black87,
                              blurRadius: 24,
                              offset: Offset(0, 10),
                            ),
                            BoxShadow(
                              color: accent.withValues(alpha: .45),
                              blurRadius: 26,
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                        child: ExcludeSemantics(
                          child: TarotCardFaceArt(
                            face: face,
                            size: const Size(104, 166),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: RevealIn(
                        active: active,
                        step: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 28,
                                height: 1.05,
                                fontWeight: FontWeight.w600,
                                color: ArcanumColors.ivory,
                              ),
                            ),
                            if (gd != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                gd,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: ArcanumColors.goldMuted,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              [
                                rev ? 'Invertida' : 'Al derecho',
                                if (card.isClarifier) 'aclaratoria',
                              ].join(' · '),
                              style: const TextStyle(
                                fontSize: 13,
                                color: ArcanumColors.ivoryMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (card.positionMeaning case final pm?)
                  RevealIn(
                    active: active,
                    step: 3,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        pm,
                        style: TextStyle(
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                RevealIn(
                  active: active,
                  step: 4,
                  child: Text(
                    card.meaning,
                    style: const TextStyle(
                      fontSize: 16.5,
                      height: 1.45,
                      color: ArcanumColors.ivory,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                    ),
                  ),
                ),
                if (first) ...[
                  const SizedBox(height: 28),
                  Text(
                    'Desliza hacia arriba',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: ArcanumColors.ivoryMuted.withValues(alpha: .8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// El final: la pregunta, las cartas juntas, el cielo y «Cerrar el circulo».
class _Synthesis extends StatelessWidget {
  const _Synthesis({
    required this.reading,
    required this.faces,
    required this.active,
    required this.onCloseCircle,
  });

  final Interpretation reading;
  final List<TarotFace> faces;
  final bool active;
  final VoidCallback onCloseCircle;

  @override
  Widget build(BuildContext context) {
    final cards = reading.cards;
    return Center(
      child: SingleChildScrollView(
        primary: false,
        // sin rebote: al llegar al borde avisa, y el pager pasa de carta
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'EL CÍRCULO',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 2.4,
                color: ArcanumColors.gold,
              ),
            ),
            if (reading.question case final q?) ...[
              const SizedBox(height: 14),
              RevealIn(
                active: active,
                child: Text(
                  '«$q»',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontStyle: FontStyle.italic,
                    color: ArcanumColors.goldLight,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            RevealIn(
              active: active,
              step: 1,
              child: ExcludeSemantics(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < cards.length; i++)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: tarotAtmosphere(
                                faces[i],
                              ).glow.withValues(alpha: .5),
                              blurRadius: 14,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                        child: Transform.rotate(
                          angle: cards[i].face.reversed ? 3.14159265 : 0,
                          child: TarotCardFaceArt(
                            face: faces[i],
                            size: const Size(34, 54),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (reading.skyLine case final sky?) ...[
              const SizedBox(height: 16),
              RevealIn(
                active: active,
                step: 2,
                child: Text(
                  sky,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontStyle: FontStyle.italic,
                    color: ArcanumColors.ivoryMuted,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 26),
            HoldToConfirm(
              label: 'Mantén para cerrar el círculo',
              onConfirm: onCloseCircle,
            ),
          ],
        ),
      ),
    );
  }
}

/// La tirada en pequeño, arriba: cada carta en su hueco y la actual encendida.
/// Tocar una salta a ella. Sin tirada (lectura libre), una fila de puntos.
class _SpreadStrip extends StatelessWidget {
  const _SpreadStrip({
    required this.spread,
    required this.title,
    required this.cards,
    required this.current,
    required this.go,
    required this.onBack,
  });

  final SpreadDef? spread;
  final String title;
  final List<InterpretedCard> cards;
  final int current;
  final ValueChanged<int> go;
  final VoidCallback onBack;

  /// Donde queda la tirada en pequeño dentro de la franja.
  static const double sideInset = 24, topInset = 44, bottomInset = 8;

  /// Saltar al hueco `s`. Dos huecos con el mismo centro (el cruce 1/2 de la
  /// Cruz Celta) comparten zona y el toque iria siempre al de encima: tocar
  /// alterna entre ellos, empezando por el primero.
  /// Radio alrededor de cada hueco del minimapa que cuenta como tocarlo.
  static const double reach = 40;

  void _tapNear(Offset p, Size box) {
    final slots = spread!.slots;
    int? best;
    var bestD = reach;
    for (var s = 0; s < slots.length; s++) {
      if (!cards.any((c) => c.slot == s)) continue;
      final d = (Offset(slots[s].x * box.width, slots[s].y * box.height) - p)
          .distance;
      if (d <= bestD) {
        bestD = d;
        best = s;
      }
    }
    if (best != null) _goToSlot(best);
  }

  void _goToSlot(int s) {
    final slots = spread!.slots;
    final twins = [
      for (var t = 0; t < slots.length; t++)
        if (slots[t].x == slots[s].x && slots[t].y == slots[s].y) t,
    ];
    final now = current < cards.length ? cards[current].slot : null;
    final at = twins.indexOf(now ?? -1);
    final target = at < 0 ? twins.first : twins[(at + 1) % twins.length];
    final i = cards.indexWhere((c) => c.slot == target);
    if (i >= 0) go(i);
  }

  /// Centro y giro del hueco de una carta en la franja, en coordenadas de la
  /// lectura. Una aclaratoria va al hueco que aclara; sin tirada, al centro.
  static ({Offset at, double rotation}) target(
    SpreadDef? spread,
    InterpretedCard card,
    double width,
    double safeTop,
  ) {
    final h = LecturaRevelada.headerHeight - safeTop - topInset - bottomInset;
    final s = card.slot ?? card.clarifies;
    if (spread == null || s == null || s >= spread.slots.length) {
      return (at: Offset(width / 2, safeTop + topInset + h / 2), rotation: 0);
    }
    final slot = spread.slots[s];
    return (
      at: Offset(
        sideInset + slot.x * (width - 2 * sideInset),
        safeTop + topInset + slot.y * h,
      ),
      rotation: slot.rotation.toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = current < cards.length
        ? '${current + 1} / ${cards.length}'
        : 'Síntesis';
    // la carta que se lee: la suya o, si aclara, la de su hueco
    final lit = current < cards.length
        ? (cards[current].slot ?? cards[current].clarifies)
        : null;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1),
          radius: 1.3,
          colors: [Color(0xFF3A1020), Color(0xFF1F0610)],
        ),
        border: Border(bottom: BorderSide(color: Color(0x52C9A84C))),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 16)],
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              left: 4,
              top: 0,
              child: IconButton(
                tooltip: 'Volver a la mesa',
                icon: const Icon(
                  Icons.arrow_back,
                  color: ArcanumColors.goldLight,
                ),
                onPressed: onBack,
              ),
            ),
            Positioned(
              left: 52,
              right: 16,
              top: 14,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        letterSpacing: 2,
                        color: ArcanumColors.gold,
                      ),
                    ),
                  ),
                  Text(
                    count,
                    style: const TextStyle(
                      fontSize: 11.5,
                      letterSpacing: 1.5,
                      color: ArcanumColors.gold,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: sideInset,
              right: sideInset,
              top: topInset,
              bottom: bottomInset,
              child: spread == null || spread!.slots.isEmpty
                  ? _Dots(count: cards.length, current: current, go: go)
                  : LayoutBuilder(
                      builder: (context, box) => Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (var s = 0; s < spread!.slots.length; s++)
                            _MiniSlot(
                              x: spread!.slots[s].x * box.maxWidth,
                              y: spread!.slots[s].y * box.maxHeight,
                              rotation: spread!.slots[s].rotation.toDouble(),
                              filled: cards.any((c) => c.slot == s),
                              lit: lit == s,
                              label: '${s + 1}, ${spread!.slots[s].name}',
                              // el lector nombra cada hueco: va directo a el
                              onSemanticsTap: () {
                                final i = cards.indexWhere((c) => c.slot == s);
                                if (i >= 0) go(i);
                              },
                            ),
                          // el dedo va al hueco mas cercano: cada uno gana su
                          // zona sin pisar al vecino (en la columna de la Cruz
                          // Celta no caben cajas de 48 dp)
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              excludeFromSemantics: true,
                              onTapUp: (d) =>
                                  _tapNear(d.localPosition, box.biggest),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniSlot extends StatelessWidget {
  const _MiniSlot({
    required this.x,
    required this.y,
    required this.rotation,
    required this.filled,
    required this.lit,
    required this.label,
    required this.onSemanticsTap,
  });

  final double x;
  final double y;
  final double rotation;
  final bool filled;
  final bool lit;
  final String label;
  final VoidCallback onSemanticsTap;

  static const Size size = Size(14, 22);

  @override
  Widget build(BuildContext context) => Positioned(
    left: x - 16,
    top: y - 16,
    width: 32,
    height: 32,
    child: Semantics(
      button: filled,
      selected: lit,
      label: 'Ir a $label',
      onTap: filled ? onSemanticsTap : null,
      child: SizedBox.expand(
        child: Center(
          child: Transform.rotate(
            angle: rotation * 3.14159265 / 180,
            child: AnimatedScale(
              scale: lit ? 1.18 : 1,
              duration: const Duration(milliseconds: 300),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: size.width,
                height: size.height,
                decoration: BoxDecoration(
                  color: filled ? const Color(0xFF2A1A40) : Colors.transparent,
                  borderRadius: BorderRadius.circular(2.5),
                  border: Border.all(
                    color: lit
                        ? ArcanumColors.goldLight
                        : ArcanumColors.goldMuted.withValues(
                            alpha: filled ? 1 : .5,
                          ),
                    width: lit ? 1.6 : 1,
                  ),
                  boxShadow: lit
                      ? const [
                          BoxShadow(color: Color(0x99C9A84C), blurRadius: 12),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current, required this.go});
  final int count;
  final int current;
  final ValueChanged<int> go;

  @override
  Widget build(BuildContext context) => Center(
    child: Wrap(
      spacing: 4,
      children: [
        for (var i = 0; i < count; i++)
          Semantics(
            button: true,
            selected: i == current,
            label: 'Ir a la carta ${i + 1}',
            child: GestureDetector(
              onTap: () => go(i),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: i == current ? 10 : 7,
                  height: i == current ? 10 : 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == current
                        ? ArcanumColors.goldLight
                        : ArcanumColors.goldMuted,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
