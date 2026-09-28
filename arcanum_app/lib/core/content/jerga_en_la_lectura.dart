/// Encuentra en una lectura los terminos que hay que subrayar y abrir.
///
/// EL PROBLEMA, medido el 27-sep-2026 contra el modelo real. Aunque el prompt
/// prohiba escribir la geometria y el contexto ya no entregue el volcado, en
/// las lecturas siguen apareciendo palabras que nadie entiende: "el aire de
/// Chokmah", "la obra del hod terrestre", "primera decanato". No vienen del
/// modelo inventando: vienen del SIGNIFICADO de cada carta, que las trae
/// escritas en el catalogo.
///
/// LA DECISION ES NO PELEARLAS. Tres variantes del prompt no las quitaron, y
/// quitarlas del catalogo empobreceria las cartas: la sefira es la estructura
/// real del arcano menor. Asi que en vez de esconderlas, se subrayan y se
/// abren. Es lo mismo que ya hace la pantalla de Cielos con los terminos del
/// sello, y lo que ARCANUM dice ser: un instrumento que ensena usandolo.
///
/// LO QUE NO SE SUBRAYA. Solo entra lo que tiene ficha. Un subrayado dorado
/// que al tocarlo no da nada es peor que no subrayar, asi que aqui no hay
/// lista de "palabras raras": hay una busqueda contra el contenido que existe
/// --`sephirahLore` y `glossary`--, y lo que no esta, no se marca.
library;

import 'glossary.dart';
import 'sephirah_lore.dart';

/// Un termino localizado dentro del texto, listo para pintar.
class TerminoJerga {
  /// Donde empieza y acaba en el texto ORIGINAL, para partirlo sin tocarlo.
  final int inicio;
  final int fin;

  /// El texto tal cual aparece, con sus mayusculas y acentos.
  final String textoVisible;

  /// Que abrir al tocarlo: una sefira o una entrada del glosario.
  final SephirahLore? sefira;
  final GlossaryEntry? glosario;

  const TerminoJerga({
    required this.inicio,
    required this.fin,
    required this.textoVisible,
    this.sefira,
    this.glosario,
  });

  String get titulo => sefira?.titulo ?? glosario?.title ?? textoVisible;
}

/// Las palabras del glosario que aparecen en LECTURAS, con su clave.
///
/// No es todo el glosario a proposito: "casa 7" o "profeccion" no salen en una
/// lectura de tarot, y buscarlas seria gastar pasadas por nada. Si una empieza
/// a salir, se anade aqui y ya tiene ficha.
const Map<String, String> _terminosDeGlosario = {
  'decanato': 'decanato',
  'decanatos': 'decanato',
  'séfira': 'sephirah',
  'sefira': 'sephirah',
  'sephirah': 'sephirah',
  'retrógrado': 'retrogrado',
  'retrogrado': 'retrogrado',
  'dignidad': 'dignidad',
  'hora planetaria': 'hora_planetaria',
};

/// Localiza en [texto] los terminos que tienen ficha, en orden de aparicion.
///
/// Se buscan por PALABRA COMPLETA: sin eso, "hod" casaba dentro de "método" y
/// la lectura salia con medio verbo subrayado.
List<TerminoJerga> jergaEnLaLectura(String texto) {
  final hallazgos = <TerminoJerga>[];
  final plano = _plano(texto);

  void buscar(String aguja, {SephirahLore? sefira, GlossaryEntry? glosario}) {
    final needle = _plano(aguja);
    var desde = 0;
    while (true) {
      final i = plano.indexOf(needle, desde);
      if (i < 0) break;
      desde = i + needle.length;
      if (!_esPalabraEntera(plano, i, needle.length)) continue;
      hallazgos.add(TerminoJerga(
        inicio: i,
        fin: i + needle.length,
        textoVisible: texto.substring(i, i + needle.length),
        sefira: sefira,
        glosario: glosario,
      ));
    }
  }

  for (final s in sephirahLore.values) {
    buscar(s.titulo, sefira: s);
  }
  _terminosDeGlosario.forEach((palabra, clave) {
    final entrada = glossary[clave];
    if (entrada != null) buscar(palabra, glosario: entrada);
  });

  hallazgos.sort((a, b) => a.inicio.compareTo(b.inicio));

  // Sin solapes: "séfira" dentro de otra coincidencia partiria el texto.
  final limpio = <TerminoJerga>[];
  var ultimoFin = -1;
  for (final h in hallazgos) {
    if (h.inicio < ultimoFin) continue;
    limpio.add(h);
    ultimoFin = h.fin;
  }
  return limpio;
}

/// `_plano` conserva la LONGITUD del original, carácter a carácter: los
/// índices que devuelve la búsqueda tienen que valer sobre el texto de verdad.
/// Por eso se mapea letra a letra y nunca se quita ni se anade nada.
String _plano(String s) {
  const con = 'áéíóúüñÁÉÍÓÚÜÑ';
  const sin = 'aeiouunAEIOUUN';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = con.indexOf(c);
    b.write(i < 0 ? c : sin[i]);
  }
  return b.toString();
}

bool _esPalabraEntera(String texto, int inicio, int largo) {
  bool letra(int i) =>
      i >= 0 && i < texto.length && RegExp(r'[a-z0-9]').hasMatch(texto[i]);
  return !letra(inicio - 1) && !letra(inicio + largo);
}
