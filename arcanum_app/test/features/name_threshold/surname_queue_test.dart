import 'package:arcanum_app/features/name_threshold/data/name_catalog.dart';
import 'package:arcanum_app/features/name_threshold/data/name_sources.dart';
import 'package:arcanum_app/features/name_threshold/data/surname_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cola editorial de apellidos', () {
    test('la cola tiene entradas y los ids son únicos', () {
      expect(SurnameQueue.entries, isNotEmpty);
      final ids = SurnameQueue.entries.map((entry) => entry.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('ningún apellido es publicable en V1.1', () {
      for (final entry in SurnameQueue.entries) {
        expect(entry.isPublishable, isFalse, reason: entry.id);
      }
    });

    test('ningún apellido recibe origen ni significado', () {
      for (final entry in SurnameQueue.entries) {
        expect(entry.publishedOrigin, isNull, reason: entry.id);
        expect(entry.publishedMeaning, isNull, reason: entry.id);
      }
    });

    test('cada entrada declara qué evidencia le falta', () {
      for (final entry in SurnameQueue.entries) {
        expect(entry.pendingEvidence, isNotEmpty, reason: entry.id);
      }
    });

    test('solo hay fuente citada cuando hay base verificada', () {
      for (final entry in SurnameQueue.entries) {
        if (entry.source == null) {
          expect(entry.citation, isNull, reason: entry.id);
          expect(entry.baseNameId, isNull, reason: entry.id);
          continue;
        }
        expect(NameSources.all, contains(entry.source), reason: entry.id);
        expect(entry.citation, isNotEmpty, reason: entry.id);
        expect(entry.baseNameId, isNotNull, reason: entry.id);
      }
    });

    test('toda base declarada resuelve a una ficha real del catálogo', () {
      final conBase = SurnameQueue.entries.where(
        (entry) => entry.baseNameId != null,
      );
      expect(conBase, isNotEmpty);
      for (final entry in conBase) {
        final base = entry.baseName;
        expect(base, isNotNull, reason: entry.id);
        expect(base!.id, entry.baseNameId, reason: entry.id);
      }
    });

    test('sin evidencia suficiente no hay base ni fuente', () {
      final sinEvidencia = SurnameQueue.byStatus(SurnameStatus.needsEvidence);
      expect(sinEvidencia, isNotEmpty);
      for (final entry in sinEvidencia) {
        expect(entry.baseNameId, isNull, reason: entry.id);
        expect(entry.source, isNull, reason: entry.id);
      }
    });

    test('los descartados quedan documentados y sin base', () {
      final descartados = SurnameQueue.byStatus(SurnameStatus.rejected);
      expect(descartados, isNotEmpty);
      for (final entry in descartados) {
        expect(entry.baseNameId, isNull, reason: entry.id);
        expect(entry.derivationEvidence, EvidenceLevel.disputed);
        expect(entry.pendingEvidence.length, greaterThan(40), reason: entry.id);
      }
    });

    test('la evidencia de derivación nunca llega a atestiguada en V1.1', () {
      for (final entry in SurnameQueue.entries) {
        expect(
          entry.derivationEvidence,
          isNot(EvidenceLevel.attested),
          reason: entry.id,
        );
      }
    });

    test('un apellido no aparece como ficha de nombre de pila', () {
      for (final entry in SurnameQueue.entries) {
        expect(
          NameCatalog.find(entry.displayName),
          isNull,
          reason:
              '${entry.displayName} no debe resolver a una ficha de nombre',
        );
      }
    });

    test('la cola no contiene texto de linaje, sangre ni nobleza', () {
      const prohibido = ['linaje', 'sangre', 'nobleza', 'escudo', 'estirpe'];
      for (final entry in SurnameQueue.entries) {
        final texto = entry.pendingEvidence.toLowerCase();
        for (final frase in prohibido) {
          expect(texto, isNot(contains(frase)), reason: '${entry.id}: $frase');
        }
      }
    });

    test('variantes resuelven y la ausencia no inventa nada', () {
      expect(SurnameQueue.find('Fernández')?.id, 'hernandez');
      expect(SurnameQueue.find('Vásquez')?.id, 'velasquez');
      expect(SurnameQueue.find('Muñoz')?.id, 'munoz');
      expect(SurnameQueue.find('Apellido inexistente'), isNull);
      expect(SurnameQueue.find(''), isNull);
    });
  });
}
