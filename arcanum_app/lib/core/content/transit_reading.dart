import '../../shared/astro_symbols.dart';

/// Traduce un tránsito a español llano, sin IA y sin red.
///
/// "♀ Venus trígono ☽ Luna natal" no dice nada a quien empieza, aunque
/// entienda cada palabra por separado. Aquí se compone la lectura a partir de
/// piezas fijas: qué gobierna cada planeta, qué hace cada aspecto y qué
/// favorece el cruce de ambos. Determinista y offline — la lectura
/// personalizada del oráculo es otra capa, opcional y de pago.

/// Cómo se siente el aspecto. Ordena el tono de la guía.
enum AspectTone {
  /// Conjunción: las fuerzas se funden, para bien o para mal.
  fusion,

  /// Sextil y trígono: apoyo.
  armonico,

  /// Cuadratura y oposición: tensión que pide trabajo.
  tenso,
}

class TransitReading {
  /// La línea traducida a lenguaje llano.
  final String sentence;

  /// Qué hace este aspecto, en una frase.
  final String nature;

  /// Qué conviene hacer con esto.
  final String guidance;

  final AspectTone tone;

  const TransitReading({
    required this.sentence,
    required this.nature,
    required this.guidance,
    required this.tone,
  });
}

/// Qué gobierna cada planeta, en pocas palabras y en segunda persona.
const Map<String, String> planetRole = {
  'sun': 'tu identidad y tu voluntad',
  'moon': 'tu mundo emocional y tus hábitos',
  'mercury': 'cómo piensas y te comunicas',
  'venus': 'lo que amas y lo que valoras',
  'mars': 'tu impulso y tu manera de pelear',
  'jupiter': 'tu expansión y aquello en lo que confías',
  'saturn': 'tus límites y tu disciplina',
  'uranus': 'tu necesidad de romper y liberarte',
  'neptune': 'tu imaginación y también tu niebla',
  'pluto': 'lo que en ti muere y vuelve a nacer',
  'north_node': 'la dirección hacia la que creces',
};

/// Qué hace cada aspecto, en una frase.
const Map<String, String> _aspectNature = {
  'conjunction':
      'Se funden en una sola fuerza: lo que tocan, lo amplifican — para bien '
      'o para mal.',
  'sextile':
      'Puerta abierta: la oportunidad está ahí, pero no entra sola. Responde '
      'si das el primer paso.',
  'square':
      'Fricción: dos fuerzas que no se entienden y empujan en direcciones '
      'distintas. Incómodo, pero produce carácter.',
  'trine':
      'Apoyo que fluye sin esfuerzo — y justo por eso es fácil dejarlo pasar '
      'sin usarlo.',
  'opposition':
      'Un pulso cara a cara que pide equilibrio, no un ganador. Suele verse '
      'primero fuera de ti, en otra persona.',
};

const Map<String, AspectTone> _aspectTone = {
  'conjunction': AspectTone.fusion,
  'sextile': AspectTone.armonico,
  'trine': AspectTone.armonico,
  'square': AspectTone.tenso,
  'opposition': AspectTone.tenso,
};

const Map<AspectTone, String> _guidancePrefix = {
  AspectTone.fusion: 'Se intensifica todo lo relativo a',
  AspectTone.armonico: 'Ventana favorable para trabajar',
  AspectTone.tenso: 'Pide cautela y trabajo consciente en',
};

/// Tono de un aspecto, sin componer la lectura entera (para colorear la UI).
/// Un aspecto desconocido se trata como fusión: intensifica, no juzga.
AspectTone aspectToneOf(String aspect) =>
    _aspectTone[aspect.toLowerCase()] ?? AspectTone.fusion;

/// Compone la lectura de un tránsito sobre la carta natal.
///
/// [transit] y [natal] son claves de planeta ('venus', 'moon'); [aspect] es la
/// clave inglesa del backend ('trine', 'square'…).
TransitReading readTransit({
  required String transit,
  required String natal,
  required String aspect,
}) {
  final transitName = planetEs[transit] ?? transit;
  final natalName = planetEs[natal] ?? natal;
  final aspectName = aspectEs[aspect] ?? aspect;
  final tone = _aspectTone[aspect] ?? AspectTone.fusion;

  final sentence = StringBuffer('Hoy $transitName')
    ..write(_parenthetical(planetRole[transit]))
    ..write(' forma $aspectName con tu $natalName natal')
    ..write(_parenthetical(planetRole[natal]))
    ..write('.');

  final favors = [
    planetFavors[transit],
    planetFavors[natal],
  ].whereType<String>().join(' · ');

  final guidance = favors.isEmpty
      ? '${_guidancePrefix[tone]} este cruce.'
      : '${_guidancePrefix[tone]}: $favors.';

  return TransitReading(
    sentence: sentence.toString(),
    nature: _aspectNature[aspect] ?? 'Un ángulo entre dos fuerzas de tu carta.',
    guidance: guidance,
    tone: tone,
  );
}

/// " (rol)" o cadena vacía si el planeta no tiene rol definido, para que la
/// frase nunca quede con un paréntesis huérfano.
String _parenthetical(String? role) => role == null ? '' : ' ($role)';

/// Pregunta para `POST /oracle/ia` sobre un tránsito concreto.
///
/// El servidor ya inyecta la carta natal del usuario en el contexto, así que
/// aquí solo se nombra el tránsito y qué se quiere saber de él. Se compone en
/// español y con los mismos nombres que ve el usuario en pantalla, para que la
/// respuesta hable de lo que tiene delante.
String transitOracleQuestion({
  required String transit,
  required String natal,
  required String aspect,
}) {
  final transitName = planetEs[transit] ?? transit;
  final natalName = planetEs[natal] ?? natal;
  final aspectName = aspectEs[aspect] ?? aspect;

  return 'Explícame qué significa para mí este tránsito de hoy: '
      '$transitName en $aspectName con mi $natalName natal. '
      'Habla de cómo se siente en el día a día y qué conviene hacer o evitar '
      'mientras dure.';
}
