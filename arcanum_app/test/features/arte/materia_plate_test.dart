import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:arcanum_app/features/arte/materia_plate_loader.dart';
import 'package:flutter_test/flutter_test.dart';

/// El manifest de laminas, leido del fichero igual que lo lee el bundle.
Map<String, dynamic> _manifest() =>
    json.decode(File('assets/materia/manifest.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('manifest de laminas de Materia', () {
    test('cubre las 39 piezas verificadas: 27 hierbas y 12 signos', () {
      final m = _manifest();
      expect(m, hasLength(39));
      final tipos = <String, int>{};
      for (final v in m.values) {
        final t = (v as Map<String, dynamic>)['tipo'] as String;
        tipos[t] = (tipos[t] ?? 0) + 1;
      }
      expect(tipos, {'herb': 27, 'sign': 12});
    });

    test('cada pieza declara sus dos caras, y los ficheros existen', () {
      for (final entrada in _manifest().entries) {
        final v = entrada.value as Map<String, dynamic>;
        for (final cara in ['entonado', 'grabado']) {
          final ruta = v[cara] as String;
          expect(ruta, endsWith('.webp'), reason: '${entrada.key}/$cara');
          expect(File('assets/$ruta').existsSync(), isTrue,
              reason: 'falta assets/$ruta');
        }
      }
    });

    test('toda pieza trae procedencia y licencia: es la prueba de uso', () {
      for (final entrada in _manifest().entries) {
        final v = entrada.value as Map<String, dynamic>;
        expect(v['license'], 'public-domain', reason: entrada.key);
        expect(v['obra'], isNotEmpty, reason: entrada.key);
        expect(v['source'], startsWith('https://commons.wikimedia.org/'),
            reason: entrada.key);
      }
    });
  });

  group('MateriaPlates', () {
    setUpAll(() => MateriaPlates.instance.ensureLoaded());

    test('resuelve el slug del asset', () async {
      await MateriaPlates.instance.ensureLoaded();
      final ruda = MateriaPlates.instance.resolve('ruda');
      expect(ruda, isNotNull);
      expect(ruda!.entonadoPath, 'assets/materia/entonado/ruda.webp');
      expect(ruda.grabadoPath, 'assets/materia/grabado/ruda.webp');
    });

    test('resuelve el slug del catalogo, con tilde y con prefijo', () async {
      await MateriaPlates.instance.ensureLoaded();
      // El catalogo guarda 'beleño' y los signos van prefijados. Las dos
      // formas tienen que llegar a la misma lamina, o la pieza se queda sin
      // arte sin que nadie se entere.
      expect(MateriaPlates.instance.resolve('Beleño')?.slug, 'beleno');
      expect(MateriaPlates.instance.resolve('signo-aries')?.slug, 'aries');
      expect(MateriaPlates.instance.resolve('aries')?.slug, 'aries');
    });

    test('devuelve null para una pieza sin lamina comprobada', () async {
      await MateriaPlates.instance.ensureLoaded();
      // Piedras y metales siguen fuera: su fuente es CC-BY-SA sin resolver.
      expect(MateriaPlates.instance.resolve('amatista'), isNull);
      expect(MateriaPlates.instance.resolve('oro'), isNull);
    });

    test('el credito nombra autor y obra cuando hay autor', () async {
      await MateriaPlates.instance.ensureLoaded();
      final aries = MateriaPlates.instance.resolve('signo-aries')!;
      expect(aries.credito, contains('Bayer'));
      expect(aries.credito, contains('Uranometria'));
    });
  });

  group('las laminas llegan a la pantalla', () {
    // Es un test normal y no un testWidgets a proposito: decodificar necesita
    // reloj de verdad, y dentro de testWidgets hay que pedirlo con runAsync
    // sobre un bundle que los tests de arriba ya dejaron cargado -- ahi se
    // queda colgado hasta el limite de diez minutos.
    test('un signo trae lamina raster y se decodifica', () async {
      // La regresion que esto vigila: el manifest apuntaba a un .jpg que se
      // cargaba con SvgPicture.asset, no se parseaba nunca y los doce signos
      // caian al grabado procedural sin un solo error en consola.
      await MateriaPlates.instance.ensureLoaded();
      final aries = MateriaPlates.instance.resolve('signo-aries')!;
      expect(aries.entonadoPath, endsWith('.webp'));

      // La lamina se decodifica de verdad, que es lo que el .jpg servido a
      // SvgPicture nunca llego a hacer. Se comprueba el codec y no un arbol de
      // widgets: montar la imagen obliga a precargarla a mano dentro de
      // runAsync y lo unico que se sabria de mas es que Image.asset pinta.
      final codec = await instantiateImageCodec(
        File(aries.entonadoPath).readAsBytesSync(),
      );
      final fotograma = await codec.getNextFrame();
      expect(fotograma.image.width, greaterThan(0));
      fotograma.image.dispose();
      codec.dispose();
    });
  });
}
