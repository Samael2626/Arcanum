import 'package:arcanum_app/features/name_threshold/data/name_catalog.dart';
import 'package:arcanum_app/features/name_threshold/data/name_sources.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ids de las 25 fichas de la fundacion. El lote V1.1 amplia el catalogo
/// pero no puede perder ni renombrar ninguna de ellas.
const _fundacion = <String>{
  'andres',
  'alejandro',
  'felipe',
  'jorge',
  'sofia',
  'adan',
  'eva',
  'noe',
  'abraham',
  'sara',
  'isaac',
  'jacob',
  'israel',
  'jose',
  'benjamin',
  'moises',
  'josue',
  'samuel',
  'david',
  'salomon',
  'daniel',
  'elias',
  'isaias',
  'jonas',
  'ana',
};

void main() {
  group('procedencia', () {
    test('cada ficha tiene cita, fuente, url, licencia y atribución', () {
      expect(NameCatalog.entries.length, greaterThanOrEqualTo(100));
      for (final entry in NameCatalog.entries) {
        expect(entry.citation, isNotEmpty, reason: entry.id);
        expect(entry.sourceUrl, startsWith('https://'), reason: entry.id);
        expect(entry.source.url, startsWith('https://'), reason: entry.id);
        expect(entry.attribution, isNotEmpty, reason: entry.id);
        expect(entry.license, isNotEmpty, reason: entry.id);
        expect(entry.editorialLimit, isNotEmpty, reason: entry.id);
      }
    });

    test('toda ficha declara una forma documentada', () {
      for (final entry in NameCatalog.entries) {
        expect(
          entry.archiveForm,
          isNotNull,
          reason: '${entry.id} no tiene forma documentada',
        );
        expect(entry.archiveFormLabel, isNotNull, reason: entry.id);
      }
    });

    test('los ids son únicos', () {
      final ids = NameCatalog.entries.map((entry) => entry.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('toda fuente usada está declarada en NameSources', () {
      for (final entry in NameCatalog.entries) {
        expect(NameSources.all, contains(entry.source), reason: entry.id);
      }
    });
  });

  group('gematría histórica', () {
    test('solo la escritura hebrea documentada la habilita', () {
      for (final entry in NameCatalog.entries) {
        expect(
          entry.hasHistoricalHebrew,
          entry.tradition.allowsHistoricalGematria,
          reason:
              '${entry.id}: la tradición ${entry.tradition.name} y la presencia de escritura hebrea deben coincidir',
        );
      }
    });

    test('griego, latín, germánico y árabe nunca la habilitan', () {
      const sinGematria = [
        NameTradition.greek,
        NameTradition.latin,
        NameTradition.germanic,
        NameTradition.arabic,
      ];
      for (final tradition in sinGematria) {
        expect(tradition.allowsHistoricalGematria, isFalse);
        final fichas = NameCatalog.byTradition(tradition);
        expect(fichas, isNotEmpty, reason: tradition.name);
        for (final entry in fichas) {
          expect(entry.hebrew, isNull, reason: entry.id);
          expect(entry.hasHistoricalHebrew, isFalse, reason: entry.id);
        }
      }
    });

    test('Andrés conserva su forma griega y no inventa un origen hebreo', () {
      final andres = NameCatalog.find('Andrés')!;

      expect(andres.tradition, NameTradition.greek);
      expect(andres.origin, contains('Griego'));
      expect(andres.meaning, 'Hombre; asociado con valor.');
      expect(andres.documentedForm, 'Ἀνδρέας');
      expect(andres.hebrew, isNull);
      expect(andres.story, contains('ἀνήρ'));
    });

    test('Samuel conserva historia y lectura tradicional separadas', () {
      final samuel = NameCatalog.find('Samuel')!;

      expect(samuel.tradition, NameTradition.hebrew);
      expect(samuel.meaning, 'Dios ha escuchado.');
      expect(samuel.story, contains('Ana'));
      expect(samuel.traditionalRoots, hasLength(2));
      expect(samuel.traditionalRoots.first.hebrew, 'שמע');
      expect(samuel.traditionalRoots.last.hebrew, 'אל');
      expect(samuel.traditionalRootsLimit, contains('discusión filológica'));
    });

    test('las raíces tradicionales solo aparecen en fichas hebreas', () {
      for (final entry in NameCatalog.entries) {
        if (entry.traditionalRoots.isEmpty) continue;
        expect(entry.tradition, NameTradition.hebrew, reason: entry.id);
        expect(entry.traditionalRootsLimit, isNotNull, reason: entry.id);
      }
    });
  });

  group('honestidad editorial', () {
    test('ninguna ficha no hebrea se presenta como hebrea', () {
      for (final entry in NameCatalog.entries) {
        if (entry.tradition == NameTradition.hebrew) continue;
        final prosa = '${entry.origin} ${entry.visibleProse}'.toLowerCase();
        expect(
          prosa,
          isNot(contains('hebre')),
          reason: '${entry.id} habla de hebreo sin serlo',
        );
      }
    });

    test('la etiqueta de forma corresponde a la tradición', () {
      const esperado = {
        NameTradition.hebrew: 'hebrea',
        NameTradition.greek: 'griega',
        NameTradition.latin: 'latina',
        NameTradition.germanic: 'germánica',
        NameTradition.arabic: 'árabe',
      };
      for (final entry in NameCatalog.entries) {
        expect(
          entry.archiveFormLabel!.toLowerCase(),
          contains(esperado[entry.tradition]!),
          reason: entry.id,
        );
      }
    });

    test('la prosa visible nunca contiene una URL cruda', () {
      for (final entry in NameCatalog.entries) {
        final prosa = '${entry.origin} ${entry.visibleProse}';
        expect(prosa, isNot(contains('http')), reason: entry.id);
        expect(prosa, isNot(contains('www.')), reason: entry.id);
        expect(prosa, isNot(contains('.com')), reason: entry.id);
        expect(prosa, isNot(contains('CC BY')), reason: entry.id);
      }
    });

    test('la prosa visible no hace afirmaciones sobre la persona', () {
      const prohibido = [
        'tu destino',
        'tu personalidad',
        'serás',
        'te hará',
        'garantiza',
        'predice',
      ];
      for (final entry in NameCatalog.entries) {
        final prosa = entry.visibleProse.toLowerCase();
        for (final frase in prohibido) {
          expect(prosa, isNot(contains(frase)), reason: '${entry.id}: $frase');
        }
      }
    });

    test('un significado discutido se declara como tal', () {
      final disputadas = NameCatalog.entries.where(
        (entry) => entry.meaningEvidence == EvidenceLevel.disputed,
      );
      expect(disputadas, isNotEmpty);
      for (final entry in disputadas) {
        expect(
          entry.certainty,
          contains(EvidenceLevel.disputed.label),
          reason: entry.id,
        );
      }
    });

    test('María y Antonio no reciben una etimología inventada', () {
      final maria = NameCatalog.find('María')!;
      expect(maria.meaningEvidence, EvidenceLevel.disputed);
      expect(maria.formEvidence, EvidenceLevel.attested);
      expect(maria.hebrew, 'מרים');

      final antonio = NameCatalog.find('Antonio')!;
      expect(antonio.tradition, NameTradition.latin);
      expect(antonio.meaningEvidence, EvidenceLevel.disputed);
      expect(antonio.meaning, isNot(contains('inestimable')));
    });
  });

  group('compatibilidad', () {
    test('las 25 fichas de la fundación siguen presentes', () {
      final ids = NameCatalog.entries.map((entry) => entry.id).toSet();
      expect(ids.containsAll(_fundacion), isTrue);
    });

    test('las fichas griegas de la fundación conservan su enlace de lema', () {
      for (final id in ['andres', 'alejandro', 'felipe', 'jorge', 'sofia']) {
        final entry = NameCatalog.entries.firstWhere((e) => e.id == id);
        expect(entry.entryUrl, startsWith('https://atlas.perseus.tufts.edu/'));
        expect(entry.sourceUrl, entry.entryUrl);
      }
    });

    test('variantes resuelven ficha y ausencia no inventa contenido', () {
      expect(NameCatalog.find('Joseph')?.id, 'jose');
      expect(NameCatalog.find('Hernando')?.id, 'fernando');
      expect(NameCatalog.find('  MIGUEL ')?.id, 'miguel');
      expect(NameCatalog.find('Nombre sin ficha'), isNull);
      expect(NameCatalog.find('   '), isNull);
    });

    test('el lote V1.1 aporta al menos 75 fichas nuevas', () {
      final nuevas = NameCatalog.entries
          .where((entry) => !_fundacion.contains(entry.id))
          .length;
      expect(nuevas, greaterThanOrEqualTo(75));
    });

    test('todas las tradiciones previstas están representadas', () {
      for (final tradition in NameTradition.values) {
        expect(
          NameCatalog.byTradition(tradition),
          isNotEmpty,
          reason: tradition.name,
        );
      }
    });
  });
}
