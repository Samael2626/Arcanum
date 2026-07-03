import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../../shared/astro_symbols.dart';
import '../../../shared/widgets/arcanum_mood.dart';
import '../../../shared/widgets/arcanum_surface.dart';
import '../sign_lore.dart';

// ── Correspondencias visuales por elemento (zodíaco de la rueda) ──────────────

const List<String> _signElement = [
  'fire', 'earth', 'air', 'water', // aries taurus gemini cancer
  'fire', 'earth', 'air', 'water', // leo virgo libra scorpio
  'fire', 'earth', 'air', 'water', // sag capri aqua pisces
];

const Map<String, Color> _elementAccent = {
  'fire': ArcanumColors.elementFire,
  'earth': ArcanumColors.elementEarth,
  'air': ArcanumColors.elementAir,
  'water': ArcanumColors.elementWater,
};

const Map<String, Color> _elementGlow = {
  'fire': ArcanumColors.fireGlow,
  'earth': ArcanumColors.earthGlow,
  'air': ArcanumColors.airGlow,
  'water': ArcanumColors.waterGlow,
};

const Map<String, Color> _aspectColor = {
  'conjunction': ArcanumColors.aspectUnion,
  'sextile': ArcanumColors.aspectHarmony,
  'trine': ArcanumColors.aspectHarmony,
  'square': ArcanumColors.aspectTension,
  'opposition': ArcanumColors.aspectTension,
};

/// Significado breve de cada casa astrológica (detalle al tocar).
const List<String> _houseMeaning = [
  'El yo, el cuerpo, la máscara con que llegas al mundo.',
  'Recursos, posesiones, valores propios y sustento.',
  'Mente cercana, palabra, hermanos, viajes cortos.',
  'Hogar, raíces, ancestros, el fundamento íntimo.',
  'Creación, placer, romance, hijos, lo que irradias.',
  'Trabajo, salud, servicio, la práctica cotidiana.',
  'Pareja, pactos, el otro que te refleja.',
  'Muerte y renacimiento, lo oculto, lo compartido.',
  'Sabiduría, viajes lejanos, filosofía, lo sagrado.',
  'Vocación, cima pública, obra que perdura.',
  'Alianzas, colectivo, sueños del porvenir.',
  'Disolución, misterio, lo invisible, la entrega.',
];

class _PlanetSlot {
  final String name;
  final double trueLon;
  final double displayDeg;
  final Map<String, dynamic> raw;
  _PlanetSlot(this.name, this.trueLon, this.displayDeg, this.raw);
}

/// Rueda natal vectorial, animada e interactiva.
///
/// Se dibuja al entrar (anillos → casas → aspectos → planetas en cascada),
/// respira con una deriva lenta, y responde al tacto: arrastra en horizontal
/// para girarla, toca un planeta / signo / casa para abrir su detalle. El
/// último elemento tocado queda resaltado.
class NatalWheel extends StatefulWidget {
  final Map<String, dynamic> chart;
  const NatalWheel({super.key, required this.chart});

  @override
  State<NatalWheel> createState() => _NatalWheelState();
}

class _NatalWheelState extends State<NatalWheel> with TickerProviderStateMixin {
  late final AnimationController _reveal;
  late final AnimationController _idle; // deriva/respiración continua
  late final AnimationController _pulse; // realce del seleccionado

  double _dragRot = 0; // giro acumulado por el usuario (grados)

