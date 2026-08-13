class NameCatalogEntry {
  final String id;
  final String displayName;
  final List<String> variants;
  final String origin;
  final String meaning;
  final String etymology;
  final String certainty;
  final String? hebrew;
  final String? documentedForm;
  final String? documentedFormLabel;
  final String citation;
  final String sourceUrl;
  final String attribution;
  final String editorialLimit;
  final String? story;
  final List<NameRoot> traditionalRoots;
  final String? traditionalRootsLimit;

  const NameCatalogEntry({
    required this.id,
    required this.displayName,
    required this.variants,
    required this.origin,
    required this.meaning,
    required this.etymology,
    required this.certainty,
    this.hebrew,
    this.documentedForm,
    this.documentedFormLabel,
    required this.citation,
    required this.sourceUrl,
    required this.attribution,
    required this.editorialLimit,
    this.story,
    this.traditionalRoots = const [],
    this.traditionalRootsLimit,
  });

  bool get hasHistoricalHebrew => hebrew != null && hebrew!.isNotEmpty;

  String? get archiveForm => documentedForm ?? hebrew;

  String? get archiveFormLabel =>
      documentedFormLabel ??
      (hasHistoricalHebrew ? 'Forma hebrea documentada' : null);
}

class NameRoot {
  final String hebrew;
  final String transliteration;
  final String meaning;

  const NameRoot({
    required this.hebrew,
    required this.transliteration,
    required this.meaning,
  });
}

class NameCatalog {
  static const oshbUrl = 'https://github.com/openscriptures/morphhb';
  static const attribution =
      'Open Scriptures Hebrew Bible Project; WLC dominio público, lema y morfología CC BY 4.0.';

