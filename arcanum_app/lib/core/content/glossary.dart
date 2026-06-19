/// Glosario in-app: explica cada concepto (qué es + cómo usarlo).
/// Alimenta los botones "?" (InfoDot) de toda la app.
class GlossaryEntry {
  final String title;
  final String what; // Qué es
  final String howTo; // Cómo usarlo
  const GlossaryEntry(this.title, this.what, this.howTo);
}

const Map<String, GlossaryEntry> glossary = {
  'hora_planetaria': GlossaryEntry(
    'Hora planetaria',
    'El día y la noche se dividen en 12 "horas" cada uno (desiguales), y cada una la rige un planeta '
        'siguiendo el orden caldeo. Cambian a lo largo del día.',
    'Cronometra tu trabajo a la hora del planeta afín: Venus→amor, Marte→protección/coraje, '
        'Mercurio→estudio y comercio, Júpiter→prosperidad, Sol→éxito, Luna→sueños/psiquismo, '
        'Saturno→límites y destierro.',
  ),
  'dia_regente': GlossaryEntry(
    'Regente del día',
    'Cada día de la semana también lo gobierna un planeta (lunes=Luna, martes=Marte, etc.). Es una '
        'capa de tiempo más amplia que la hora.',
    'Da el "tono" general del día. Refuerza un trabajo eligiendo el día Y la hora del mismo planeta.',
  ),
  'luna': GlossaryEntry(
    'Fase lunar',
    'La Luna crece y mengua en un ciclo de ~29 días. Su fase marca la corriente energética del momento.',
    'Creciente → atraer y construir (amor, dinero, crecimiento). Menguante → soltar y desterrar '
        '(limpieza, cortar lazos). Nueva → sembrar intención. Llena → cargar, pico de poder, adivinación.',
  ),
  'carta_natal': GlossaryEntry(
    'Carta natal',
    'El mapa del cielo en tu instante de nacimiento: dónde estaba cada planeta. Es tu "huella" '
        'astrológica y espiritual.',
    'Conoce tu planeta regente y tus fuerzas innatas para elegir patrón, diseñar talismanes y saber '
        'qué energías canalizas natural.',
  ),
  'ascendente': GlossaryEntry(
    'Ascendente y Medio Cielo',
    'El Ascendente es el signo que subía por el horizonte al nacer (tu máscara, tu cuerpo, cómo entras '
        'al mundo). El Medio Cielo es tu cima: vocación y propósito público.',
    'El Ascendente afina cómo se expresa tu carta; el Medio Cielo señala hacia dónde diriges tu obra.',
  ),
  'transitos': GlossaryEntry(
    'Tránsitos',
    'Dónde están los planetas AHORA respecto a tu carta natal. Es el "clima cósmico" que te afecta hoy.',
    'Tránsitos suaves (trígono/sextil) apoyan obras importantes; los duros (cuadratura/oposición) '
        'piden cautela. Cronometra lo grande a los apoyos.',
  ),
  'materia': GlossaryEntry(
    'Materia Arcana',
    'Catálogo de correspondencias: qué hierba, piedra, metal o incienso se asocia a cada planeta, '
        'elemento e intención.',
    'Arma los materiales de tu hechizo: filtra por intención o planeta y reúne lo afín a tu trabajo.',
  ),
  'grimorio': GlossaryEntry(
    'Grimorio cifrado',
    'Tu diario mágico privado. El contenido se cifra en tu dispositivo (AES-256): ni el servidor lo lee.',
    'Registra ritos, sueños, tiradas y resultados. Cada entrada guarda la luna y la hora del momento '
        '→ con el tiempo ves qué condiciones te funcionan.',
  ),
  'tarot': GlossaryEntry(
    'Tirada de tarot',
    'Cada posición de la tirada hace una pregunta fija; la carta que cae ahí la responde. En "Tres '
        'cartas" son Pasado · Presente · Futuro. Una carta puede salir al derecho o invertida (su sombra).',
    'Sostén una pregunta clara, lee cada carta EN su posición y luego une las tres en un solo relato. '
        'Invertida = matiz o bloqueo, no "malo".',
  ),
};
