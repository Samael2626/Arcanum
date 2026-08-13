import 'package:flutter/foundation.dart';

/// Tradicion linguistica documentada de una ficha.
///
/// Solo la tradicion hebrea habilita gematria historica: el calculo 1-400
/// exige escritura hebrea atestiguada. Griego, latin, germanico y arabe se
/// muestran en su propia escritura documentada y nunca abren ese camino.
enum NameTradition {
  hebrew('Hebrea', allowsHistoricalGematria: true),
  greek('Griega', allowsHistoricalGematria: false),
  latin('Latina', allowsHistoricalGematria: false),
  germanic('Germanica', allowsHistoricalGematria: false),
  arabic('Arabe', allowsHistoricalGematria: false);

  const NameTradition(this.label, {required this.allowsHistoricalGematria});

  final String label;
  final bool allowsHistoricalGematria;
}

/// Nivel de certeza editorial separado en dos ejes independientes:
/// la forma escrita puede estar firmemente atestiguada aunque su
/// significado siga en disputa.
enum EvidenceLevel {
  attested('Atestiguada'),
  probable('Probable'),
  disputed('Discutida');

  const EvidenceLevel(this.label);
  final String label;
}

/// Fuente reutilizable compartida por todas las fichas de una tradicion.
///
/// Evita repetir url, atribucion y licencia en cada ficha y garantiza que
/// ninguna entrada pueda existir sin procedencia comprobable.
@immutable
class NameSource {
  final String id;
  final String label;
  final String url;
  final String attribution;
  final String license;

  const NameSource({
    required this.id,
    required this.label,
    required this.url,
    required this.attribution,
    required this.license,
  });
}

/// Catalogo de fuentes verificadas el 2026-08-13 contra la fuente real.
class NameSources {
  const NameSources._();

  /// Biblia Hebraica documentada con lema y morfologia abiertos.
  static const oshb = NameSource(
    id: 'oshb',
    label: 'Open Scriptures Hebrew Bible (morphhb)',
    url: 'https://github.com/openscriptures/morphhb',
    attribution:
        'Open Scriptures Hebrew Bible Project; WLC dominio publico, lema y morfologia CC BY 4.0.',
    license: 'CC BY 4.0 (lema y morfologia); WLC en dominio publico',
  );

  /// Liddell-Scott-Jones, A Greek-English Lexicon, en Perseus Digital Library.
  static const lsj = NameSource(
    id: 'lsj',
    label: 'Liddell-Scott-Jones, A Greek-English Lexicon (Perseus)',
    url: 'https://www.perseus.tufts.edu/hopper/text?doc=Perseus:text:1999.04.0057',
    attribution:
        'Henry George Liddell y Robert Scott, A Greek-English Lexicon; Perseus Digital Library, Tufts University.',
    license: 'CC BY-SA 3.0 US',
  );

  /// Lewis y Short, A Latin Dictionary (Oxford, 1879), en Perseus.
  static const lewisShort = NameSource(
    id: 'lewis-short',
    label: 'Lewis y Short, A Latin Dictionary (Perseus)',
    url: 'https://www.perseus.tufts.edu/hopper/text?doc=Perseus:text:1999.04.0059',
    attribution:
        'Charlton T. Lewis y Charles Short, A Latin Dictionary, Oxford, Clarendon Press, 1879; Perseus Digital Library, Tufts University.',
    license: 'CC BY-SA 3.0 US',
  );

  /// Forstemann, Altdeutsches Namenbuch Bd. 1: Personennamen (1900).
  static const forstemann = NameSource(
    id: 'forstemann',
    label: 'Forstemann, Altdeutsches Namenbuch Bd. 1: Personennamen (1900)',
    url: 'https://archive.org/details/bub_gb_doEFT5vbo2kC',
    attribution:
        'Ernst Wilhelm Forstemann, Altdeutsches Namenbuch, Band 1: Personennamen, 2a edicion a cargo de Hermann Jellinghaus, Bonn, 1900.',
    license: 'Dominio publico (Public Domain Mark 1.0)',
  );

  /// Lane, An Arabic-English Lexicon (1863-1893).
  static const lane = NameSource(
    id: 'lane',
    label: 'Lane, An Arabic-English Lexicon',
    url: 'https://archive.org/details/anarabicenglish01lanegoog',
    attribution:
        'Edward William Lane, An Arabic-English Lexicon, Derived from the Best and the Most Copious Eastern Sources, Londres, 1863-1893.',
    license: 'Dominio publico (fuera de copyright)',
  );

  static const all = <NameSource>[oshb, lsj, lewisShort, forstemann, lane];
}
