import 'package:flutter/foundation.dart';

import '../data/name_catalog.dart';
import 'reading_identity.dart';

/// Lo unico que un puente puede llevar fuera del modulo Nombre y Umbral.
///
/// Es un recorte deliberado del perfil, no una vista del perfil: se
/// construye solo con el primer nombre de pila y con texto ya auditado del
/// catalogo editorial. El apellido no entra aqui por construccion, asi que
/// ningun modulo receptor puede filtrarlo aunque quiera.
///
/// Nada de lo que vive aqui se persiste: se calcula al vuelo cada vez que un
/// modulo lo pide, de modo que revocar el consentimiento lo borra sin tener
/// que ir a buscar copias.
@immutable
class NameResonance {
  /// Nombre de pila tal como la persona lo escribio. Local siempre: nunca
  /// forma parte de lo que cruza al Oraculo.
  final String givenName;

  /// Frase de significado copiada literal de la ficha del catalogo. Es lo
  /// unico que puede salir del dispositivo, y solo por el puente Oraculo.
  final String? sourceMeaning;

  final String? traditionLabel;

  /// Limite editorial de la ficha. Se muestra siempre que exista: es el
  /// contrapeso explicito a leer la frase como un dato sobre la persona.
  final String? editorialLimit;

  /// Valor de gematria de la forma confirmada mas reciente. Local siempre.
  final int? gematriaValue;
  final String? gematriaOriginLabel;

  const NameResonance({
    required this.givenName,
    this.sourceMeaning,
    this.traditionLabel,
    this.editorialLimit,
    this.gematriaValue,
    this.gematriaOriginLabel,
  });

  /// Construye la resonancia del primer nombre de pila del perfil.
  ///
  /// Devuelve null si no hay ninguno: un perfil que solo tiene apellidos no
  /// cruza ningun puente en esta fase, porque no hay nada publicable que
  /// cruzar.
  static NameResonance? fromProfile(ReadingIdentityProfile? profile) {
    if (profile == null) return null;
    final given = profile.parts.where(
      (item) => item.type == NamePartType.givenName,
    );
    if (given.isEmpty) return null;
    final part = given.first;

    final entry = NameCatalog.find(part.originalText);
    final form = part.currentForm;

    // La gematria historica 1-400 exige escritura hebrea atestiguada. Si la
    // forma dice ser historica pero la tradicion no la habilita, el puente no
    // muestra valor alguno: degradar la etiqueta seria mentir en la otra
    // direccion, y mostrarla tal cual relajaria la invariante del modulo.
    final claimsHistorical = form?.origin == HebrewFormOrigin.historicalDocumented;
    final historicalAllowed =
        entry != null && entry.tradition.allowsHistoricalGematria;
    final showsGematria = form != null && (!claimsHistorical || historicalAllowed);

    return NameResonance(
      givenName: part.originalText,
      sourceMeaning: entry?.meaning,
      traditionLabel: entry?.tradition.label,
      editorialLimit: entry?.editorialLimit,
      gematriaValue: showsGematria ? form.value : null,
      gematriaOriginLabel: showsGematria ? form.origin.label : null,
    );
  }

  /// Prosa local de la tarjeta.
  ///
  /// El sujeto gramatical es siempre el nombre o la fuente, nunca la persona
  /// ni la carta: ahi esta el limite entre sugerir y afirmar.
  String get prose {
    if (sourceMeaning == null) {
      return 'Junto a esta lectura permanece $givenName, aun sin ficha en el archivo.';
    }
    final tradition = traditionLabel == null
        ? 'Las fuentes'
        : 'Las fuentes de tradicion ${traditionLabel!.toLowerCase()}';
    return 'Junto a esta lectura permanece $givenName. '
        '$tradition recogen ese nombre asi: $sourceMeaning';
  }

  String? get gematriaLine => gematriaValue == null
      ? null
      : 'Valor $gematriaValue · $gematriaOriginLabel';

  /// Lo unico que cruza hacia el Oraculo, y solo con su consentimiento propio.
  ///
  /// Sale la frase del catalogo, no el nombre. Sin ficha no sale nada: el
  /// texto libre que escribio la persona jamas se publica. El valor de
  /// gematria tampoco viaja, porque un numero suelto invita al modelo a hacer
  /// numerologia por su cuenta.
  String? get oracleClause {
    final meaning = sourceMeaning;
    if (meaning == null) return null;
    return 'Resonancia simbolica elegida por quien consulta: $meaning '
        'Acompana la lectura como eco; no afirma rasgos, destino ni caracter.';
  }

  /// Compone la pregunta que viaja al servidor.
  ///
  /// Si no hay pregunta la resonancia no viaja sola: una peticion sin texto
  /// significa "lee la tirada", y convertirla en una frase sobre el nombre
  /// cambiaria lo que la persona pidio.
  static String composeOracleQuestion(
    String question,
    NameResonance? resonance,
  ) {
    final clause = resonance?.oracleClause;
    final clean = question.trim();
    if (clause == null || clean.isEmpty) return question;
    return '$clean\n\n$clause';
  }
}
