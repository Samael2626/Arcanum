/// Las diez sefiras, para cuando el Oraculo las nombra y nadie sabe que son.
///
/// POR QUE HACE FALTA. El catalogo de tarot trae `sephirah` en cada arcano
/// menor, `tarot_learn` lo ensena como una fila ("SEFIRA: Hod") y el Oraculo
/// lo escribe dentro de la lectura ("la obra meticulosa del hod terrestre",
/// "el aire de Chokmah" -- medido el 27-sep-2026 contra el modelo real). En
/// ningun sitio se explicaba. Una palabra hebrea suelta en mitad de una
/// lectura no es profundidad: es una puerta cerrada.
///
/// No se quita del texto, se ABRE. Las sefiras son la estructura real del
/// Tarot --en los arcanos menores el NUMERO de la carta ES su sefira-- y
/// borrarlas empobreceria la lectura. Lo que faltaba era poder tocarlas.
///
/// LAS CLAVES SON LAS DEL CATALOGO DE DATOS (`Arcanum-datos/tarot/*.json`,
/// campo `sephirah`): Kether, Chokmah, Binah, Chesed, Geburah, Tiphareth,
/// Netzach, Hod, Yesod, Malkuth. Se buscan sin acentos y sin mayusculas.
///
/// Correspondencias segun la skill `arcanum-kabbalist` del proyecto (planeta,
/// mundo, principio). Y su regla numero uno: **el Arbol no es psicologia.** No
/// se traduce ninguna sefira a un arquetipo junguiano ni a una emocion; cada
/// una es una FUNCION, y asi se dice.
library;

/// Una sefira, en lo que la pantalla necesita para abrirla al tocarla.
class SephirahLore {
  /// Como se escribe en el catalogo y en la lectura.
  final String titulo;

  /// El numero en el Arbol, 1 a 10. En los arcanos menores es tambien el
  /// numero de la carta: el Ocho de Oros es Hod en Tierra.
  final int numero;

  /// El cuerpo que le corresponde. Es la via mas corta para entenderla sin
  /// saber cabala: quien ya sabe que rige Mercurio, ya sabe que hace Hod.
  final String planeta;

  /// Atziluth, Briah, Yetzirah o Assiah: a que altura opera.
  final String mundo;

  /// Que es, en una frase llana y sin hebreo.
  final String que;

  /// Que aporta cuando sale en una carta. Es lo que convierte la ficha en
  /// lectura y no en enciclopedia.
  final String enLaCarta;

  const SephirahLore({
    required this.titulo,
    required this.numero,
    required this.planeta,
    required this.mundo,
    required this.que,
    required this.enLaCarta,
  });
}