  static const entries = <NameCatalogEntry>[
    NameCatalogEntry(
      id: 'andres',
      displayName: 'Andrés',
      variants: ['Andres', 'Andreas', 'Andrew', 'Andre'],
      origin: 'Griego antiguo, a través del latín y el español',
      meaning: 'Hombre; asociado con valor.',
      etymology:
          'Forma española de Andreas, del griego Ἀνδρέας. Su familia léxica remite a ἀνήρ / ἀνδρός: «hombre».',
      certainty: 'Alta',
      documentedForm: 'Ἀνδρέας',
      documentedFormLabel: 'Forma griega documentada',
      citation: 'SBLGNT Juan 1:40; LSJ ἀνήρ y ἀνδρεῖος',
      sourceUrl:
          'https://atlas.perseus.tufts.edu/dictionaries/entry/urn%3Acite2%3Ascaife-viewer%3Adictionaries.v1%3Alsj-n8665/',
      attribution:
          'SBL Greek New Testament, CC BY 4.0; Liddell-Scott, CC BY-SA 3.0.',
      editorialLimit:
          'La historia de la palabra habla de una forma lingüística; no prescribe carácter ni destino.',
      story:
          'Andrés conserva la huella de Ἀνδρέας. En griego, ἀνήρ nombra al hombre; su familia también contiene ἀνδρεῖος, «valiente». De ahí nace una lectura de valor, no una sentencia sobre quién debes ser.',
    ),
    NameCatalogEntry(
      id: 'alejandro',
      displayName: 'Alejandro',
      variants: ['Alexander', 'Alexandro', 'Alex'],
      origin: 'Griego antiguo, a través del latín y el español',
      meaning: 'Defensor de los hombres.',
      etymology:
          'Del griego Ἀλέξανδρος. El léxico lo glosa como «defensor de los hombres».',
      certainty: 'Alta',
      documentedForm: 'Ἀλέξανδρος',
      documentedFormLabel: 'Forma griega documentada',
      citation: 'LSJ ἀλέξανδρος',
      sourceUrl:
          'https://atlas.perseus.tufts.edu/dictionaries/entry/urn%3Acite2%3Ascaife-viewer%3Adictionaries.v1%3Alsj-n3997/',
      attribution: 'Liddell-Scott, CC BY-SA 3.0.',
      editorialLimit:
          'El sentido etimológico no impone una misión de protección a la persona.',
    ),
    NameCatalogEntry(
      id: 'felipe',
      displayName: 'Felipe',
      variants: ['Philip', 'Felipe'],
      origin: 'Griego antiguo, a través del latín y el español',
      meaning: 'Amigo de los caballos.',
      etymology:
          'Del griego φίλιππος, compuesto que el léxico define como «aficionado a los caballos».',
      certainty: 'Alta',
      documentedForm: 'Φίλιππος',
      documentedFormLabel: 'Forma griega documentada',
      citation: 'Middle Liddell φίλιππος',
      sourceUrl:
          'https://atlas.perseus.tufts.edu/dictionaries/entry/urn%3Acite2%3Ascaife-viewer%3Adictionary-entries.atlas_v1%3Amiddle-liddell.perseus-eng2-n34799/',
      attribution: 'Middle Liddell en Scaife ATLAS, CC BY-SA 3.0.',
      editorialLimit:
          'No asigna afinidades, profesión ni temperamento a quien lleva el nombre.',
    ),
    NameCatalogEntry(
      id: 'jorge',
      displayName: 'Jorge',
      variants: ['George', 'Georgios'],
      origin: 'Griego antiguo, a través del latín y el español',
      meaning: 'Quien trabaja la tierra.',
      etymology:
          'Se vincula con γεωργός, compuesto de «tierra» y «trabajo»: labrador o cultivador.',
      certainty: 'Alta',
      documentedForm: 'Γεώργιος',
      documentedFormLabel: 'Forma griega documentada',
      citation: 'LSJ γεωργός',
      sourceUrl:
          'https://atlas.perseus.tufts.edu/dictionaries/entry/urn%3Acite2%3Ascaife-viewer%3Adictionaries.v1%3Alsj-n22088/',
      attribution: 'Liddell-Scott, CC BY-SA 3.0.',
      editorialLimit:
          'La imagen del cultivo es histórica; no describe oficio ni destino.',
    ),
    NameCatalogEntry(
      id: 'sofia',
      displayName: 'Sofía',
      variants: ['Sofia', 'Sophia'],
      origin: 'Griego antiguo, a través del latín y el español',
      meaning: 'Sabiduría; destreza.',
      etymology:
          'Del griego σοφία. El léxico conserva sentidos de destreza técnica, arte y saber.',
      certainty: 'Alta',
      documentedForm: 'Σοφία',
      documentedFormLabel: 'Forma griega documentada',
      citation: 'LSJ σοφία',
      sourceUrl:
          'https://atlas.perseus.tufts.edu/dictionaries/entry/urn%3Acite2%3Ascaife-viewer%3Adictionaries.v1%3Alsj-n95641/',
      attribution: 'Liddell-Scott, CC BY-SA 3.0.',
      editorialLimit:
          'No presenta el significado como capacidad, diagnóstico ni promesa personal.',
    ),
    NameCatalogEntry(
      id: 'adan',
      displayName: 'Adán',
      variants: ['Adam'],
      origin: 'Hebreo bíblico',
      meaning: 'Humano, hombre.',
      etymology: 'El relato vincula el nombre con adamah, suelo.',
      certainty: 'Alta en forma; media en explicación',
      hebrew: 'אדם',
      citation: 'Génesis 2:20; BDB אדם',
      sourceUrl: oshbUrl,
      attribution: attribution,
      editorialLimit: 'No es prueba de que una persona esté «hecha de tierra».',
    ),
    NameCatalogEntry(
      id: 'eva',
      displayName: 'Eva',
      variants: ['Hava', 'Chava'],
      origin: 'Hebreo bíblico',
      meaning: 'El relato la llama madre de todo viviente.',
      etymology: 'Explicación narrativa relacionada con vivir.',
      certainty: 'Alta en forma; media en etimología',
      hebrew: 'חוה',
      citation: 'Génesis 3:20; BDB חוה/חיה',
      sourceUrl: oshbUrl,
      attribution: attribution,
      editorialLimit: 'La explicación narrativa no prueba hechos biográficos.',
    ),
    NameCatalogEntry(
      id: 'noe',
      displayName: 'Noé',
      variants: ['Noah'],
      origin: 'Hebreo bíblico',
      meaning: 'Asociado con descanso y consuelo.',
      etymology: 'Juego narrativo de Génesis.',
      certainty: 'Alta en forma; media en etimología',
      hebrew: 'נח',
      citation: 'Génesis 5:29; BDB נוח',
      sourceUrl: oshbUrl,
      attribution: attribution,
      editorialLimit: 'Asociación narrativa, no equivalencia absoluta.',
    ),
    NameCatalogEntry(
      id: 'abraham',
      displayName: 'Abraham',
      variants: ['Abram'],
      origin: 'Hebreo bíblico',
      meaning: 'Padre de multitud en el relato.',
      etymology: 'Explicación narrativa del cambio de nombre.',
      certainty: 'Alta en forma; media en etimología',
      hebrew: 'אברהם',
      citation: 'Génesis 17:5',
      sourceUrl: oshbUrl,
      attribution: attribution,
      editorialLimit: 'Abram y Abraham son formas distintas para el cálculo.',
    ),
    NameCatalogEntry(
      id: 'sara',
      displayName: 'Sara',
      variants: ['Sarah'],
      origin: 'Hebreo bíblico',
      meaning: 'Princesa o señora.',
      etymology: 'Forma hebrea שרה.',
      certainty: 'Alta',
      hebrew: 'שרה',
      citation: 'Génesis 17:15; BDB שרה',
      sourceUrl: oshbUrl,
      attribution: attribution,
      editorialLimit: 'No implica rango, nobleza ni carácter.',
    ),
    NameCatalogEntry(
      id: 'isaac',
      displayName: 'Isaac',
      variants: ['Isac'],
      origin: 'Hebreo bíblico',
      meaning: 'Él ríe; risa.',
      etymology: 'Relacionado con el verbo hebreo reír.',
      certainty: 'Alta',
      hebrew: 'יצחק',
      citation: 'Génesis 17:19; 21:6; BDB צחק',
      sourceUrl: oshbUrl,
      attribution: attribution,
      editorialLimit: 'No define un rasgo psicológico.',
    ),
    NameCatalogEntry(
      id: 'jacob',
      displayName: 'Jacob',
      variants: ['Jacobo', 'Yaakov'],
      origin: 'Hebreo bíblico',
      meaning: 'El relato lo vincula con el talón.',
      etymology: 'Juego narrativo con la raíz עקב.',
      certainty: 'Alta en forma; media en etimología',
      hebrew: 'יעקב',
      citation: 'Génesis 25:26; BDB עקב',
      sourceUrl: oshbUrl,
      attribution: attribution,
      editorialLimit: 'No es diagnóstico moral.',
    ),
    NameCatalogEntry(
      id: 'israel',
      displayName: 'Israel',
      variants: ['Yisrael'],
      origin: 'Hebreo bíblico',
      meaning: 'El relato lo explica como contender con Dios y hombres.',
      etymology: 'Explicación narrativa de Génesis.',
      certainty: 'Alta en forma; media en etimología',
      hebrew: 'ישראל',
      citation: 'Génesis 32:29',
      sourceUrl: oshbUrl,
      attribution: attribution,
      editorialLimit: 'No permite inferir religión, ciudadanía o etnia.',
    ),
    NameCatalogEntry(
      id: 'jose',
      displayName: 'José',
      variants: ['Joseph', 'Yosef'],
      origin: 'Hebreo bíblico',
      meaning: 'Que añada.',
      etymology: 'El relato lo relaciona con añadir.',
      certainty: 'Alta',
      hebrew: 'יוסף',
      citation: 'Génesis 30:24; BDB יסף',
      sourceUrl: oshbUrl,
      attribution: attribution,
      editorialLimit: 'No promete abundancia.',
    ),
    NameCatalogEntry(
      id: 'benjamin',
      displayName: 'Benjamín',
      variants: ['Benjamin', 'Binyamin'],
      origin: 'Hebreo bíblico',
      meaning: 'Hijo de la derecha o del sur.',
      etymology: 'Contrasta con Ben-oní en el relato.',
      certainty: 'Alta en forma; media en matiz',
      hebrew: 'בנימין',
      citation: 'Génesis 35:18; BDB בנימין',
      sourceUrl: oshbUrl,
      attribution: attribution,
      editorialLimit: 'No implica jerarquía familiar.',
    ),
    NameCatalogEntry(
      id: 'moises',
      displayName: 'Moisés',
      variants: ['Moses', 'Moshe'],
      origin: 'Bíblico; origen discutido',
      meaning: 'Éxodo lo relaciona con sacar de las aguas.',
      etymology: 'Posible origen egipcio; no existe consenso único.',
      certainty: 'Alta en forma; baja en origen único',
      hebrew: 'משה',
      citation: 'Éxodo 2:10; BDB משה',
      sourceUrl: oshbUrl,
      attribution: attribution,
      editorialLimit: 'La disputa etimológica debe permanecer visible.',
    ),
    NameCatalogEntry(
      id: 'josue',
      displayName: 'Josué',
      variants: ['Joshua', 'Yehoshua'],
      origin: 'Hebreo bíblico',
      meaning: 'YHWH salva.',
      etymology: 'Nombre teofórico hebreo.',
      certainty: 'Alta',
      hebrew: 'יהושע',
      citation: 'Números 13:16; Josué 1:1; TBESH',
      sourceUrl: oshbUrl,
      attribution: attribution,
      editorialLimit: 'No promete protección.',
    ),
    NameCatalogEntry(
      id: 'samuel',
      displayName: 'Samuel',
      variants: ['Shmuel'],
      origin: 'Hebreo bíblico',
      meaning: 'Dios ha escuchado.',
      etymology: 'La etimología exacta de la forma hebrea sigue discutida.',
      certainty: 'Alta en forma; media en etimología',
      hebrew: 'שמואל',
      citation: '1 Samuel 1:20; BDB שמואל',
      sourceUrl: oshbUrl,
      attribution: attribution,
      editorialLimit: 'Mostrar explicación narrativa y disputa.',
      story:
          'En el primer libro de Samuel, Ana nombra a su hijo tras pedirlo a YHWH. De ese relato nace la lectura tradicional: Dios ha escuchado.',
      traditionalRoots: [
        NameRoot(hebrew: 'שמע', transliteration: 'shama', meaning: 'escuchar'),
        NameRoot(hebrew: 'אל', transliteration: 'El', meaning: 'Dios'),
      ],
      traditionalRootsLimit:
          'Es una lectura tradicional de las letras. No cierra por sí sola la discusión filológica sobre שמואל.',
    ),
    NameCatalogEntry(
      id: 'david',
      displayName: 'David',
      variants: ['Dawid'],
      origin: 'Hebreo bíblico',
      meaning: 'Probablemente amado.',
      etymology: 'Relacionado con דוד.',
      certainty: 'Alta en forma; media en etimología',
      hebrew: 'דוד',
      citation: '1 Samuel 16:13; BDB דוד',
      sourceUrl: oshbUrl,
      attribution: attribution,
      editorialLimit: '«Probablemente», no certeza total.',
    ),
    NameCatalogEntry(
      id: 'salomon',
      displayName: 'Salomón',
      variants: ['Solomon', 'Shlomo'],
      origin: 'Hebreo bíblico',
      meaning: 'Relacionado con paz.',
      etymology: 'El relato lo llama hombre de paz.',
      certainty: 'Alta',
      hebrew: 'שלמה',
      citation: '1 Crónicas 22:9; BDB שלם',
      sourceUrl: oshbUrl,
      attribution: attribution,
      editorialLimit: 'No promete una vida pacífica.',
    ),
    NameCatalogEntry(
      id: 'daniel',
      displayName: 'Daniel',
      variants: ['Daniyyel'],
      origin: 'Hebreo bíblico',
      meaning: 'Dios es mi juez.',
      etymology: 'Nombre teofórico hebreo.',
      certainty: 'Alta',
      hebrew: 'דניאל',
      citation: 'Daniel 1:6; TBESH',
      sourceUrl: oshbUrl,
      attribution: attribution,
      editorialLimit: 'No atribuye profesión ni destino judicial.',
    ),
    NameCatalogEntry(
      id: 'elias',
      displayName: 'Elías',
      variants: ['Elijah', 'Eliyahu'],
      origin: 'Hebreo bíblico',
      meaning: 'YHWH es mi Dios.',
      etymology: 'Nombre teofórico hebreo.',
      certainty: 'Alta',
      hebrew: 'אליהו',
      citation: '1 Reyes 17:1; TBESH',
      sourceUrl: oshbUrl,
      attribution: attribution,
      editorialLimit: 'No permite inferir religión de la persona.',
    ),
    NameCatalogEntry(
      id: 'isaias',
      displayName: 'Isaías',
      variants: ['Isaiah', 'Yeshayahu'],
      origin: 'Hebreo bíblico',
      meaning: 'YHWH salva.',
      etymology: 'Nombre teofórico hebreo.',
      certainty: 'Alta',
      hebrew: 'ישעיהו',
      citation: 'Isaías 1:1; TBESH',
      sourceUrl: oshbUrl,
      attribution: attribution,
      editorialLimit: 'No promete salvación.',
    ),
    NameCatalogEntry(
      id: 'jonas',
      displayName: 'Jonás',
      variants: ['Jonah', 'Yonah'],
      origin: 'Hebreo bíblico',
      meaning: 'Paloma.',
      etymology: 'Sustantivo hebreo יונה.',
      certainty: 'Alta',
      hebrew: 'יונה',
      citation: 'Jonás 1:1; BDB יונה',
      sourceUrl: oshbUrl,
      attribution: attribution,
      editorialLimit: 'No convierte el significado léxico en tótem.',
    ),
    NameCatalogEntry(
      id: 'ana',
      displayName: 'Ana',
      variants: ['Anna', 'Hannah'],
      origin: 'Hebreo bíblico',
      meaning: 'Favor o gracia.',
      etymology: 'Relacionado con la raíz חנן.',
      certainty: 'Alta',
      hebrew: 'חנה',
      citation: '1 Samuel 1:2; BDB חנן/חנה',
      sourceUrl: oshbUrl,
      attribution: attribution,
      editorialLimit: 'No implica favor sobrenatural.',
    ),
  ];

  static NameCatalogEntry? find(String value) {
    final key = _normalize(value);
    for (final entry in entries) {
      if (_normalize(entry.displayName) == key ||
          entry.variants.any((variant) => _normalize(variant) == key)) {
        return entry;
      }
    }
    return null;
  }

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u');
}
