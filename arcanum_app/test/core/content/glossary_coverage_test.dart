import 'package:arcanum_app/core/content/glossary.dart';
import 'package:arcanum_app/features/cielos/sign_lore.dart';
import 'package:arcanum_app/features/hoy/hoy_lore.dart';
import 'package:arcanum_app/shared/astro_symbols.dart';
import 'package:flutter_test/flutter_test.dart';

/// La capa explicativa falla en silencio por naturaleza: si falta una entrada,
/// el "?" simplemente no aparece y la hoja no abre. Estos tests convierten ese
/// hueco de contenido en un test rojo.
void main() {
  group('cobertura del glosario', () {
    test('las 12 casas tienen entrada propia', () {
      for (var house = 1; house <= 12; house++) {
        final key = houseGlossaryKey(house);
        expect(key, 'casa_$house');
        expect(
          glossary[key],
          isNotNull,
          reason: 'falta la entrada de glosario "$key"',
        );
      }
    });

    test('el vocabulario del sello del cielo tiene explicación', () {
      // El sello enseña estos términos en pantalla y la app apuesta por
      // "toca y te explica" en vez de escribirlo todo en la tarjeta. Si falta
      // una entrada, el gesto abre un hueco y nadie se entera: por eso está
      // aquí y no en la cabeza de quien lo escribió.
      for (final key in const [
        'orbe', // "le faltan 0,8°" y la figura torcida
        'aplicativo', // "se va cerrando" contra "ya pasó"
        'transitos',
        'natal_vs_transito',
        'retrogrado', // el ℞ junto al planeta en tránsito
        // Estas tres son NUESTRAS: no existen en ninguna tradición y nadie
        // puede buscarlas fuera de la app. Sin entrada, la leyenda del sello
        // ("hoy" / "capítulo") sería una etiqueta sin significado.
        'capitulo',
        'hoy_transito', // el otro chip de la leyenda; sin esto abriría un hueco
        'sigilo',
        'sello',
      ]) {
        expect(
          glossary[key],
          isNotNull,
          reason: 'falta la entrada de glosario "$key"',
        );
        expect(glossary[key]!.what.trim(), isNotEmpty);
        expect(glossary[key]!.howTo.trim(), isNotEmpty);
      }
    });

    test('una casa fuera de rango cae al genérico, que existe', () {
      expect(houseGlossaryKey(0), 'casa');
      expect(houseGlossaryKey(13), 'casa');
      expect(glossary['casa'], isNotNull);
    });

    test('todo aspecto mostrado en pantalla tiene explicación', () {
      for (final aspect in aspectEs.keys) {
        final key = aspectGlossaryKey(aspect);
        expect(
          key,
          isNot('aspecto'),
          reason: '"$aspect" cae al genérico: falta su clave específica',
        );
        expect(
          glossary[key],
          isNotNull,
          reason: 'falta la entrada de glosario "$key" (aspecto "$aspect")',
        );
      }
    });

    test('un aspecto desconocido cae al genérico, que existe', () {
      expect(aspectGlossaryKey('quincunx'), 'aspecto');
      expect(glossary['aspecto'], isNotNull);
    });

    test('las claves fijas usadas en la carta natal existen', () {
      for (final key in const [
        'retrogrado',
        'natal_vs_transito',
        'carta_natal',
        'transitos',
        'ascendente',
      ]) {
        expect(
          glossary[key],
          isNotNull,
          reason: 'falta la entrada de glosario "$key"',
        );
      }
    });

    test('ninguna entrada está vacía', () {
      glossary.forEach((key, entry) {
        expect(entry.title.trim(), isNotEmpty, reason: '"$key" sin título');
        expect(entry.what.trim(), isNotEmpty, reason: '"$key" sin "qué es"');
        expect(
          entry.howTo.trim(),
          isNotEmpty,
          reason: '"$key" sin "cómo usarlo"',
        );
      });
    });
  });

  group('cobertura del lore', () {
    test('todo planeta de la carta natal tiene lore', () {
      for (final planet in planetEs.keys) {
        expect(
          planetLore[planet],
          isNotNull,
          reason:
              'falta el lore de "$planet": la carta lo dibuja y su hoja no abre',
        );
      }
    });

    test('todo signo tiene lore', () {
      for (final sign in signEs.keys) {
        expect(
          signLore[sign],
          isNotNull,
          reason: 'falta el lore del signo "$sign"',
        );
      }
    });

    test('los clásicos conservan día, metal y sephirah', () {
      for (final planet in const [
        'sun',
        'moon',
        'mars',
        'mercury',
        'venus',
        'jupiter',
        'saturn',
      ]) {
        final lore = planetLore[planet]!;
        expect(lore.dia, isNotNull, reason: '"$planet" sin día regente');
        expect(lore.metal, isNotNull, reason: '"$planet" sin metal');
        expect(lore.sephirah, isNotNull, reason: '"$planet" sin sephirah');
      }
    });

    test('los modernos y el Nodo no inventan correspondencias clásicas', () {
      for (final planet in const ['uranus', 'neptune', 'pluto', 'north_node']) {
        final lore = planetLore[planet]!;
        expect(
          lore.dia,
          isNull,
          reason: '"$planet" no rige ningún día en la tradición clásica',
        );
        expect(lore.metal, isNull, reason: '"$planet" no tiene metal asignado');
        expect(lore.descripcion.trim(), isNotEmpty);
        expect(lore.correspondencias, isNotEmpty);
      }
    });
  });
}