const Map<String, SephirahLore> sephirahLore = {
  'kether': SephirahLore(
    titulo: 'Kether',
    numero: 1,
    planeta: 'el Primer Motor',
    mundo: 'Atziluth · emanación',
    que:
        'La corona del Árbol: el punto donde algo empieza a ser, antes de tener '
        'forma o nombre. Es lo indiviso.',
    enLaCarta:
        'Trae el impulso puro y sin repartir: el as, la semilla, lo que todavía '
        'no se ha gastado en ninguna dirección. Mucha fuerza y ninguna forma.',
  ),
  'chokmah': SephirahLore(
    titulo: 'Chokmah',
    numero: 2,
    planeta: 'el Zodíaco',
    mundo: 'Atziluth · emanación',
    que:
        'La sabiduría como empuje, no como conocimiento: la fuerza que sale y se '
        'reparte en dos. Aquí aparece la primera división.',
    enLaCarta:
        'Trae el impulso ya en marcha y todavía sin límite. Hay dirección y hay '
        'ímpetu; lo que no hay aún es medida.',
  ),
  'binah': SephirahLore(
    titulo: 'Binah',
    numero: 3,
    planeta: 'Saturno',
    mundo: 'Atziluth · emanación',
    que:
        'El entendimiento que da forma: lo que recibe la fuerza y la contiene en '
        'un molde. Sin ella, el empuje se derrama.',
    enLaCarta:
        'Trae el límite que hace posible la obra. Acota, ordena y a veces duele, '
        'porque dar forma es renunciar a las otras formas.',
  ),
  'chesed': SephirahLore(
    titulo: 'Chesed',
    numero: 4,
    planeta: 'Júpiter',
    mundo: 'Briah · creación',
    que:
        'La misericordia entendida como abundancia: lo que crece, ampara y da de '
        'más. La estabilidad que se puede permitir ser generosa.',
    enLaCarta:
        'Trae consolidación y holgura. Lo construido se sostiene solo, y ahí '
        'empieza el riesgo de acomodarse.',
  ),
  'geburah': SephirahLore(
    titulo: 'Geburah',
    numero: 5,
    planeta: 'Marte',
    mundo: 'Briah · creación',
    que:
        'La severidad: la fuerza que corta y quita. Es el contrapeso exacto de '
        'Chesed, y el Árbol necesita las dos.',
    enLaCarta:
        'Trae conflicto, pérdida o poda. No es castigo: es lo que recorta lo que '
        'había crecido de más.',
  ),
  'tiphareth': SephirahLore(
    titulo: 'Tiphareth',
    numero: 6,
    planeta: 'el Sol',
    mundo: 'Briah · creación',
    que:
        'La belleza como equilibrio: el centro del Árbol, donde las fuerzas de '
        'arriba y de abajo se reparten sin que ninguna mande.',
    enLaCarta:
        'Trae armonía y centro. Es el punto del ciclo en que algo está logrado y '
        'todavía no ha empezado a pasarse.',
  ),
  'netzach': SephirahLore(
    titulo: 'Netzach',
    numero: 7,
    planeta: 'Venus',
    mundo: 'Yetzirah · formación',
    que:
        'La victoria entendida como deseo que persiste: lo que atrae, lo que '
        'gusta y lo que no se rinde.',
    enLaCarta:
        'Trae deseo y también desgaste. Empuja hacia lo que se quiere, y ahí se '
        've si la voluntad aguanta más que el gusto.',
  ),
  'hod': SephirahLore(
    titulo: 'Hod',
    numero: 8,
    planeta: 'Mercurio',
    mundo: 'Yetzirah · formación',
    que:
        'El esplendor del oficio: la inteligencia que mide, nombra y repite '
        'hasta que sale bien. Es la sefira del taller.',
    enLaCarta:
        'Trae el trabajo hecho con método. La pieza repetida mil veces, el '
        'cálculo, la palabra exacta — y el riesgo de no salir nunca del detalle.',
  ),
  'yesod': SephirahLore(
    titulo: 'Yesod',
    numero: 9,
    planeta: 'la Luna',
    mundo: 'Yetzirah · formación',
    que:
        'El fundamento: la capa donde todo lo de arriba se junta antes de tocar '
        'el mundo. Es lo que sostiene sin verse.',
    enLaCarta:
        'Trae lo que ya está casi, y lo que se mueve por debajo: el hábito, el '
        'sueño, la imagen que uno se hace de las cosas.',
  ),
  'malkuth': SephirahLore(
    titulo: 'Malkuth',
    numero: 10,
    planeta: 'la Tierra',
    mundo: 'Assiah · acción',
    que:
        'El reino: donde el Árbol toca el suelo y la cosa por fin existe, con su '
        'peso y sus consecuencias.',
    enLaCarta:
        'Trae el resultado, entero y ya inevitable. Lo que se ve, lo que se '
        'cobra, lo que hay que habitar — un ciclo que se cierra.',
  ),
};

/// La ficha de una sefira, o `null` si el nombre no está cubierto.
///
/// Acepta el nombre como venga del catálogo o de la lectura: con mayúscula,
/// con acento o suelto en mitad de una frase. Devuelve `null` en vez de una
/// ficha de relleno para que quien pinta el término pueda NO subrayarlo.
SephirahLore? sephirahLoreOf(String? nombre) {
  if (nombre == null) return null;
  return sephirahLore[_clave(nombre)];
}

String _clave(String s) {
  const con = 'áéíóúüÁÉÍÓÚÜ';
  const sin = 'aeiouuAEIOUU';
  final b = StringBuffer();
  for (final c in s.trim().toLowerCase().split('')) {
    final i = con.indexOf(c);
    b.write(i < 0 ? c : sin[i]);
  }
  return b.toString();
}
