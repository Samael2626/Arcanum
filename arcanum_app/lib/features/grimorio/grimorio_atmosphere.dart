import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/widgets/arcanum_mood.dart';
import '../../shared/widgets/arcanum_surface.dart';

// ── Léxico del códice ───────────────────────────────────────────────────────

/// Tipos de entrada en español.
const entryTypeEs = {
  'ritual': 'Ritual',
  'reading': 'Lectura',
  'note': 'Nota',
  'sigil': 'Sigilo',
};

/// Emblema de cada tipo — un glifo que sella la clase del trabajo mágico.
/// Ritual=pentáculo invertido de la labor · Lectura=estrella del oráculo ·
/// Nota=fleurón del escriba · Sigilo=nodo del sello.
const entryTypeGlyph = {
  'ritual': '⛧',
  'reading': '✦',
  'note': '❦',
  'sigil': '⟠',
};

/// Regente planetario del día de la semana (día caldeo clásico).
/// DateTime.weekday: 1=Lunes … 7=Domingo. Clave EN → ArcanumMood.forPlanet.
const _weekdayPlanet = {
  1: 'moon', // Lunes
  2: 'mars', // Martes
  3: 'mercury', // Miércoles
  4: 'jupiter', // Jueves
  5: 'venus', // Viernes
  6: 'saturn', // Sábado
  7: 'sun', // Domingo
};

const _weekdayEs = {
  1: 'Lunes',
  2: 'Martes',
  3: 'Miércoles',
  4: 'Jueves',
  5: 'Viernes',
  6: 'Sábado',
  7: 'Domingo',
};

const _monthEs = [
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

/// Contexto ritual derivado de una entrada del grimorio.
class GrimoireDay {
  final String planet; // clave EN (regente del día)
  final String weekdayEs;
  final String longDate; // "2 de julio, 2026"
  final ArcanumMood mood;

  const GrimoireDay(this.planet, this.weekdayEs, this.longDate, this.mood);

  /// Resuelve el día a partir de `entry_date` (ISO) y el `day_planet` guardado
  /// (best-effort al crear). Si falta el planeta, se deriva del día de la semana
  /// real — la correspondencia clásica, no un default arbitrario.
  factory GrimoireDay.from(String? isoDate, String? storedPlanet) {
    final d = DateTime.tryParse(isoDate ?? '')?.toLocal() ?? DateTime.now();
    final planet = (storedPlanet != null && storedPlanet.isNotEmpty)
        ? storedPlanet
        : (_weekdayPlanet[d.weekday] ?? 'moon');
    final long = '${d.day} de ${_monthEs[d.month - 1]}, ${d.year}';
    return GrimoireDay(
      planet,
      _weekdayEs[d.weekday] ?? '',
      long,
      ArcanumMood.forPlanet(planet),
    );
  }
}

// ── Fondo vivo del libro ────────────────────────────────────────────────────

/// Atmósfera de pergamino oscuro que respira, para el fondo de cualquier
/// pantalla del grimorio. Penumbra tibia (neutral) o insinuación del regente de
/// una entrada; intensidad baja para que el texto mande. Sin grano (coste en
/// pantalla completa) — la deriva lenta da la vida.
class GrimoireSky extends StatefulWidget {
  final ArcanumMood mood;
  final double intensity;
  const GrimoireSky({
    super.key,
    this.mood = ArcanumMood.neutral,
    this.intensity = 0.32,
  });

  @override
  State<GrimoireSky> createState() => _GrimoireSkyState();
}

class _GrimoireSkyState extends State<GrimoireSky>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 54),
  )..repeat();

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _drift,
      builder: (context, _) => ArcanumSurface(
        mood: widget.mood,
        drift: _drift.value,
        grain: false,
        intensity: widget.intensity,
      ),
    );
  }
}

// ── Capitular iluminada (medallón del scriptorium) ──────────────────────────

/// Primera letra de un título en un medallón dorado con la atmósfera viva del
/// regente del día — como la inicial iluminada de un manuscrito.
class IlluminatedDropCap extends StatelessWidget {
  final String letter;
  final ArcanumMood mood;
  final double size;
  const IlluminatedDropCap({
    super.key,
    required this.letter,
    required this.mood,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(size * 0.22);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: r,
        border: Border.all(color: mood.accent.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: mood.glow.withValues(alpha: 0.16),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: ArcanumSurface(
          mood: mood,
          intensity: 0.85,
          child: Center(
            child: Text(
              letter.toUpperCase(),
              style: ArcanumText.heading(
                size * 0.62,
                color: mood.accent,
              ).copyWith(height: 1),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Colofón de cierre ───────────────────────────────────────────────────────

/// Filete ornamental de fin de página + línea de colofón en itálica.
class ClosingColophon extends StatelessWidget {
  final String note;
  final Color accent;
  const ClosingColophon({
    super.key,
    required this.note,
    this.accent = ArcanumColors.gold,
  });

  @override
  Widget build(BuildContext context) {
    Widget rule() => Expanded(
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              ArcanumColors.goldMuted.withValues(alpha: 0.5),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            rule(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '✦ ⟡ ✦',
                style: TextStyle(color: accent, fontSize: 15, letterSpacing: 4),
              ),
            ),
            rule(),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          note,
          textAlign: TextAlign.center,
          style: ArcanumText.body(
            13.5,
            italic: true,
            color: ArcanumColors.ivoryMuted,
          ),
        ),
      ],
    );
  }
}

// ── Entrada en cascada ──────────────────────────────────────────────────────

/// Emerge del velo (opacidad + leve ascenso) tras [delayMs]. Para escalonar
/// la aparición de las hojas del códice.
class Cascade extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const Cascade({super.key, required this.child, this.delayMs = 0});

  @override
  State<Cascade> createState() => _CascadeState();
}

class _CascadeState extends State<Cascade> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.delayMs == 0) {
      _c.forward();
      return;
    }
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 22),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ── Feedback táctil al pulsar una hoja ──────────────────────────────────────

/// Hunde/atenúa levemente al pulsar (feedback físico) y dispara [onTap].
class PressFade extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const PressFade({super.key, required this.child, required this.onTap});

