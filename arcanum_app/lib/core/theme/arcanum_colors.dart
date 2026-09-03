import 'package:flutter/material.dart';

/// Paleta "Grimorio Vivo" — manuscrito medieval digitalizado.
class ArcanumColors {
  static const background = Color(0xFF0A0A0F);
  static const surface = Color(0xFF12121A);
  static const surfaceHigh = Color(0xFF1C1C28);
  static const gold = Color(0xFFC9A84C);
  static const goldMuted = Color(0xFF8A6E32);
  /// Oro claro de los rombos y realces finos del instrumento.
  static const goldLight = Color(0xFFECD79A);
  static const burgundy = Color(0xFF4A0E1A);
  // Vino legible sobre fondos oscuros — estado "invertida" de una carta.
  static const burgundyLight = Color(0xFFB07686);
  static const ivory = Color(0xFFF5F0E8);
  static const ivoryMuted = Color(0xFFB8B0A0);
  static const error = Color(0xFF8B1A1A);

  // ── Elementos del Tarot (caras vectoriales de las cartas) ──────────────
  // Acentos por elemento, calibrados para leerse sobre fondo oscuro sin
  // pelear con el oro. Fuego=ámbar-ascua · Agua=azul profundo ·
  // Aire=oro pálido luminoso · Tierra=verde vegetal.
  static const elementFire = Color(0xFFCB6A3E);
  static const elementWater = Color(0xFF4E86C4);
  static const elementAir = Color(0xFFE4D69A);
  static const elementEarth = Color(0xFF6FA766);

  // ── Atmósferas internas de las cartas ──────────────────────────────────
  // Fondo vivo tras el emblema, derivado del elemento/palo (Menores) o de la
  // correspondencia astral (Mayores). Cada atmósfera: edge (borde oscuro que
  // funde con el naipe) · core (centro tintado, donde cae la luz) · glow
  // (bruma saturada del elemento) · accent (color del emblema, más brillante).
  // Saturación calibrada para que "levante" sin chillar sobre negro.
  static const fireEdge = Color(0xFF180806);
  static const fireCore = Color(0xFF3A1109);
  static const fireGlow = Color(0xFFE0561F);
  static const fireAccent = Color(0xFFF0854A);

  static const waterEdge = Color(0xFF03111B);
  static const waterCore = Color(0xFF0B2A3A); // azul petróleo profundo, no cian
  static const waterGlow = Color(0xFF3A8FAC);
  static const waterAccent = Color(0xFF78C2D6);

  static const airEdge = Color(0xFF161207);
  static const airCore = Color(0xFF38311C); // penumbra cálida, cielo dorado
  static const airGlow = Color(0xFFD8BE72);
  static const airAccent = Color(0xFFF2E2A6);

  static const earthEdge = Color(0xFF070D06);
  static const earthCore = Color(0xFF182611); // musgo profundo
  static const earthGlow = Color(0xFF6FA24A);
  static const earthAccent = Color(0xFFC99B44); // bronce vegetal

  // Mayores destacados con atmósfera propia.
  static const moonEdge = Color(0xFF04060E);
  static const moonCore = Color(0xFF101A32); // nocturno plateado
  static const moonGlow = Color(0xFF8FA8D6);
  static const moonAccent = Color(0xFFCFDCF2);

  static const sunEdge = Color(0xFF201002);
  static const sunCore = Color(0xFF552F06); // radiante dorado
  static const sunGlow = Color(0xFFEDAE30);
  static const sunAccent = Color(0xFFFAD26A);

  // Júpiter — día de Júpiter (jueves). Púrpura regio: Tzedek, el rey
  // benéfico, estaño, escala de la reina Golden Dawn (violeta/azul real).
  // Expansión, abundancia, justicia. Lujo sin chillar sobre negro.
  static const jupiterEdge = Color(0xFF0A0820);
  static const jupiterCore = Color(0xFF241A55); // índigo-violeta real
  static const jupiterGlow = Color(0xFF6C5CD8); // amatista regia
  static const jupiterAccent = Color(0xFFB9A8F5);

  // Saturno — día de Saturno (sábado). Índigo-plomo frío: Binah, el
  // Anciano, plomo, límites y disciplina. Acero frío, no negro muerto.
  static const saturnEdge = Color(0xFF07080C);
  static const saturnCore = Color(0xFF161A28); // pizarra índigo helada
  static const saturnGlow = Color(0xFF4A5A78); // azul acero
  static const saturnAccent = Color(0xFF9FB0C8); // plata-acero fría

  // Neutral — atmósfera base para paneles sin correspondencia (grimorio,
  // ajustes). Penumbra tibia dorada: el "pergamino vivo" por defecto.
  static const neutralEdge = Color(0xFF0A0A0F);
  static const neutralCore = Color(0xFF1A1720); // surface tibio elevado
  static const neutralGlow = Color(0xFF8A6E32); // oro apagado
  static const neutralAccent = Color(0xFFC9A84C);

  // ── Aspectos de la rueda natal ─────────────────────────────────────────
  // Trazos que cruzan el centro de la carta, coloreados por su naturaleza.
  // Unión (conjunción) = oro · Armonía (sextil/trígono) = azul sereno ·
  // Tensión (cuadratura/oposición) = ascua roja. Sobrios sobre negro.
  static const aspectUnion = gold;
  static const aspectHarmony = Color(0xFF5E9BB8);
  static const aspectTension = Color(0xFFB0563E);
}
