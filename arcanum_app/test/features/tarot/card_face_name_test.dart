import 'package:arcanum_app/features/tarot/domain/table_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('un menor se nombra por numero y palo; el titulo GD va aparte', () {
    // GN2200: «Señor de la Paz Restaurada» sin decir que es el Dos de Espadas
    const f = CardFace(
      slug: 'dos-de-espadas',
      reversed: false,
      arcana: 'minor',
      nameEs: 'Dos de Espadas',
      titleEs: 'Señor de la Paz Restaurada',
    );
    expect(f.commonName, 'Dos de Espadas');
    expect(f.goldenDawnTitle, 'Señor de la Paz Restaurada');
  });

  test('lo ya guardado con el titulo GD en name_es tambien se corrige', () {
    const f = CardFace(
      slug: 'sota-de-bastos',
      reversed: false,
      arcana: 'minor',
      nameEs: 'Princesa de la Llama Brillante',
    );
    expect(f.commonName, 'Sota de Bastos');
    expect(f.goldenDawnTitle, 'Princesa de la Llama Brillante');
  });

  test('un mayor conserva su nombre y no repite titulo', () {
    const f = CardFace(
      slug: 'el-colgado',
      reversed: false,
      arcana: 'major',
      nameEs: 'El Colgado',
    );
    expect(f.commonName, 'El Colgado');
    expect(f.goldenDawnTitle, isNull);
  });

  test('title_es viaja en el JSON', () {
    final f = CardFace.fromJson({
      'slug': 'as-de-copas',
      'reversed': true,
      'arcana': 'minor',
      'title_es': 'Raíz de los Poderes del Agua',
    });
    expect(f.commonName, 'As de Copas');
    expect(
      CardFace.fromJson(f.toJson()).titleEs,
      'Raíz de los Poderes del Agua',
    );
  });
}
