import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';

/// "Humor" atmosférico de un panel: el material y la luz de su fondo.
///
/// Destilado del sistema de skins de las cartas del Oráculo
/// (`oraculo/widgets/tarot_card.dart`) para que CUALQUIER superficie de la app
/// pueda vestir la misma atmósfera viva — coherente en todo ARCANUM.
///
/// Cada humor deriva de una correspondencia real (elemento del Tarot o color
/// planetario clásico / escala Golden Dawn), no de decoración arbitraria:
/// el color de una pantalla SIGNIFICA algo.
class ArcanumMood {
  /// Borde oscuro que funde con el fondo de la app.
  final Color edge;

  /// Centro tintado donde cae la luz (foco).
  final Color core;

  /// Bruma saturada del elemento/planeta (inner-glow / bloom).
  final Color glow;

  /// Acento brillante (filete interior, chispas, texto de realce).
  final Color accent;

  /// Posición vertical de la luz (0 = arriba, 1 = abajo).
  final double lightY;

  const ArcanumMood({
    required this.edge,
    required this.core,
    required this.glow,
    required this.accent,
    this.lightY = 0.40,
  });

  // ── Elementos del Tarot ────────────────────────────────────────────────
  static const fire = ArcanumMood(
    edge: ArcanumColors.fireEdge,
    core: ArcanumColors.fireCore,
    glow: ArcanumColors.fireGlow,
    accent: ArcanumColors.fireAccent,
    lightY: 0.62,
  );
  static const water = ArcanumMood(
    edge: ArcanumColors.waterEdge,
    core: ArcanumColors.waterCore,
    glow: ArcanumColors.waterGlow,
    accent: ArcanumColors.waterAccent,
    lightY: 0.34,
  );
  static const air = ArcanumMood(
    edge: ArcanumColors.airEdge,
    core: ArcanumColors.airCore,
    glow: ArcanumColors.airGlow,
    accent: ArcanumColors.airAccent,
    lightY: 0.32,
  );
  static const earth = ArcanumMood(
    edge: ArcanumColors.earthEdge,
    core: ArcanumColors.earthCore,
    glow: ArcanumColors.earthGlow,
    accent: ArcanumColors.earthAccent,
    lightY: 0.62,
  );

  // ── Luminarias y planetas (color clásico / Golden Dawn) ────────────────
  static const moon = ArcanumMood(
    edge: ArcanumColors.moonEdge,
    core: ArcanumColors.moonCore,
    glow: ArcanumColors.moonGlow,
    accent: ArcanumColors.moonAccent,
    lightY: 0.30,
  );
  static const sun = ArcanumMood(
    edge: ArcanumColors.sunEdge,
    core: ArcanumColors.sunCore,
    glow: ArcanumColors.sunGlow,
    accent: ArcanumColors.sunAccent,
    lightY: 0.44,
  );
  static const jupiter = ArcanumMood(
    edge: ArcanumColors.jupiterEdge,
    core: ArcanumColors.jupiterCore,
    glow: ArcanumColors.jupiterGlow,
    accent: ArcanumColors.jupiterAccent,
    lightY: 0.36,
  );
  static const saturn = ArcanumMood(
    edge: ArcanumColors.saturnEdge,
    core: ArcanumColors.saturnCore,
    glow: ArcanumColors.saturnGlow,
    accent: ArcanumColors.saturnAccent,
    lightY: 0.30,
  );

  /// Atmósfera base (pergamino tibio) para paneles sin correspondencia.
  static const neutral = ArcanumMood(
    edge: ArcanumColors.neutralEdge,
    core: ArcanumColors.neutralCore,
    glow: ArcanumColors.neutralGlow,
    accent: ArcanumColors.neutralAccent,
    lightY: 0.36,
  );

  /// Resuelve el humor de un elemento del Tarot (fuego/agua/aire/tierra).
  factory ArcanumMood.forElement(String element) {
    switch (element.toLowerCase()) {
      case 'fuego':
      case 'fire':
        return fire;
      case 'agua':
      case 'water':
        return water;
      case 'tierra':
      case 'earth':
        return earth;
      case 'aire':
      case 'air':
        return air;
      default:
        return air;
    }
  }

  /// Resuelve el humor de un planeta clásico (clave EN del backend).
  ///
  /// Correspondencias: Marte→fuego (escarlata), Venus→tierra (verde/cobre,
  /// rige Tauro), Mercurio→aire (rige Géminis), Sol/Luna/Júpiter/Saturno con
  /// atmósfera propia. Es el color VERDADERO del regente del día.
  factory ArcanumMood.forPlanet(String planet) {
    switch (planet.toLowerCase()) {
      case 'sun':
        return sun;
      case 'moon':
        return moon;
      case 'mars':
        return fire;
      case 'venus':
        return earth;
      case 'mercury':
        return air;
      case 'jupiter':
        return jupiter;
      case 'saturn':
        return saturn;
      default:
        return neutral;
    }
  }

  /// Interpola dos humores (para transiciones suaves de atmósfera).
  static ArcanumMood lerp(ArcanumMood a, ArcanumMood b, double t) =>
      ArcanumMood(
        edge: Color.lerp(a.edge, b.edge, t)!,
        core: Color.lerp(a.core, b.core, t)!,
        glow: Color.lerp(a.glow, b.glow, t)!,
        accent: Color.lerp(a.accent, b.accent, t)!,
        lightY: a.lightY + (b.lightY - a.lightY) * t,
      );
}
