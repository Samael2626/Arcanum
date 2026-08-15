import 'package:flutter/foundation.dart';

import 'threshold_bridge.dart';

enum NamePartType {
  givenName('Nombre'),
  surname('Apellido');

  const NamePartType(this.label);
  final String label;
}

enum ReadingDialect {
  latinAmerica('Español Colombia / LatAm'),
  peninsular('Español peninsular'),
  portuguese('Portugués — próximamente'),
  basqueManual('Vasco — entrada manual');

  const ReadingDialect(this.label);
  final String label;
}

enum HebrewFormOrigin {
  historicalDocumented('Gematría histórica documentada'),
  userProvided('Forma aportada por ti'),
  arcanumContemplative('Transliteración contemplativa ARCANUM');

  const HebrewFormOrigin(this.label);
  final String label;
}

@immutable
class GematriaLetter {
  final String glyph;
  final int value;

  const GematriaLetter(this.glyph, this.value);

  Map<String, Object> toJson() => {'glyph': glyph, 'value': value};

  factory GematriaLetter.fromJson(Map<String, dynamic> json) =>
      GematriaLetter(json['glyph'] as String, json['value'] as int);
}

@immutable
class ConfirmedHebrewForm {
  final String resultId;
  final String pointedHebrew;
  final String baseHebrew;
  final String pronunciation;
  final HebrewFormOrigin origin;
  final String ruleVersion;
  final String gematriaVersion;
  final List<GematriaLetter> letters;
  final int value;
  final DateTime confirmedAt;

  const ConfirmedHebrewForm({
    required this.resultId,
    required this.pointedHebrew,
    required this.baseHebrew,
    required this.pronunciation,
    required this.origin,
    required this.ruleVersion,
    required this.gematriaVersion,
    required this.letters,
    required this.value,
    required this.confirmedAt,
  });

  Map<String, Object> toJson() => {
    'result_id': resultId,
    'pointed_hebrew': pointedHebrew,
    'base_hebrew': baseHebrew,
    'pronunciation': pronunciation,
    'origin': origin.name,
    'rule_version': ruleVersion,
    'gematria_version': gematriaVersion,
    'letters': letters.map((letter) => letter.toJson()).toList(),
    'value': value,
    'confirmed_at': confirmedAt.toUtc().toIso8601String(),
  };

  factory ConfirmedHebrewForm.fromJson(Map<String, dynamic> json) =>
      ConfirmedHebrewForm(
        resultId: json['result_id'] as String,
        pointedHebrew: json['pointed_hebrew'] as String,
        baseHebrew: json['base_hebrew'] as String,
        pronunciation: json['pronunciation'] as String,
        origin: HebrewFormOrigin.values.byName(json['origin'] as String),
        ruleVersion: json['rule_version'] as String,
        gematriaVersion: json['gematria_version'] as String,
        letters: (json['letters'] as List<dynamic>)
            .map(
              (item) => GematriaLetter.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
        value: json['value'] as int,
        confirmedAt: DateTime.parse(json['confirmed_at'] as String),
      );
}

@immutable
class ReadingNamePart {
  final String id;
  final NamePartType type;
  final String originalText;
  final ReadingDialect dialect;
  final DateTime createdAt;
  final List<ConfirmedHebrewForm> confirmedForms;

  const ReadingNamePart({
    required this.id,
    required this.type,
    required this.originalText,
    required this.dialect,
    required this.createdAt,
    this.confirmedForms = const [],
  });

  ConfirmedHebrewForm? get currentForm =>
      confirmedForms.isEmpty ? null : confirmedForms.last;

  ReadingNamePart addForm(ConfirmedHebrewForm form) => ReadingNamePart(
    id: id,
    type: type,
    originalText: originalText,
    dialect: dialect,
    createdAt: createdAt,
    confirmedForms: [...confirmedForms, form],
  );

  Map<String, Object> toJson() => {
    'id': id,
    'type': type.name,
    'original_text': originalText,
    'dialect': dialect.name,
    'created_at': createdAt.toUtc().toIso8601String(),
    'confirmed_forms': confirmedForms.map((form) => form.toJson()).toList(),
  };

  factory ReadingNamePart.fromJson(Map<String, dynamic> json) =>
      ReadingNamePart(
        id: json['id'] as String,
        type: NamePartType.values.byName(json['type'] as String),
        originalText: json['original_text'] as String,
        dialect: ReadingDialect.values.byName(json['dialect'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        confirmedForms: (json['confirmed_forms'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  ConfirmedHebrewForm.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
      );
}

@immutable
class ReadingIdentityProfile {
  static const schemaVersion = 2;

  /// Versiones que este binario sabe abrir. La 1 es anterior a los puentes:
  /// se lee sin ninguno encendido, que es el estado por defecto de todos
  /// modos, asi que la migracion no puede conceder permisos por accidente.
  static const supportedSchemaVersions = <int>{1, 2};

  final List<ReadingNamePart> parts;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Puentes que la persona encendio explicitamente. El consentimiento vive
  /// dentro del propio perfil cifrado: borrar el perfil borra el permiso por
  /// construccion, no por acordarse de hacerlo en otro sitio.
  final Set<ThresholdBridge> bridges;

  const ReadingIdentityProfile({
    required this.parts,
    required this.createdAt,
    required this.updatedAt,
    this.bridges = const <ThresholdBridge>{},
  });

  bool allows(ThresholdBridge bridge) => bridges.contains(bridge);

  ReadingIdentityProfile withBridges(
    Set<ThresholdBridge> next,
    DateTime updatedAt,
  ) => ReadingIdentityProfile(
    parts: parts,
    createdAt: createdAt,
    updatedAt: updatedAt,
    bridges: next,
  );

  Map<String, Object> toJson() => {
    'schema_version': schemaVersion,
    'parts': parts.map((part) => part.toJson()).toList(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'bridges': bridges.map((bridge) => bridge.name).toList(growable: false),
  };

  factory ReadingIdentityProfile.fromJson(Map<String, dynamic> json) {
    if (!supportedSchemaVersions.contains(json['schema_version'])) {
      throw const FormatException('Version de perfil no compatible');
    }
    final names = ThresholdBridge.values.asNameMap();
    return ReadingIdentityProfile(
      parts: (json['parts'] as List<dynamic>)
          .map((item) => ReadingNamePart.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      // Un puente desconocido se descarta en vez de romper la carga: un
      // binario viejo nunca debe conceder un permiso que no sabe explicar.
      bridges: ((json['bridges'] as List<dynamic>?) ?? const [])
          .map((item) => names[item as String])
          .nonNulls
          .toSet(),
    );
  }
}
