import 'package:flutter/foundation.dart';

import 'name_catalog.dart';
import 'name_sources.dart';

/// Estado de un apellido dentro de la cola editorial.
///
/// V1.1 no publica ningun apellido. La cola existe para acumular evidencia
/// verificable y dejar por escrito lo que todavia falta, no para adelantar
/// interpretaciones.
enum SurnameStatus {
  /// Hay evidencia parcial reutilizable, insuficiente para publicar.
  queued('En cola con evidencia parcial'),

  /// No existe fuente seria, licenciable y reutilizable todavia.
  needsEvidence('Sin evidencia suficiente'),

  /// Revisado y descartado: la evidencia disponible no es sostenible.
  rejected('Descartado');

  const SurnameStatus(this.label);
  final String label;
}

/// Entrada de la cola editorial de apellidos.
///
/// Deliberadamente carece de campos de significado y de origen publicables.
/// Un apellido no prueba linaje, etnia, sangre, nacionalidad ni destino, y
/// el tipo impide afirmarlo por construccion, no por convencion.
@immutable
class SurnameQueueEntry {
  final String id;
  final String displayName;
  final List<String> variants;
  final SurnameStatus status;

  /// Id de la ficha de nombre de pila de la que el apellido podria derivar.
  /// Es la unica evidencia que ARCANUM posee con licencia limpia; nunca
  /// autoriza a afirmar que una familia concreta descienda de ese nombre.
  final String? baseNameId;

  /// Certeza de que la forma del apellido derive de esa base.
  final EvidenceLevel derivationEvidence;

  /// Fuente ya licenciada que cubre la base, si existe.
  final NameSource? source;
  final String? citation;

  /// Que falta exactamente para poder publicar esta ficha.
  final String pendingEvidence;

  const SurnameQueueEntry({
    required this.id,
    required this.displayName,
    this.variants = const [],
    required this.status,
    this.baseNameId,
    required this.derivationEvidence,
    this.source,
    this.citation,
    required this.pendingEvidence,
  });

  /// Ninguna entrada de la cola es publicable en V1.1. Publicar exige, como
  /// minimo, evidencia atestiguada de la derivacion y una fuente licenciada
  /// que cubra el sufijo o el toponimo, cosa que todavia no existe.
  bool get isPublishable => false;

  /// Origen visible en la aplicacion. Siempre nulo mientras no se publique.
  String? get publishedOrigin => null;

  /// Significado visible en la aplicacion. Siempre nulo mientras no se publique.
  String? get publishedMeaning => null;

  /// Ficha del nombre de pila que sostiene la evidencia, si la hay.
  NameCatalogEntry? get baseName =>
      baseNameId == null ? null : NameCatalog.find(baseNameId!);
}

/// Cola editorial de apellidos priorizada por frecuencia en Colombia.
///
/// El patron patronimico en -ez esta descrito en la bibliografia, pero
/// ARCANUM todavia no dispone de una fuente reutilizable con licencia clara
/// para el sufijo. Por eso ningun apellido pasa de `queued`.
class SurnameQueue {
  const SurnameQueue._();

  static const _pendingSuffix =
      'Falta una fuente con licencia reutilizable para el sufijo patronímico -ez. La base del nombre de pila ya está verificada.';
  static const _pendingBase =
      'Falta verificar el nombre de pila de origen en una fuente con licencia reutilizable.';
  static const _pendingToponym =
      'Falta una fuente toponímica con licencia reutilizable que documente el lugar y su paso a apellido.';

