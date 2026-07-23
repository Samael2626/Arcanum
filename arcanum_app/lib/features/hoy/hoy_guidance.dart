/// El motor de "salto contextual inteligente" de Hoy.
///
/// Dado el cielo real (regente del día, hora planetaria, luna) decide UNA
/// acción concreta y hacible ahora — el "Tu siguiente paso" — y provee las
/// correspondencias que cada panel usa para saltar a otra sección. Es Dart
/// puro y determinista: la misma entrada da el mismo paso, para poder testearlo
/// y para que no cambie a mitad de sesión sin motivo.
///
/// No inventa destinos: solo apunta a lo que la app ya tiene. Tarot no tiene
/// visor de carta individual, así que su salto va a la pestaña del oráculo.
library;

/// Slug de la obra de Culpeper en las Lecturas (lo fija el seed).
const culpeperWorkSlug = 'culpeper-complete-herbal';

/// Los siete regentes clásicos: los únicos que rigen horas y días planetarios,
/// y por tanto los únicos que pueden conducir "Tu siguiente paso".
const classicalPlanets = {
  'sun',
  'moon',
  'mercury',
  'venus',
  'mars',
  'jupiter',
  'saturn',
};

/// Planeta → Arcano Mayor que rige (atribución Golden Dawn). Para el salto al
/// oráculo con el naipe del día. Slugs reales del catálogo (en español).
const planetTarot = {
  'sun': 'el-sol',
  'moon': 'la-sacerdotisa',
  'mercury': 'el-mago',
  'venus': 'la-emperatriz',
  'mars': 'la-torre',
  'jupiter': 'la-rueda',
  'saturn': 'el-mundo',
};

/// Nombre en español del Arcano de cada planeta, para el copy.
const planetTarotEs = {
  'sun': 'El Sol',
  'moon': 'La Sacerdotisa',
  'mercury': 'El Mago',
  'venus': 'La Emperatriz',
  'mars': 'La Torre',
  'jupiter': 'La Rueda',
  'saturn': 'El Mundo',
};

/// Planeta → capítulo de Culpeper de una hierba que ESE planeta rige según el
/// propio Culpeper (no según Materia): así el salto al libro no cae en una
/// discrepancia. Curado de los 20 enlaces del puente; solo los planetas con una
/// hierba de regencia coincidente en Culpeper aparecen aquí. La Luna no tiene
/// hierba lunar limpia en Culpeper, así que se omite y cae al salto de plantas.
const planetCulpeperChapter = {
  'sun': 'rosemary',
  'mercury': 'lavender',
  'venus': 'vervain',
  'mars': 'wormwood',
  'jupiter': 'sage',
  'saturn': 'henbane',
};

/// Lo que la energía de cada planeta invita a ANOTAR en el grimorio. Frase
/// corta y accionable, no la lista larga de `planetFavors`.
const planetGrimoireSeed = {
  'sun': 'una meta que quieras hacer brillar',
  'moon': 'un sueño o una emoción de hoy',
  'mercury': 'una idea, un mensaje o algo que estudiar',
  'venus': 'una intención de amor, arte o reconciliación',
  'mars': 'algo que defender o el coraje que necesitas',
  'jupiter': 'aquello que quieres que crezca',
  'saturn': 'un límite que poner o algo que soltar',
};

/// Nombre en español del planeta (duplicado mínimo para no acoplar este módulo
/// puro a `astro_symbols`, que trae glifos de Flutter).
const _planetEs = {
  'sun': 'Sol',
  'moon': 'Luna',
  'mercury': 'Mercurio',
  'venus': 'Venus',
  'mars': 'Marte',
  'jupiter': 'Júpiter',
  'saturn': 'Saturno',
};

/// A dónde lleva un paso. Cada valor mapea a una navegación real y existente.
enum NextStepKind {
  /// Plantas de Materia Arcana filtradas por el planeta.
  materia,

  /// Un capítulo concreto de Culpeper (una hierba del planeta).
  culpeper,

  /// El editor del grimorio, con una semilla de intención.
  grimoire,

  /// La pestaña del oráculo (tarot no tiene visor de carta suelta).
  tarot,

