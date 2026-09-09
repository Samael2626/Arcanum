// GENERADO por tools/build_zodiaco_engravings.py -- no editar a mano.
//
// El delta del velo de cada signo esta MEDIDO, no elegido: sale de donde acaba
// la figura de su plancha, topado por el contraste del texto que va encima.
// Ver el campo `velo` de assets/engravings/manifest.json.
library;

/// Una lamina de la Uranometria lista para ir de fondo de la tarjeta.
class LaminaSigno {
  const LaminaSigno({
    required this.asset,
    required this.delta,
    required this.altoLamina,
    required this.banda,
  });

  /// El recorte, ya a la proporcion de la tarjeta (salvo Piscis).
  final String asset;

  /// Cuanto baja el bloque de datos del velo, en px de una tarjeta de 479.
  final int delta;

  /// Alto del recorte en px de tarjeta: 479 a sangre, 240 en banda.
  final int altoLamina;

  /// Piscis va en banda y no a sangre: sus dos peces no caben a proporcion de
  /// tarjeta. Es la unica excepcion; el manifest explica el porque.
  final bool banda;
}

enum Signo { capricornio, aries, tauro, geminis, cancer, leo, virgo, libra, escorpio, sagitario, acuario, piscis }

/// Alto de la tarjeta sobre el que se midieron los delta. Los numeros del velo
/// se leen contra este alto y se escalan al alto real de la tarjeta.
const double altoDeReferencia = 479;

const Map<Signo, LaminaSigno> laminasDelZodiaco = {
  Signo.capricornio: LaminaSigno(
    asset: 'assets/engravings/zodiaco/capricornio.jpg',
    delta: 64,
    altoLamina: 479,
    banda: false,
  ),
  Signo.aries: LaminaSigno(
    asset: 'assets/engravings/zodiaco/aries.jpg',
    delta: 0,
    altoLamina: 479,
    banda: false,
  ),
  Signo.tauro: LaminaSigno(
    asset: 'assets/engravings/zodiaco/tauro.jpg',
    delta: 66,
    altoLamina: 479,
    banda: false,
  ),
  Signo.geminis: LaminaSigno(
    asset: 'assets/engravings/zodiaco/geminis.jpg',
    delta: 43,
    altoLamina: 479,
    banda: false,
  ),
  Signo.cancer: LaminaSigno(
    asset: 'assets/engravings/zodiaco/cancer.jpg',
    delta: 55,
    altoLamina: 479,
    banda: false,
  ),
  Signo.leo: LaminaSigno(
    asset: 'assets/engravings/zodiaco/leo.jpg',
    delta: 0,
    altoLamina: 479,
    banda: false,
  ),
  Signo.virgo: LaminaSigno(
    asset: 'assets/engravings/zodiaco/virgo.jpg',
    delta: 0,
    altoLamina: 479,
    banda: false,
  ),
  Signo.libra: LaminaSigno(
    asset: 'assets/engravings/zodiaco/libra.jpg',
    delta: 75,
    altoLamina: 479,
    banda: false,
  ),
  Signo.escorpio: LaminaSigno(
    asset: 'assets/engravings/zodiaco/escorpio.jpg',
    delta: 71,
    altoLamina: 479,
    banda: false,
  ),
  Signo.sagitario: LaminaSigno(
    asset: 'assets/engravings/zodiaco/sagitario.jpg',
    delta: 31,
    altoLamina: 479,
    banda: false,
  ),
  Signo.acuario: LaminaSigno(
    asset: 'assets/engravings/zodiaco/acuario.jpg',
    delta: 0,
    altoLamina: 479,
    banda: false,
  ),
  Signo.piscis: LaminaSigno(
    asset: 'assets/engravings/zodiaco/piscis.jpg',
    delta: 0,
    altoLamina: 240,
    banda: true,
  ),
};

/// Del `sun_sign` que manda el servidor (ingles) al signo de la app.
const Map<String, Signo> signoDesdeIngles = {
  'aries': Signo.aries,
  'taurus': Signo.tauro,
  'gemini': Signo.geminis,
  'cancer': Signo.cancer,
  'leo': Signo.leo,
  'virgo': Signo.virgo,
  'libra': Signo.libra,
  'scorpio': Signo.escorpio,
  'sagittarius': Signo.sagitario,
  'capricorn': Signo.capricornio,
  'aquarius': Signo.acuario,
  'pisces': Signo.piscis,
};
