/// Menu radial de la mesa, sin widgets: disposicion, eleccion por angulo y
/// el ORDEN FIJO de cada menu.
///
/// Orden fijo: una opcion imposible se apaga, no desaparece. Si se quitara,
/// las demas cambiarian de sitio y la mano, que ya sabe donde esta
/// «Barajar», acabaria en otra opcion.
library;

import 'dart:math' as math;
import 'dart:ui';

class RadialItem {
  const RadialItem(
    this.id,
    this.label, {
    this.enabled = true,
    this.current = false,
    this.glyph,
  });

  final String id;
  final String label;
  final bool enabled;

  /// Dibujo propio (camino SVG en 24x24) cuando el id no tiene icono fijo:
  /// cada tirada se dibuja con su propia disposicion.
  final String? glyph;

  /// La opcion que ya esta en uso (p. ej. la tirada puesta).
  final bool current;
}

class RadialLayout {
  RadialLayout._(
    this.center,
    this.anchor,
    this.radius,
    this.items,
    this.positions,
  );

  /// Coloca el radial alrededor de `anchor` sin salirse de la pantalla.
  factory RadialLayout.at(Offset anchor, Size screen, List<RadialItem> items) {
    final n = items.length;
    final r = n > 6 ? largeRadius : radius0;
    final pad = r + 44;
    final cx = anchor.dx
        .clamp(pad, math.max(pad, screen.width - pad))
        .toDouble();
    // arriba deja sitio tambien al titulo, que va encima del circulo
    final top = pad + titleHeight, bottom = screen.height - pad - 16;
    final cy = anchor.dy.clamp(top, math.max(top, bottom)).toDouble();
    final center = Offset(cx, cy);
    return RadialLayout._(center, anchor, r, items, [
      for (var i = 0; i < n; i++)
        center + Offset(math.cos(angleOf(i, n)), math.sin(angleOf(i, n))) * r,
    ]);
  }

  static const double radius0 = 86;
  static const double largeRadius = 100;

  /// Zona muerta del centro y del punto pulsado: ahi no se marca nada y
  /// soltar deja el radial abierto.
  static const double deadZone = 46;

  /// Alto que se reserva al titulo encima del circulo.
  static const double titleHeight = 20;

  /// Diametro de cada circulo (dp).
  static const double buttonSize = 52;

  final Offset center;

  /// Donde se pulso. Pegado al borde el circulo se mete hacia dentro y una
  /// opcion puede quedar bajo el dedo: soltar sin deslizar no debe elegirla.
  final Offset anchor;
  final double radius;
  final List<RadialItem> items;
  final List<Offset> positions;

  /// La primera opcion arriba y el resto en el sentido de las agujas del reloj.
  static double angleOf(int i, int n) => -math.pi / 2 + i * 2 * math.pi / n;

  /// Donde va el titulo: encima del circulo.
  Offset get titlePosition => center.translate(0, -radius - 44);

  /// Opcion marcada con el dedo en `p`, o null (centro u opcion apagada).
  int? hotAt(Offset p) {
    final d = p - center;
    if (d.distance <= deadZone || (p - anchor).distance <= deadZone) {
      return null;
    }
    final n = items.length;
    final a =
        (math.atan2(d.dy, d.dx) + math.pi / 2 + math.pi * 4) % (math.pi * 2);
    final i = (a / (math.pi * 2 / n)).round() % n;
    return items[i].enabled ? i : null;
  }

  /// Opcion bajo un toque directo (tocar el circulo, no deslizar), o null.
  int? tappedAt(Offset p) {
    for (var i = 0; i < positions.length; i++) {
      final near = (positions[i] - p).distance <= buttonSize / 2 + 6;
      if (near && items[i].enabled) return i;
    }
    return null;
  }
}

/// Los menus de la mesa, en el orden del prototipo.
abstract final class RadialMenus {
  static List<RadialItem> card({
    required bool faceUp,
    required bool aside,
    required bool canRevealAll,
  }) => [
    faceUp
        ? const RadialItem('read', 'Leer')
        : const RadialItem('reveal', 'Desvelar'),
    const RadialItem('turn', 'Girar'),
    const RadialItem('collect', 'Recoger'),
    RadialItem('aside', 'Sacar', enabled: !aside),
    RadialItem('reveal-all', 'Desvelar todas', enabled: canRevealAll),
  ];

  static List<RadialItem> deck({
    required int count,
    required bool cardsOut,
    required int piles,
  }) => [
    RadialItem('shuffle', 'Barajar', enabled: count >= 4),
    RadialItem('cut', 'Cortar', enabled: count >= 4),
    RadialItem('fan', 'Extender', enabled: count > 0),
    RadialItem('deal', 'Sacar', enabled: count > 0),
    RadialItem('collect', 'Recoger', enabled: cardsOut),
    const RadialItem('spread', 'Tirada'),
    RadialItem('union', 'Unir', enabled: piles >= 2),
  ];

  /// «Tirada» va al final: las tres primeras no se mueven de sitio.
  static const List<RadialItem> fan = [
    RadialItem('take', 'Sacar'),
    RadialItem('gather', 'Juntar'),
    RadialItem('shuffle', 'Barajar'),
    RadialItem('spread', 'Tirada'),
  ];

  /// Los ids son los estilos que acepta el backend.
  static const List<RadialItem> shuffle = [
    RadialItem('cascada', 'Cascada'),
    RadialItem('por_encima', 'Por encima'),
    RadialItem('sobre_el_pano', 'Sobre el paño'),
  ];

  static const List<RadialItem> union = [
    RadialItem('order', 'Elegir orden'),
    RadialItem('auto', 'Automático'),
  ];

  static List<RadialItem> cloth({
    required bool canSeal,
    required bool canGather,
    required bool hasReadings,
    required bool soundOn,
  }) => [
    RadialItem('seal', 'Sellar pregunta', enabled: canSeal),
    RadialItem('all', 'Recoger todo', enabled: canGather),
    RadialItem('hist', 'Lecturas', enabled: hasReadings),
    RadialItem('sound', soundOn ? 'Silenciar' : 'Sonido'),
  ];

  /// Recoger con una lectura empezada obliga a decidir si se guarda.
  static const List<RadialItem> gatherWithReading = [
    RadialItem('close', 'Cerrar el círculo'),
    RadialItem('drop', 'Sin guardar'),
  ];
}
