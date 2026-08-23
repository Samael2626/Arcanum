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

  // ── Aspectos ───────────────────────────────────────────────────────────────
  'aspecto': GlossaryEntry(
    'Aspecto',
    'El ángulo que forman dos planetas entre sí visto desde la Tierra. Ese ángulo dice cómo se '
        'relacionan sus fuerzas: si colaboran, se ignoran o chocan.',
    'No leas los planetas sueltos: léelos EN relación. Un mismo planeta se comporta distinto según '
        'con quién esté aspectado. Los suaves (sextil, trígono) abren puertas; los duros (cuadratura, '
        'oposición) piden trabajo.',
  ),
  'conjuncion': GlossaryEntry(
    'Conjunción (0°)',
    'Dos planetas en el mismo punto del cielo. Sus naturalezas se funden en una sola fuerza: ya no '
        'actúan por separado.',
    'Es el aspecto más potente y el más ambiguo — amplifica lo que toca, para bien o para mal. Mira '
        'qué planetas son: Venus con Júpiter bendice; Marte con Saturno aprieta. Buen momento para '
        'iniciar algo de la naturaleza de ambos.',
  ),
  'sextil': GlossaryEntry(
    'Sextil (60°)',
    'Aspecto suave entre planetas de elementos compatibles. Es una puerta abierta: la oportunidad '
        'está ahí, pero no entra sola.',
    'Favorece si actúas. A diferencia del trígono, el sextil pide que des el primer paso — es apoyo '
        'que responde al esfuerzo. Ideal para pedir, proponer, estudiar y tender puentes.',
  ),
  'cuadratura': GlossaryEntry(
    'Cuadratura (90°)',
    'Aspecto de tensión: dos planetas tiran en direcciones que no se entienden. Es fricción, y la '
        'fricción es incómoda pero produce fuego.',
    'No es una maldición: es el músculo del carácter. Evita cronometrar aquí lo delicado (firmas, '
        'reconciliaciones, ritos de atracción). Úsalo para romper inercia, cortar y empujar lo que '
        'estaba trabado.',
  ),
  'trigono': GlossaryEntry(
    'Trígono (120°)',
    'Aspecto armónico entre planetas del mismo elemento. Todo fluye sin resistencia: el talento sale '
        'solo, sin esfuerzo.',
    'La mejor ventana para lo importante: talismanes, consagraciones, obras que quieres que prosperen. '
        'Su trampa es la pereza — como no cuesta, es fácil no usarlo.',
  ),
  'oposicion': GlossaryEntry(
    'Oposición (180°)',
    'Dos planetas enfrentados, cara a cara desde extremos del cielo. Es el aspecto de la conciencia: '
        'ves el conflicto porque está fuera de ti, casi siempre en otra persona.',
    'Pide equilibrio, no victoria de un lado. Buen momento para negociar, para ver un espejo y para '
        'la adivinación; mal momento para decidir en caliente o para atar voluntades.',
  ),

  // ── Lectura de la carta ────────────────────────────────────────────────────
  // "Capitulo" y "sigilo" NO son palabras de la tradicion: las pusimos
  // nosotros. `transit_weight.select()` llama `chapter` al transito lento y la
  // figura la dibuja `figura_aspecto.dart`. Si inventamos el vocabulario,
  // tenemos que definirlo — nadie puede buscarlo en otro sitio.
  'capitulo': GlossaryEntry(
    'El capítulo',
    'El tránsito LENTO más fuerte sobre tu carta. Lo traen Júpiter, Saturno o el Nodo, que se mueven '
        'tan despacio que su asunto dura semanas o meses: Saturno tarda 23 días en recorrer un grado, '
        'y la Luna dos horas.\n\n'
        'En el sello va por fuera y punteado, envolviendo al del día.',
    'No es la noticia de hoy: ya estaba ayer y seguirá mañana. Se lee como el fondo sobre el que cae '
        'la jornada, no como algo que llega. Si el capítulo cambia, es que ha cambiado algo largo — y '
        'eso pasa pocas veces al año.',
  ),
  'sigilo': GlossaryEntry(
    'El sigilo',
    'La figura que forman dos cuerpos sobre la rueda. No es un dibujo del aspecto: ES el aspecto. El '
        'ángulo decide la forma —120° caben tres veces en la vuelta y sale un triángulo, 90° cuatro y '
        'sale un cuadrado, 60° seis y sale un hexágono— así que nadie la dibuja: se deduce.\n\n'
        'La conjunción no tiene figura: son dos cuerpos en el mismo punto.',
    'Míralo torcido y sabrás que el aspecto aún no es exacto; cuanto más regular, más cerca está de '
        'perfeccionar. Cambia solo cada día porque el cielo se mueve.',
  ),
  'sello': GlossaryEntry(
    'El sello del cielo',
    'La lectura de tu día: los dos tránsitos que más pesan sobre tu carta, dibujados y luego '
        'interpretados. Se abre una vez al día y queda abierto hasta tu medianoche.',
    'El dibujo, los grados y la lectura llana son cálculo y no cuestan nada: están siempre, incluso '
        'sin conexión. Lo que se pide al abrirlo es la interpretación.',
  ),
  'orbe': GlossaryEntry(
    'Orbe',
    'Un aspecto casi nunca es exacto. El orbe son los grados que le faltan (o le sobran) para serlo: '
        'un trígono de 118,6° tiene 1,4° de orbe. Dentro de ese margen el aspecto cuenta; fuera, no '
        'existe.\n\n'
        'Por eso las figuras del sello salen torcidas: los dos cuerpos se dibujan donde están de '
        'verdad, no donde el aspecto sería perfecto.',
    'Cuanto más cerrado el orbe, más apretado el símbolo — y más fácil situar el día en que '
        'perfecciona. Un orbe ancho es un asunto que aún no ha llegado del todo. ARCANUM usa 3° para '
        'conjunción, cuadratura, trígono y oposición, y 2° para el sextil; cada escuela usa los '
        'suyos, y algunas los miden por planeta en vez de por aspecto.',
  ),
  'aplicativo': GlossaryEntry(
    'Aplicativo y separativo',
    'Un aspecto APLICATIVO todavía se está formando: el planeta se acerca a la exactitud. Uno '
        'SEPARATIVO ya pasó por ella y se aleja.\n\n'
        'La misma figura y el mismo orbe significan cosas distintas según la dirección: uno es algo '
        'que llega, el otro algo que se va.',
    'Lo aplicativo se lee como asunto entrando, y tiene fecha: se puede decir cuándo cierra. Lo '
        'separativo se lee como algo que se suelta, y esa fecha ya pasó. Ojo con los retrógrados: al '
        'moverse hacia atrás invierten la dirección, y un aspecto que parecía irse vuelve.',
  ),
  'natal_vs_transito': GlossaryEntry(
    'Natal vs. tránsito',
    'Tu carta NATAL es fija: el cielo del instante en que naciste, y no cambia jamás. Un TRÁNSITO es '
        'dónde está ese mismo planeta AHORA en el cielo real.\n\n'
        'Por eso una línea como "Venus trígono Luna natal" se lee: la Venus de hoy está en trígono con '
        'la Luna que tenías al nacer.',
    'Tu carta natal es el instrumento; los tránsitos son la mano que lo toca. Lee siempre en ese '
        'orden: primero qué eres, luego qué te está pasando encima.',
  ),
  'retrogrado': GlossaryEntry(
    'Retrógrado ℞',
    'Desde la Tierra, un planeta parece retroceder en el cielo durante unas semanas. Es un efecto de '
        'perspectiva, no un cambio real de dirección — pero la tradición lo lee como una fuerza que '
        'mira hacia adentro.',
    'Su energía se vuelve introspectiva: revisar, corregir, terminar lo empezado, reencontrar. Mala '
        'ventana para lanzar y firmar de esa naturaleza; excelente para RE-hacer. En tu carta natal, '
        'un planeta retrógrado indica una fuerza que trabajas por dentro antes de expresarla.',
  ),
  'elemento': GlossaryEntry(
    'Elemento',
    'Fuego, Tierra, Aire y Agua: las cuatro naturalezas básicas. Cada signo pertenece a una, y de ahí '
        'salen casi todas las correspondencias mágicas.',
    'Fuego → voluntad y acción. Tierra → cuerpo, dinero, materia. Aire → mente, palabra, vínculo. '
        'Agua → emoción, sueño, psiquismo. Elige materiales e intención afines al elemento del trabajo.',
  ),
  'polaridad': GlossaryEntry(
    'Polaridad',
    'Cada signo es activo (Fuego y Aire) o receptivo (Tierra y Agua). No es "masculino/femenino" ni '
        'bueno/malo: es la dirección en que la fuerza se mueve.',
    'Activa → proyectar hacia fuera, iniciar, emitir. Receptiva → contener, atraer, gestar. Ajusta el '
        'gesto del rito a la polaridad: no se invoca igual de lo que se acoge.',
  ),
  'regente': GlossaryEntry(
    'Regente',
    'El planeta que gobierna un signo o una casa y le presta su naturaleza. Marte rige Aries; Venus, '
        'Tauro y Libra; la Luna, Cáncer, y así.',
    'Para reforzar un asunto, trabaja en el día y la hora de su regente, con sus metales, hierbas e '
        'inciensos. Es el hilo que conecta tu carta con la Materia Arcana.',
  ),

  // ── Casas ──────────────────────────────────────────────────────────────────
  'casa': GlossaryEntry(
    'Las doce casas',
    'La rueda natal se divide en doce sectores llamados casas. Si el signo dice CÓMO actúa un planeta, '
        'la casa dice DÓNDE: en qué terreno concreto de tu vida se nota.\n\n'
        'Se cuentan desde el Ascendente y dependen de la hora y el lugar exactos de tu nacimiento.',
    'Localiza el asunto que te importa (dinero → casa 2, pareja → casa 7, trabajo → casa 10) y mira '
        'qué planetas caen ahí: son las fuerzas que gobiernan ese terreno en tu vida.',
  ),
  'casa_1': GlossaryEntry(
    'Casa 1 · el Yo',
    'La casa del Ascendente: tu cuerpo, tu aspecto, tu manera de entrar en cualquier sala. Cómo te ve '
        'el mundo antes de que hables.',
    'Trabajos de presencia, carisma, salud del cuerpo y comienzos personales. Planetas aquí se notan '
        'en el temperamento a simple vista.',
  ),
  'casa_2': GlossaryEntry(
    'Casa 2 · lo que sostiene',
    'Tus recursos: dinero ganado, bienes, cuerpo como herramienta, y también lo que valoras y te da '
        'seguridad.',
    'Prosperidad, estabilidad material, autoestima. Es la casa de los talismanes de abundancia y de '
        'todo lo que quieras que dure.',
  ),
  'casa_3': GlossaryEntry(
    'Casa 3 · la palabra',
    'Mente cotidiana, habla, escritura, aprendizaje corto, hermanos, vecinos y trayectos breves.',
    'Estudio, elocuencia, pactos y comunicación. Casa mercurial por excelencia: aquí van los sigilos '
        'de palabra y de mensaje.',
  ),
  'casa_4': GlossaryEntry(
    'Casa 4 · la raíz',
    'Hogar, familia de origen, ancestros, la tierra bajo tus pies y el final de las cosas.',
    'Protección del hogar, trabajo ancestral, echar raíces. Todo rito de asentamiento y de linaje '
        'pertenece aquí.',
  ),
  'casa_5': GlossaryEntry(
    'Casa 5 · la creación',
    'Lo que sale de ti por gusto: arte, juego, romance, hijos, riesgo y placer.',
    'Creatividad, atracción amorosa, fertilidad y suerte. Casa solar: se trabaja para brillar y para '
        'gozar, no para durar.',
  ),
  'casa_6': GlossaryEntry(
    'Casa 6 · el oficio',
    'Trabajo diario, rutinas, salud, servicio y disciplina. Lo que haces todos los días aunque no te '
        'apetezca.',
    'Salud, hábitos, limpieza y el trabajo como práctica. Aquí van los ritos de mantenimiento — los '
        'que sostienen todo lo demás.',
  ),
  'casa_7': GlossaryEntry(
    'Casa 7 · el otro',
    'Pareja, socios, contratos y también enemigos declarados. Todo vínculo cara a cara.',
    'Amor comprometido, alianzas, acuerdos y reconciliación. Es la casa opuesta a la 1: aquí se '
        'trabaja el espejo, no el yo.',
  ),
  'casa_8': GlossaryEntry(
    'Casa 8 · lo profundo',
    'Muerte y renacimiento, sexo, crisis, herencias, deudas y recursos de otros. Lo que se transforma '
        'sin permiso.',
    'Necromancia, trabajo de sombra, transformación profunda y corte de lazos. Casa de umbral: pide '
        'protección y limpieza antes y después.',
  ),
  'casa_9': GlossaryEntry(
    'Casa 9 · la búsqueda',
    'Filosofía, religión, estudios superiores, viajes largos y visión de largo alcance.',
    'Iniciación, adivinación, peregrinación y estudio profundo. La casa natural del practicante que '
        'busca la doctrina, no solo el efecto.',
  ),
  'casa_10': GlossaryEntry(
    'Casa 10 · la cima',
    'La casa del Medio Cielo: vocación, reputación, autoridad y tu obra pública.',
    'Éxito visible, reconocimiento, ascenso. Trabajos solares y jupiterianos de carrera y de nombre.',
  ),
  'casa_11': GlossaryEntry(
    'Casa 11 · la red',
    'Amistades, comunidad, aliados, causas colectivas y esperanzas a futuro.',
    'Favores, apoyo de grupo, encontrar a los tuyos. Casa buena para trabajos que necesitan más manos '
        'que la tuya.',
  ),
  'casa_12': GlossaryEntry(
    'Casa 12 · lo oculto',
    'Lo invisible: inconsciente, sueños, encierro, enemigos secretos, retiro y disolución.',
    'Trabajo onírico, retiro, destierro de lo que te mina sin que lo veas. También la casa de lo que '
        'te sabotea: mírala antes de culpar a fuera.',
  ),
};

/// Clave de glosario para una casa (1-12). Cae al genérico si el número no es válido.
String houseGlossaryKey(int house) =>
    (house >= 1 && house <= 12) ? 'casa_$house' : 'casa';

/// Clave de glosario para un aspecto, desde la clave inglesa del backend
/// ('sextile', 'trine'…). Cae al genérico si llega uno desconocido.
String aspectGlossaryKey(String aspect) =>
    const {
      'conjunction': 'conjuncion',
      'sextile': 'sextil',
      'square': 'cuadratura',
      'trine': 'trigono',
      'opposition': 'oposicion',
    }[aspect.toLowerCase()] ??
    'aspecto';
