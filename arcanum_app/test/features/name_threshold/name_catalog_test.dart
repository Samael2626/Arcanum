import 'package:arcanum_app/features/name_threshold/data/name_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalogo contiene fichas verificadas de origen hebreo y griego', () {
    expect(NameCatalog.entries, hasLength(25));
    for (final entry in NameCatalog.entries) {
      expect(entry.citation, isNotEmpty);
      expect(entry.sourceUrl, startsWith('https://'));
      expect(entry.attribution, contains('CC BY'));
      expect(entry.hebrew != null || entry.documentedForm != null, isTrue);
    }
  });

  test('variantes resuelven ficha y ausencia no inventa contenido', () {
    expect(NameCatalog.find('Joseph')?.id, 'jose');
    expect(NameCatalog.find('Nombre sin ficha'), isNull);
  });

  test('Andres conserva su forma griega y no inventa un origen hebreo', () {
    final andres = NameCatalog.find('Andrés')!;

    expect(andres.origin, contains('Griego'));
    expect(andres.meaning, 'Hombre; asociado con valor.');
    expect(andres.documentedForm, 'Ἀνδρέας');
    expect(andres.hebrew, isNull);
    expect(andres.story, contains('ἀνήρ'));
  });

  test('Samuel conserva historia y lectura tradicional separadas', () {
    final samuel = NameCatalog.find('Samuel')!;

    expect(samuel.meaning, 'Dios ha escuchado.');
    expect(samuel.story, contains('Ana'));
    expect(samuel.traditionalRoots, hasLength(2));
    expect(samuel.traditionalRoots.first.hebrew, 'שמע');
    expect(samuel.traditionalRoots.last.hebrew, 'אל');
    expect(samuel.traditionalRootsLimit, contains('discusión filológica'));
  });
}