  /// Cielos, enfocando el planeta en la carta natal ("tu Marte natal").
  cielos,
}

/// El "siguiente paso" ya resuelto en texto + destino. La pantalla solo lo pinta
/// y, al tocar, ejecuta la navegación según [kind]/[planet]/[slug].
class NextStep {
  /// Línea pequeña de contexto, p.ej. "AHORA · Hora de Mercurio".
  final String eyebrow;

  /// La invitación concreta, p.ej. "Estudia una planta de Mercurio".
  final String title;

  /// El texto del botón, p.ej. "Ver plantas mercuriales".
  final String actionLabel;

  final NextStepKind kind;

  /// Planeta que conduce el paso (siempre uno de los siete clásicos).
  final String planet;

  /// Destino fino cuando aplica: slug de capítulo (culpeper) o de carta (tarot).
  final String? slug;

  const NextStep({
    required this.eyebrow,
    required this.title,
    required this.actionLabel,
    required this.kind,
    required this.planet,
    this.slug,
  });
}

/// El orden en que rotan los tipos de paso a lo largo del día. Rotar por número
/// de hora da variedad (no siempre "ver plantas") sin dejar de ser determinista.
const _kindRotation = [
  NextStepKind.materia,
  NextStepKind.grimoire,
  NextStepKind.culpeper,
  NextStepKind.tarot,
];

/// Decide el siguiente paso desde la hora planetaria vigente.
///
/// La hora manda (cambia cada ~60 min: mantiene Hoy vivo). El tipo de acción
/// rota con [hourNumber] para variar. Si toca "culpeper" pero el planeta no
/// tiene capítulo limpio, cae a "materia" en vez de mandar a un libro que
/// contradiría la regencia. Devuelve null si el planeta no es de los clásicos
/// (no debería pasar: las horas solo las rigen los siete), y la pantalla
/// entonces simplemente no muestra la tarjeta.
NextStep? nextStepFor({
  required String hourPlanet,
  required int hourNumber,
}) {
  if (!classicalPlanets.contains(hourPlanet)) return null;
  final es = _planetEs[hourPlanet] ?? hourPlanet;
  final eyebrow = 'AHORA · Hora de $es';

  var kind = _kindRotation[hourNumber % _kindRotation.length];
  if (kind == NextStepKind.culpeper &&
      !planetCulpeperChapter.containsKey(hourPlanet)) {
    kind = NextStepKind.materia;
  }

  switch (kind) {
    case NextStepKind.materia:
      return NextStep(
        eyebrow: eyebrow,
        title: 'Explora una planta de $es',
        actionLabel: 'Ver plantas de $es',
        kind: kind,
        planet: hourPlanet,
      );
    case NextStepKind.culpeper:
      return NextStep(
        eyebrow: eyebrow,
        title: 'Lee lo que Culpeper dijo de una hierba de $es',
        actionLabel: 'Abrir el capítulo',
        kind: kind,
        planet: hourPlanet,
        slug: planetCulpeperChapter[hourPlanet],
      );
    case NextStepKind.grimoire:
      final seed = planetGrimoireSeed[hourPlanet] ?? 'una intención';
      return NextStep(
        eyebrow: eyebrow,
        title: 'Anota $seed',
        actionLabel: 'Escribir en el grimorio',
        kind: kind,
        planet: hourPlanet,
      );
    case NextStepKind.tarot:
      final card = planetTarotEs[hourPlanet] ?? 'su arcano';
      return NextStep(
        eyebrow: eyebrow,
        title: 'La carta de $es es $card',
        actionLabel: 'Ir al oráculo',
        kind: kind,
        planet: hourPlanet,
        slug: planetTarot[hourPlanet],
      );
    case NextStepKind.cielos:
      // Hoy no lo produce por rotación; existe como destino de los saltos de
      // panel ("tu Marte natal") y queda listo por si entra a la rotación.
      return NextStep(
        eyebrow: eyebrow,
        title: 'Mira tu $es en tu carta natal',
        actionLabel: 'Ver tu $es natal',
        kind: kind,
        planet: hourPlanet,
      );
  }
}