  String? _selPlanet;
  int? _selHouse;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..forward();
    _idle = AnimationController(vsync: this, duration: const Duration(seconds: 26))
      ..repeat();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
  }

  @override
  void dispose() {
    _reveal.dispose();
    _idle.dispose();
    _pulse.dispose();
    super.dispose();
  }

  double get _ascLon =>
      (widget.chart['ascendant']?['longitude'] as num?)?.toDouble() ?? 0;

  // Deriva sutil (±1.4°) + giro del usuario.
  double get _rot =>
      _dragRot + 1.4 * math.sin(_idle.value * 2 * math.pi);

  double _screenDeg(double lon) => (180 + (lon - _ascLon) + _rot) % 360;

  List<_PlanetSlot> _slots() {
    final planets =
        (widget.chart['planets'] as List).cast<Map<String, dynamic>>();
    final raw = planets
        .map((p) => _PlanetSlot(
              p['name'] as String,
              (p['longitude'] as num).toDouble(),
              _screenDeg((p['longitude'] as num).toDouble()),
              p,
            ))
        .toList()
      ..sort((a, b) => a.displayDeg.compareTo(b.displayDeg));

    const minGap = 10.0;
    final adj = <_PlanetSlot>[];
    double? prev;
    for (final s in raw) {
      var d = s.displayDeg;
      if (prev != null && d - prev < minGap) d = prev + minGap;
      adj.add(_PlanetSlot(s.name, s.trueLon, d, s.raw));
      prev = d;
    }
    return adj;
  }

  Offset _point(Offset c, double r, double deg) {
    final a = deg * math.pi / 180;
    return Offset(c.dx + r * math.cos(a), c.dy - r * math.sin(a));
  }

  void _select({String? planet, int? house}) {
    setState(() {
      _selPlanet = planet;
      _selHouse = house;
    });
    _pulse
      ..reset()
      ..forward();
  }

  void _onTap(TapUpDetails d, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final R = math.min(size.width, size.height) / 2 - size.width * 0.03;
    final p = d.localPosition;
    final v = p - c;
    final dist = v.distance;

    final slots = _slots();
    for (final s in slots) {
      final pos = _point(c, R * 0.635, s.displayDeg);
      if ((p - pos).distance <= 20) {
        _select(planet: s.name);
        _showPlanet(s.raw);
        return;
      }
    }

    var deg = (math.atan2(-v.dy, v.dx) * 180 / math.pi) % 360;
    if (deg < 0) deg += 360;
    final lon = (deg - 180 - _rot + _ascLon) % 360;
    final lonN = lon < 0 ? lon + 360 : lon;

    if (dist >= R * 0.80 && dist <= R) {
      final idx = (lonN ~/ 30) % 12;
      _select();
      showSignLoreSheet(context, zodiacOrder[idx]);
      return;
    }
    if (dist >= R * 0.46 && dist < R * 0.80) {
      final h = _houseOf(lonN);
      _select(house: h);
      _showHouse(lonN);
    }
  }

  int _houseOf(double lon) {
    final houses =
        (widget.chart['houses'] as List).cast<Map<String, dynamic>>();
    for (var i = 0; i < 12; i++) {
      final a = (houses[i]['longitude'] as num).toDouble() % 360;
      final b = (houses[(i + 1) % 12]['longitude'] as num).toDouble() % 360;
      if (a <= b) {
        if (lon >= a && lon < b) return i + 1;
      } else {
        if (lon >= a || lon < b) return i + 1;
      }
    }
    return 12;
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxWidth);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _onTap(d, size),
            onHorizontalDragUpdate: (d) =>
                setState(() => _dragRot += d.delta.dx * 0.45),
            child: AnimatedBuilder(
              animation: Listenable.merge([_reveal, _idle, _pulse]),
              builder: (context, _) => CustomPaint(
                size: size,
                painter: _WheelPainter(
                  chart: widget.chart,
                  ascLon: _ascLon,
                  rot: _rot,
                  slots: _slots(),
                  reveal: Curves.easeOutCubic.transform(_reveal.value),
                  rawReveal: _reveal.value,
                  selPlanet: _selPlanet,
                  selHouse: _selHouse,
                  pulse: _pulse.isAnimating || _pulse.isCompleted
                      ? _pulse.value
                      : 0,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Hojas de detalle ────────────────────────────────────────────────────

  void _showPlanet(Map<String, dynamic> p) {
    final name = p['name'] as String;
    final sign = p['sign'] as String? ?? '';
    final deg = (p['degree_in_sign'] as num?)?.toDouble() ?? 0;
    final house = p['house'];
    final retro = p['retrograde'] == true;
    final mood = ArcanumMood.forPlanet(name);
    final favors = planetFavors[name];

    _sheet(
      mood: mood,
      builder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(planetGlyph[name] ?? '?',
                style: TextStyle(fontSize: 46, color: mood.accent)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(planetEs[name] ?? name,
                      style:
                          ArcanumText.heading(30, color: ArcanumColors.gold)),
                  Text(
                      '${signGlyph[sign] ?? ''} ${signEs[sign] ?? sign} · ${deg.floor()}°'
                      '${retro ? '  ·  retrógrado ℞' : ''}',
                      style: ArcanumText.body(15,
                          color: ArcanumColors.ivoryMuted, italic: true)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 22),
          if (house != null) ...[
            Text('CASA $house', style: ArcanumText.label()),
            const SizedBox(height: 8),
            Text(_houseMeaning[(house as int) - 1],
                style: ArcanumText.body(16)),
            const SizedBox(height: 20),
          ],
          if (favors != null) ...[
            Text('SU FUERZA FAVORECE', style: ArcanumText.label()),
            const SizedBox(height: 8),
            Text(favors, style: ArcanumText.body(16)),
            const SizedBox(height: 20),
          ],
          if (retro) ...[
            Text('RETRÓGRADO', style: ArcanumText.label()),
            const SizedBox(height: 8),
            Text(
                'Su corriente se vuelve hacia dentro: revisión, retorno y '
                'trabajo interior antes que impulso hacia afuera.',
                style: ArcanumText.body(16)),
          ],
        ],
      ),
    );
  }

  void _showHouse(double lon) {
    final h = _houseOf(lon);
    final houses =
        (widget.chart['houses'] as List).cast<Map<String, dynamic>>();
    final cuspSign = houses[h - 1]['sign'] as String? ?? '';
    _sheet(
      mood: ArcanumMood.neutral,
      builder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CASA $h', style: ArcanumText.label()),
          const SizedBox(height: 6),
          Text('${signGlyph[cuspSign] ?? ''} en la cúspide',
              style: ArcanumText.heading(28, color: ArcanumColors.gold)),
          const SizedBox(height: 18),
          Text(_houseMeaning[h - 1], style: ArcanumText.body(17)),
          const SizedBox(height: 18),
          Text(
              'La cúspide cae en ${signEs[cuspSign] ?? cuspSign}: ese signo '
              'colorea cómo vives este territorio de tu carta.',
              style: ArcanumText.body(15,
                  color: ArcanumColors.ivoryMuted, italic: true)),
        ],
      ),
    );
  }

  void _sheet({required ArcanumMood mood, required WidgetBuilder builder}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: ArcanumSurface(
          mood: mood,
          intensity: 0.42,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 18, 28, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ArcanumColors.goldMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                builder(ctx),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pintor ────────────────────────────────────────────────────────────────────

class _WheelPainter extends CustomPainter {
  final Map<String, dynamic> chart;
  final double ascLon;
  final double rot;
  final List<_PlanetSlot> slots;
  final double reveal; // eased 0..1
  final double rawReveal; // lineal 0..1 (para cascadas)
  final String? selPlanet;
  final int? selHouse;
  final double pulse;

  _WheelPainter({
    required this.chart,
    required this.ascLon,
    required this.rot,
    required this.slots,
    required this.reveal,
    required this.rawReveal,
    required this.selPlanet,
    required this.selHouse,
    required this.pulse,
  });

  double _deg(double lon) => (180 + (lon - ascLon) + rot) % 360;

  Offset _pt(Offset c, double r, double deg) {
    final a = deg * math.pi / 180;
    return Offset(c.dx + r * math.cos(a), c.dy - r * math.sin(a));
  }

  Offset _ptLon(Offset c, double r, double lon) => _pt(c, r, _deg(lon));

  // Fracción de aparición de una etapa dentro del reveal [start,end].
  double _stage(double start, double end) =>
      ((rawReveal - start) / (end - start)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final R = math.min(size.width, size.height) / 2 - size.width * 0.03;

    final zodOuter = R;
    final zodInner = R * 0.80;
    final glyphR = R * 0.905;
    final hubR = R * 0.46;
    final planetR = R * 0.635;
    final houseNumR = R * 0.545;

    final ringsA = Curves.easeOut.transform(_stage(0.0, 0.35));
    final housesA = Curves.easeOut.transform(_stage(0.25, 0.55));
    final aspectsA = Curves.easeOut.transform(_stage(0.5, 0.8));

    _paintBackglow(canvas, c, R);
    _paintZodiac(canvas, c, zodInner, zodOuter, glyphR, ringsA);
    if (selHouse != null) _paintHouseHighlight(canvas, c, hubR, zodInner);
    _paintHouses(canvas, c, hubR, zodInner, houseNumR, housesA);
    _paintAngles(canvas, c, zodInner, ringsA);
    _paintAspects(canvas, c, hubR, aspectsA);
    _paintCenter(canvas, c, hubR, ringsA);
    _paintPlanets(canvas, c, hubR, planetR);
  }

  void _paintBackglow(Canvas canvas, Offset c, double R) {
    canvas.drawCircle(
      c,
      R * 1.02,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xFF100D16), ArcanumColors.background],
        ).createShader(Rect.fromCircle(center: c, radius: R * 1.12)),
    );
  }

  void _paintZodiac(Canvas canvas, Offset c, double inner, double outer,
      double glyphR, double a) {
    if (a <= 0) return;
    for (var i = 0; i < 12; i++) {
      final el = _signElement[i];
      final glow = _elementGlow[el]!;
      final startLon = i * 30.0;
      final a0 = _deg(startLon) * math.pi / 180;
      final a1 = _deg(startLon + 30) * math.pi / 180;
      final path = Path();
      _sectorPath(path, c, inner, outer, a0, a1);
      final mid = _pt(c, (inner + outer) / 2, _deg(startLon + 15));
      // Glow tenue y desaturado (misterio, no neón).
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            colors: [
              glow.withValues(alpha: 0.17 * a),
              glow.withValues(alpha: 0.045 * a),
            ],
          ).createShader(
              Rect.fromCircle(center: mid, radius: (outer - inner) * 1.5)),
      );
    }

    for (final r in [outer, inner]) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = ArcanumColors.gold.withValues(alpha: 0.5 * a),
      );
    }
    for (var i = 0; i < 12; i++) {
      canvas.drawLine(
        _ptLon(c, inner, i * 30.0),
        _ptLon(c, outer, i * 30.0),
        Paint()
          ..strokeWidth = 1
          ..color = ArcanumColors.gold.withValues(alpha: 0.26 * a),
      );
    }
    for (var d = 0; d < 360; d += 5) {
      final len = (d % 10 == 0) ? 9.0 : 5.0;
      canvas.drawLine(
        _ptLon(c, inner, d.toDouble()),
        _ptLon(c, inner + len, d.toDouble()),
        Paint()
          ..strokeWidth = 1
          ..color = ArcanumColors.goldMuted
              .withValues(alpha: (d % 30 == 0 ? 0.5 : 0.26) * a),
      );
    }
    for (var i = 0; i < 12; i++) {
      final el = _signElement[i];
      final pos = _pt(c, glyphR, _deg(i * 30.0 + 15));
      _text(canvas, signGlyph[zodiacOrder[i]] ?? '', pos,
          _elementAccent[el]!.withValues(alpha: 0.95 * a), glyphR * 0.205,
          bold: true);
    }
  }

  void _sectorPath(
      Path path, Offset c, double inner, double outer, double a0, double a1) {
    final s0 = -a0, s1 = -a1;
    final sweep = s1 - s0;
    path
      ..addArc(Rect.fromCircle(center: c, radius: outer), s0, sweep)
      ..arcTo(Rect.fromCircle(center: c, radius: inner), s1, -sweep, false)
      ..close();
  }

  void _paintHouseHighlight(
      Canvas canvas, Offset c, double hubR, double zodInner) {
    final houses = (chart['houses'] as List).cast<Map<String, dynamic>>();
    final i = selHouse! - 1;
    final cusp = (houses[i]['longitude'] as num).toDouble();
    final next = (houses[(i + 1) % 12]['longitude'] as num).toDouble();
    final a0 = _deg(cusp) * math.pi / 180;
    final a1 = _deg(next) * math.pi / 180;
    final path = Path();
    _sectorPath(path, c, hubR, zodInner, a0, a1);
    final glowA = 0.10 + 0.10 * math.sin(pulse * math.pi);
    canvas.drawPath(
      path,
      Paint()..color = ArcanumColors.gold.withValues(alpha: glowA),
    );
  }

  void _paintHouses(Canvas canvas, Offset c, double hubR, double zodInner,
      double numR, double a) {
    if (a <= 0) return;
    canvas.drawCircle(
      c,
      hubR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = ArcanumColors.gold.withValues(alpha: 0.32 * a),
    );
    final houses = (chart['houses'] as List).cast<Map<String, dynamic>>();
    for (var i = 0; i < 12; i++) {
      final cusp = (houses[i]['longitude'] as num).toDouble();
      final isAngle = i == 0 || i == 3 || i == 6 || i == 9;
      final p0 = _ptLon(c, hubR, cusp);
      final p1 = _ptLon(c, zodInner, cusp);
      final paint = Paint()
        ..strokeWidth = isAngle ? 1.8 : 1.0
        ..color = (isAngle ? ArcanumColors.gold : ArcanumColors.goldMuted)
            .withValues(alpha: (isAngle ? 0.7 : 0.34) * a);
      if (isAngle) {
        canvas.drawLine(p0, p1, paint);
        // Extiende el eje angular hasta el centro → crucero de instrumento.
        canvas.drawLine(
          c,
          p0,
          Paint()
            ..strokeWidth = 0.9
            ..color = ArcanumColors.gold.withValues(alpha: 0.16 * a),
        );
      } else {
        _dashedLine(canvas, p0, p1, paint);
      }
      final next = (houses[(i + 1) % 12]['longitude'] as num).toDouble();
      var span = (next - cusp) % 360;
      if (span <= 0) span += 360;
      final numPos = _ptLon(c, numR, cusp + span / 2);
      _text(canvas, '${i + 1}', numPos,
          ArcanumColors.ivoryMuted.withValues(alpha: 0.5 * a), 13);
    }
  }

  void _paintAngles(Canvas canvas, Offset c, double zodInner, double a) {
    if (a <= 0) return;
    final asc = (chart['ascendant']?['longitude'] as num?)?.toDouble();
    final mc = (chart['midheaven']?['longitude'] as num?)?.toDouble();
    void label(double? lon, String txt) {
      if (lon == null) return;
      _text(canvas, txt, _ptLon(c, zodInner - 20, lon),
          ArcanumColors.gold.withValues(alpha: a), 15,
          bold: true);
    }

    label(asc, 'AC');
    label(mc, 'MC');
  }

  void _paintAspects(Canvas canvas, Offset c, double hubR, double a) {
    if (a <= 0) return;
    final aspects =
        (chart['aspects'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final lonByName = {
      for (final p in (chart['planets'] as List).cast<Map<String, dynamic>>())
        p['name'] as String: (p['longitude'] as num).toDouble()
    };
    for (final asp in aspects) {
      final l1 = lonByName[asp['p1']];
      final l2 = lonByName[asp['p2']];
      if (l1 == null || l2 == null) continue;
      final col = _aspectColor[asp['aspect']] ?? ArcanumColors.ivoryMuted;
      final p0 = _ptLon(c, hubR, l1);
      final full = _ptLon(c, hubR, l2);
      // "Traza" la línea creciendo desde p0 hacia p1.
      final p1 = Offset.lerp(p0, full, a)!;
      final hard = asp['aspect'] == 'trine' || asp['aspect'] == 'opposition';
      final sel = selPlanet != null &&
          (asp['p1'] == selPlanet || asp['p2'] == selPlanet);
      canvas.drawLine(
        p0,
        p1,
        Paint()
          ..strokeWidth = sel ? 1.8 : (hard ? 1.2 : 0.85)
          ..shader = LinearGradient(
            colors: [
              col.withValues(alpha: (sel ? 0.75 : 0.42)),
              col.withValues(alpha: (sel ? 0.32 : 0.14)),
              col.withValues(alpha: (sel ? 0.75 : 0.42)),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromPoints(p0, full)),
      );
    }
  }

  void _paintCenter(Canvas canvas, Offset c, double hubR, double a) {
    _text(canvas, '✦', c,
        ArcanumColors.gold.withValues(alpha: 0.6 * a), hubR * 0.16);
  }

  void _paintPlanets(Canvas canvas, Offset c, double hubR, double planetR) {
    final n = slots.length;
    for (var i = 0; i < n; i++) {
      final s = slots[i];
      // Cascada: cada planeta entra escalonado tras los aspectos.
      final start = 0.62 + (i / n) * 0.32;
      final t = Curves.easeOutBack
          .transform(((rawReveal - start) / 0.14).clamp(0.0, 1.0));
      if (t <= 0) continue;
      final pos = _pt(c, planetR, s.displayDeg);
      final hubPos = _ptLon(c, hubR, s.trueLon);
      final rDisc = planetR * 0.135 * t;
      final selected = s.name == selPlanet;

      canvas.drawLine(
        hubPos,
        pos,
        Paint()
          ..strokeWidth = 1
          ..color = ArcanumColors.gold.withValues(alpha: 0.24 * t),
      );

      if (selected) {
        final glowA = (0.25 + 0.30 * math.sin(pulse * math.pi)).clamp(0.0, 1.0);
        canvas.drawCircle(
          pos,
          rDisc * 1.9,
          Paint()..color = ArcanumColors.gold.withValues(alpha: 0.18 * glowA),
        );
        canvas.drawCircle(
          pos,
          rDisc * 1.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = ArcanumColors.gold.withValues(alpha: glowA),
        );
      }

      canvas.drawCircle(
        pos,
        rDisc,
        Paint()
          ..shader = RadialGradient(
            colors: const [ArcanumColors.surfaceHigh, Color(0xFF0E0E15)],
          ).createShader(Rect.fromCircle(center: pos, radius: rDisc)),
      );
      canvas.drawCircle(
        pos,
        rDisc,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = ArcanumColors.gold
              .withValues(alpha: (selected ? 0.85 : 0.5) * t),
      );
      _text(canvas, planetGlyph[s.name] ?? '?', pos,
          ArcanumColors.gold.withValues(alpha: t), rDisc * 1.15);
      if (s.raw['retrograde'] == true) {
        _text(canvas, '℞', pos + Offset(rDisc * 0.85, -rDisc * 0.85),
            ArcanumColors.burgundyLight.withValues(alpha: t), rDisc * 0.7);
      }
    }
  }

  void _text(Canvas canvas, String s, Offset center, Color color, double size,
      {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: ArcanumText.body(size, color: color).copyWith(
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 4.0, gap = 5.0;
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      canvas.drawLine(
          a + dir * d, a + dir * math.min(d + dash, total), paint);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) => true;
}