  static const entries = <SurnameQueueEntry>[
    // Patronimicos cuya base ya esta verificada en el catalogo de nombres.
    SurnameQueueEntry(
      id: 'rodriguez',
      displayName: 'Rodríguez',
      variants: ['Rodrigues'],
      status: SurnameStatus.queued,
      baseNameId: 'rodrigo',
      derivationEvidence: EvidenceLevel.probable,
      source: NameSources.forstemann,
      citation: 'Forstemann, Altdeutsches Namenbuch I, raíces HROD y RIK',
      pendingEvidence: _pendingSuffix,
    ),
    SurnameQueueEntry(
      id: 'hernandez',
      displayName: 'Hernández',
      variants: ['Fernández', 'Fernandes'],
      status: SurnameStatus.queued,
      baseNameId: 'fernando',
      derivationEvidence: EvidenceLevel.probable,
      source: NameSources.forstemann,
      citation: 'Forstemann, Altdeutsches Namenbuch I, raíces FRIDU y NAND',
      pendingEvidence: _pendingSuffix,
    ),
    SurnameQueueEntry(
      id: 'perez',
      displayName: 'Pérez',
      variants: ['Peres'],
      status: SurnameStatus.queued,
      baseNameId: 'pedro',
      derivationEvidence: EvidenceLevel.probable,
      source: NameSources.lsj,
      citation: 'LSJ πέτρα',
      pendingEvidence: _pendingSuffix,
    ),
    SurnameQueueEntry(
      id: 'enriquez',
      displayName: 'Enríquez',
      variants: ['Henríquez'],
      status: SurnameStatus.queued,
      baseNameId: 'enrique',
      derivationEvidence: EvidenceLevel.probable,
      source: NameSources.forstemann,
      citation: 'Forstemann, Altdeutsches Namenbuch I, raíces HAIM y RIK',
      pendingEvidence: _pendingSuffix,
    ),
    SurnameQueueEntry(
      id: 'estevez',
      displayName: 'Estévez',
      variants: ['Esteves'],
      status: SurnameStatus.queued,
      baseNameId: 'esteban',
      derivationEvidence: EvidenceLevel.probable,
      source: NameSources.lsj,
      citation: 'LSJ στέφανος',
      pendingEvidence: _pendingSuffix,
    ),
    SurnameQueueEntry(
      id: 'alvarez',
      displayName: 'Álvarez',
      variants: ['Alvarez'],
      status: SurnameStatus.needsEvidence,
      derivationEvidence: EvidenceLevel.probable,
      pendingEvidence: _pendingBase,
    ),

    // Patronimicos cuya base todavia no esta verificada.
    SurnameQueueEntry(
      id: 'gonzalez',
      displayName: 'González',
      variants: ['Gonzales'],
      status: SurnameStatus.needsEvidence,
      derivationEvidence: EvidenceLevel.probable,
      pendingEvidence: _pendingBase,
    ),
    SurnameQueueEntry(
      id: 'martinez',
      displayName: 'Martínez',
      variants: ['Martines'],
      status: SurnameStatus.needsEvidence,
      derivationEvidence: EvidenceLevel.probable,
      pendingEvidence: _pendingBase,
    ),
    SurnameQueueEntry(
      id: 'ramirez',
      displayName: 'Ramírez',
      variants: ['Ramires'],
      status: SurnameStatus.needsEvidence,
      derivationEvidence: EvidenceLevel.probable,
      pendingEvidence: _pendingBase,
    ),
    SurnameQueueEntry(
      id: 'sanchez',
      displayName: 'Sánchez',
      variants: ['Sanches'],
      status: SurnameStatus.needsEvidence,
      derivationEvidence: EvidenceLevel.probable,
      pendingEvidence: _pendingBase,
    ),
    SurnameQueueEntry(
      id: 'gomez',
      displayName: 'Gómez',
      variants: ['Gomes'],
      status: SurnameStatus.needsEvidence,
      derivationEvidence: EvidenceLevel.probable,
      pendingEvidence: _pendingBase,
    ),
    SurnameQueueEntry(
      id: 'gutierrez',
      displayName: 'Gutiérrez',
      variants: ['Gutierres'],
      status: SurnameStatus.needsEvidence,
      derivationEvidence: EvidenceLevel.probable,
      pendingEvidence: _pendingBase,
    ),
    SurnameQueueEntry(
      id: 'jimenez',
      displayName: 'Jiménez',
      variants: ['Giménez', 'Ximénez'],
      status: SurnameStatus.needsEvidence,
      derivationEvidence: EvidenceLevel.probable,
      pendingEvidence: _pendingBase,
    ),
    SurnameQueueEntry(
      id: 'dominguez',
      displayName: 'Domínguez',
      variants: ['Domingues'],
      status: SurnameStatus.needsEvidence,
      derivationEvidence: EvidenceLevel.probable,
      pendingEvidence: _pendingBase,
    ),
    SurnameQueueEntry(
      id: 'suarez',
      displayName: 'Suárez',
      variants: ['Suarez'],
      status: SurnameStatus.needsEvidence,
      derivationEvidence: EvidenceLevel.disputed,
      pendingEvidence: _pendingBase,
    ),
    SurnameQueueEntry(
      id: 'diaz',
      displayName: 'Díaz',
      variants: ['Dias'],
      status: SurnameStatus.needsEvidence,
      derivationEvidence: EvidenceLevel.disputed,
      pendingEvidence:
          'La base Diego tiene etimología discutida; hace falta fuente con licencia que documente la disputa antes de escribir nada.',
    ),
    SurnameQueueEntry(
      id: 'lopez',
      displayName: 'López',
      variants: ['Lopes'],
      status: SurnameStatus.needsEvidence,
      derivationEvidence: EvidenceLevel.probable,
      pendingEvidence: _pendingBase,
    ),
    SurnameQueueEntry(
      id: 'velasquez',
      displayName: 'Velásquez',
      variants: ['Vásquez', 'Vazquez', 'Velázquez'],
      status: SurnameStatus.needsEvidence,
      derivationEvidence: EvidenceLevel.disputed,
      pendingEvidence: _pendingBase,
    ),

    // Toponimicos y de oficio o apodo.
    SurnameQueueEntry(
      id: 'torres',
      displayName: 'Torres',
      variants: [],
      status: SurnameStatus.needsEvidence,
      derivationEvidence: EvidenceLevel.probable,
      pendingEvidence: _pendingToponym,
    ),
    SurnameQueueEntry(
      id: 'castro',
      displayName: 'Castro',
      variants: [],
      status: SurnameStatus.needsEvidence,
      derivationEvidence: EvidenceLevel.probable,
      pendingEvidence: _pendingToponym,
    ),
    SurnameQueueEntry(
      id: 'valencia',
      displayName: 'Valencia',
      variants: [],
      status: SurnameStatus.needsEvidence,
      derivationEvidence: EvidenceLevel.probable,
      pendingEvidence: _pendingToponym,
    ),
    SurnameQueueEntry(
      id: 'restrepo',
      displayName: 'Restrepo',
      variants: [],
      status: SurnameStatus.needsEvidence,
      derivationEvidence: EvidenceLevel.disputed,
      pendingEvidence: _pendingToponym,
    ),
    SurnameQueueEntry(
      id: 'salazar',
      displayName: 'Salazar',
      variants: [],
      status: SurnameStatus.needsEvidence,
      derivationEvidence: EvidenceLevel.probable,
      pendingEvidence: _pendingToponym,
    ),
    SurnameQueueEntry(
      id: 'moreno',
      displayName: 'Moreno',
      variants: [],
      status: SurnameStatus.needsEvidence,
      derivationEvidence: EvidenceLevel.probable,
      pendingEvidence:
          'Apellido de apodo. Falta fuente licenciada; además su historia en Colombia toca la clasificación colonial por color y exige tratamiento editorial cuidadoso.',
    ),
    SurnameQueueEntry(
      id: 'rojas',
      displayName: 'Rojas',
      variants: [],
      status: SurnameStatus.needsEvidence,
      derivationEvidence: EvidenceLevel.probable,
      pendingEvidence:
          'Apellido de apodo. Falta fuente licenciada que documente el paso del adjetivo al apellido.',
    ),

    // Revisados y descartados para el catalogo editorial.
    SurnameQueueEntry(
      id: 'garcia',
      displayName: 'García',
      variants: ['Garcia'],
      status: SurnameStatus.rejected,
      derivationEvidence: EvidenceLevel.disputed,
      pendingEvidence:
          'El origen de García no está resuelto: se han propuesto etimologías vascas y prerromanas sin consenso. Ninguna fuente permite escribir una ficha honesta, y es demasiado frecuente para arriesgar una conjetura.',
    ),
    SurnameQueueEntry(
      id: 'munoz',
      displayName: 'Muñoz',
      variants: ['Munoz'],
      status: SurnameStatus.rejected,
      derivationEvidence: EvidenceLevel.disputed,
      pendingEvidence:
          'La base Munio o Nuño no tiene etimología establecida. Se descarta hasta que aparezca evidencia sostenible.',
    ),
  ];

  static SurnameQueueEntry? find(String value) {
    final key = _normalize(value);
    if (key.isEmpty) return null;
    for (final entry in entries) {
      if (_normalize(entry.displayName) == key ||
          entry.variants.any((variant) => _normalize(variant) == key)) {
        return entry;
      }
    }
    return null;
  }

  static Iterable<SurnameQueueEntry> byStatus(SurnameStatus status) =>
      entries.where((entry) => entry.status == status);

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');
}
