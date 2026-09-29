/// Las cuatro figuras de la corte, que la app nombraba sin explicar nunca.
///
/// POR QUE. Barrido el catalogo y las lecturas reales del 27-sep-2026,
/// "caballero" sale 7 veces y no habia explicacion en NINGUNA parte de la app:
/// solo un mapa de nombres en `tarot_card.dart` para pintar el rotulo. Es el
/// unico hueco de contenido de verdad que encontro el barrido; todo lo demas
/// estaba escrito y solo hacia falta poder llegar a el.
///
/// EL CATALOGO MEZCLA DOS SISTEMAS, y conviene saberlo antes de tocar esto.
/// Los slugs son Rider-Waite --`sota-de-copas`, `rey-de-bastos`-- y los
/// titulos son Golden Dawn: "Princess of the Waters", "Prince of the Chariot
/// of Fire". Es decir, lo que la app llama REY es el PRINCIPE del Carro de la
/// Golden Dawn, no el Rey de Waite. Las fichas se escriben por la FUNCION, que
/// es la que comparten los dos sistemas, y usan el nombre en espanol que la
/// app ensena. Si algun dia se unifica la nomenclatura, esto no cambia.
///
/// Las cortes NO tienen sefira --`sephirah` viene null en las dieciseis--
/// porque no son estaciones del Arbol: son las cuatro letras del Nombre
/// aplicadas a cada palo. Por eso su ficha habla de elemento y no de numero.
library;

/// Una figura de la corte, en lo que la pantalla necesita para abrirla.
class CourtLore {
  /// Como la nombra la app, en espanol.
  final String titulo;

  /// Su elemento propio, el que monta sobre el del palo.
  final String elemento;

  /// Que es, en una frase llana.
  final String que;

  /// Que aporta cuando sale en una tirada.
  final String enLaTirada;

  const CourtLore({
    required this.titulo,
    required this.elemento,
    required this.que,
    required this.enLaTirada,
  });
}

const Map<String, CourtLore> courtLore = {
  'sota': CourtLore(
    titulo: 'Sota',
    elemento: 'Tierra',
    que:
        'La figura más joven del palo: el asunto recién llegado, todavía sin '
        'forma hecha. Es donde algo toca el suelo por primera vez.',
    enLaTirada:
        'Trae una noticia, un comienzo o algo por aprender. Poca fuerza y mucha '
        'apertura: aún se puede decidir de qué va.',
  ),
  'caballero': CourtLore(
    titulo: 'Caballero',
    elemento: 'Fuego',
    que:
        'La fuerza que llega de golpe y no se queda. Entra en el asunto, lo '
        'mueve y sigue: es el único de la corte que está de paso.',
    enLaTirada:
        'Trae prisa y movimiento — algo que entra o algo que se va. Empuja el '
        'asunto, y también lo puede quemar si nadie lo sostiene.',
  ),
  'reina': CourtLore(
    titulo: 'Reina',
    elemento: 'Agua',
    que:
        'El dominio maduro del palo, ejercido hacia dentro. Sostiene y conserva '
        'sin tener que demostrar nada.',
    enLaTirada:
        'Trae hondura y aguante: quien ya sabe de esto y no necesita probarlo. '
        'Si la tienes en contra, no choca — espera.',
  ),
  'rey': CourtLore(
    titulo: 'Rey',
    elemento: 'Aire',
    que:
        'El dominio del palo ejercido hacia fuera: el que decide, ordena y '
        'responde de lo decidido.',
    enLaTirada:
        'Trae autoridad y una decisión tomada. El asunto sale de la duda y pasa '
        'a la acción, con alguien firmando por ello.',
  ),
};

/// Lo que una figura NO es, y hace falta decirlo una vez.
///
/// Es la pregunta que todo el mundo hace ante una corte, y la respuesta vale
/// para las cuatro: puede ser una persona, una parte de ti, o simplemente una
/// manera de estar llevando el asunto. La lectura dice cuál por el contexto,
/// no la carta por sí sola.
const String courtAviso =
    'Una figura puede ser una persona de tu entorno, una parte de ti, o '
    'simplemente la manera en que estás llevando el asunto. La carta no elige '
    'cuál de las tres: eso lo dice el resto de la tirada.';

/// Y lo que la hace concreta: su elemento monta sobre el del palo.
///
/// El Caballero de Copas es Fuego de Agua — prisa dentro de lo emocional —, y
/// la Reina de Espadas es Agua de Aire — hondura dentro de lo que se piensa.
const String courtElementoDoble =
    'Su elemento se monta sobre el del palo: el Caballero de Copas es Fuego de '
    'Agua, prisa dentro de lo que se siente. Ahí está lo que la distingue de '
    'las otras tres del mismo palo.';

/// La ficha de una figura, o `null` si el nombre no está cubierto.
CourtLore? courtLoreOf(String? nombre) {
  if (nombre == null) return null;
  return courtLore[_clave(nombre)];
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
