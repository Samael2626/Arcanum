import 'package:arcanum_app/features/name_threshold/data/name_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalogo contiene solo las veinte fichas verificadas', () {
    expect(NameCatalog.entries, hasLength(20));
    for (final entry in NameCatalog.entries) {
      expect(entry.citation, isNotEmpty);
      expect(entry.sourceUrl, startsWith('https://'));
      expect(entry.attribution, contains('CC BY 4.0'));
      expect(entry.hebrew, isNotEmpty);
    }
  });

  test('variantes resuelven ficha y ausencia no inventa contenido', () {
    expect(NameCatalog.find('Joseph')?.id, 'jose');
    expect(NameCatalog.find('Nombre sin ficha'), isNull);
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