  @override
  State<PressFade> createState() => _PressFadeState();
}

class _PressFadeState extends State<PressFade> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _down ? 0.86 : 1.0,
          duration: const Duration(milliseconds: 140),
          child: widget.child,
        ),
      ),
    );
  }
}

// ── Transición "pasar página" ───────────────────────────────────────────────

/// Ruta con giro de página: la entrante rota en Y desde el borde (perspectiva
/// real) mientras aparece y se desliza. Elegante, barata (solo transform +
/// opacidad), 60fps. La saliente cede con una leve caída de opacidad.
Route<T> bookPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 520),
    reverseTransitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (context, animation, secondary) => page,
    transitionsBuilder: (context, anim, secondary, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return AnimatedBuilder(
        animation: Listenable.merge([curved, secondary]),
        builder: (context, _) {
          final t = curved.value; // 0→1 entrante
          final rotY = (1 - t) * 0.72; // pliego que se abre desde la derecha
          final s = secondary.value; // saliente empujada atrás
          final matrix = Matrix4.identity()
            ..setEntry(3, 2, 0.0016)
            ..translateByDouble(0.0, 0.0, s * -60.0, 1.0)
            ..rotateY(rotY - s * 0.28);
          return Opacity(
            opacity: (t).clamp(0.0, 1.0) * (1 - s * 0.5),
            child: Transform(
              alignment: Alignment.centerLeft,
              transform: matrix,
              child: child,
            ),
          );
        },
      );
    },
  );
}

// ── Destello del sello (feedback al guardar) ────────────────────────────────

/// Overlay de sello lacrado: un disco de vino con un sigilo dorado que se
/// estampa (escala elástica) y late; al terminar dispara [onDone]. Da el
/// micro-feedback ritual de "sellar" una entrada.
class SealStamp extends StatefulWidget {
  final VoidCallback onDone;
  final Color accent;
  const SealStamp({
    super.key,
    required this.onDone,
    this.accent = ArcanumColors.gold,
  });

  @override
  State<SealStamp> createState() => _SealStampState();
}

class _SealStampState extends State<SealStamp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          // Estampa: golpe elástico 0→0.55, sostiene, se desvanece al final.
          final stamp = Curves.elasticOut.transform((t / 0.55).clamp(0.0, 1.0));
          final fade = t < 0.78 ? 1.0 : (1 - (t - 0.78) / 0.22);
          final ring = Curves.easeOut.transform((t / 0.7).clamp(0.0, 1.0));
          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Container(
              color: Colors.black.withValues(alpha: 0.42 * fade),
              alignment: Alignment.center,
              child: SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Onda expansiva del sello.
                    Transform.scale(
                      scale: 0.6 + ring * 1.1,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.accent.withValues(
                              alpha: 0.5 * (1 - ring),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Disco de lacre.
                    Transform.scale(
                      scale: (0.4 + stamp * 0.6).clamp(0.0, 1.0),
                      child: Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ArcanumColors.burgundy.withValues(alpha: 0.92),
                          border: Border.all(
                            color: widget.accent.withValues(alpha: 0.85),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.accent.withValues(alpha: 0.32),
                              blurRadius: 26,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '⛨',
                          style: TextStyle(
                            fontSize: 52,
                            color: widget.accent,
                            height: 1,
                            shadows: [
                              Shadow(
                                color: widget.accent.withValues(alpha: 0.6),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Heptagrama respirante (sello del estado vacío) ──────────────────────────

/// Estrella de siete puntas (sello del misterio) que rota muy lento tras el
/// emblema del grimorio vacío.
class BreathingHeptagram extends StatefulWidget {
  final double size;
  const BreathingHeptagram({super.key, this.size = 150});

  @override
  State<BreathingHeptagram> createState() => _BreathingHeptagramState();
}

class _BreathingHeptagramState extends State<BreathingHeptagram>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Transform.rotate(
        angle: _c.value * 2 * math.pi,
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _HeptagramPainter(),
        ),
      ),
    );
  }
}

class _HeptagramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.5;
    final pts = <Offset>[
      for (var i = 0; i < 7; i++)
        Offset(
          c.dx + r * math.cos(-math.pi / 2 + i * 2 * math.pi / 7),
          c.dy + r * math.sin(-math.pi / 2 + i * 2 * math.pi / 7),
        ),
    ];
    final path = Path();
    // Heptagrama {7/3}: salta 3 vértices cada trazo.
    var idx = 0;
    path.moveTo(pts[0].dx, pts[0].dy);
    for (var k = 0; k < 7; k++) {
      idx = (idx + 3) % 7;
      path.lineTo(pts[idx].dx, pts[idx].dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = ArcanumColors.goldMuted.withValues(alpha: 0.28),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
