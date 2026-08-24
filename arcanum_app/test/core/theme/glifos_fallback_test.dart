import 'dart:io';

import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ni Cormorant Garamond ni Crimson Pro traen los signos del zodíaco ni los
/// glifos planetarios. Comprobado leyendo su tabla `cmap`: **1 de los 39 que
/// usa `lib/`**. Sin un respaldo declarado, cada dispositivo decide qué fuente
/// los pinta — y en varios Android eso significa emoji de colores dentro de la
/// rueda natal.
///
/// Es un fallo que NO se ve en CI ni en el emulador de quien lo escribió: se ve
/// en el teléfono de otra persona. Por eso está aquí.
///
/// El test importante es el último: **vuelve a escanear `lib/`** y compara con
/// el manifiesto. Las fuentes van recortadas a los glifos que se usan, así que
/// estrenar uno nuevo lo deja fuera del paquete — y sin este test, en silencio.
void main() {
  group('respaldo de glifos', () {
    test('el fallback nombra las cuatro familias, en orden', () {
      // El orden es el diseño: Libertinus primero porque es la única serif del
      // grupo. Si alguien la mueve, los signos pasan a verse geométricos y
      // fríos junto a Cormorant sin que nadie sepa por qué.
      expect(kGlyphFallback, [
        'ArcanumGlifos',
        'ArcanumGlifosB',
        'ArcanumGlifosC',
        'ArcanumGlifosD',
      ]);
    });

    test('todos los estilos del sistema lo declaran', () {
      // Si un estilo se queda sin fallback, sus glifos vuelven a depender del
      // dispositivo y nadie se entera hasta ver una captura ajena.
      final estilos = <String, TextStyle>{
        'wordmark': ArcanumText.wordmark(),
        'heading': ArcanumText.heading(20),
        'body': ArcanumText.body(14),
        'label': ArcanumText.label(),
      };
      estilos.forEach((nombre, estilo) {
        expect(
          estilo.fontFamilyFallback,
          kGlyphFallback,
          reason: 'ArcanumText.$nombre no declara el respaldo de glifos',
        );
      });
    });

    test('el tema lo propaga al textTheme', () {
      final tema = buildArcanumTheme();
      expect(tema.textTheme.bodyMedium?.fontFamilyFallback, kGlyphFallback);
    });

    test('cada familia está declarada en pubspec y su fichero existe', () {
      // Declararlas en el tema sin empaquetarlas deja el fallback en nada:
      // Flutter no avisa, simplemente no las encuentra.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final familia in kGlyphFallback) {
        expect(
          pubspec,
          contains('family: $familia'),
          reason: '$familia no está declarada en pubspec.yaml',
        );
      }
      final ficheros = Directory('assets/fonts')
          .listSync()
          .map((e) => e.path.split(Platform.pathSeparator).last)
          .toList();
      for (final familia in kGlyphFallback) {
        expect(
          ficheros.any((f) => f.startsWith('$familia-Regular.')),
          isTrue,
          reason: 'falta el fichero de $familia',
        );
      }
      // La OFL obliga a distribuir el texto de la licencia junto a la fuente.
      // Son dos proyectos distintos: Libertinus y Noto.
      expect(File('assets/fonts/OFL-Libertinus.txt').existsSync(), isTrue);
      expect(File('assets/fonts/OFL-Noto.txt').existsSync(), isTrue);
    });

    test('ningún glifo de lib/ se quedó fuera del paquete', () {
      // Esta es la guarda de verdad. Las fuentes están recortadas: traen SOLO
      // los glifos que el código usaba el día que se generaron. Estrenar uno
      // nuevo no rompe nada visible aquí — se ve mal en el teléfono de otro.
      //
      // Si se pone rojo: correr `python tool/generar_fuente_glifos.py`.
      final manifiesto = File('assets/fonts/glifos_manifest.txt')
          .readAsLinesSync()
          .where((l) => l.startsWith('U+'))
          .map((l) => int.parse(l.substring(2).split(' ').first, radix: 16))
          .toSet();
      expect(manifiesto, isNotEmpty, reason: 'el manifiesto está vacío');

      // Mismo rango y mismo criterio que el generador: solo símbolos. Fuera
      // quedan flechas y cuadros de dibujo, que viven en comentarios.
      final escape = RegExp(r'\\u\{?([0-9A-Fa-f]{4,5})\}?');
      final usados = <int, String>{};
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final texto = f.readAsStringSync();
        final puntos = <int>[
          ...texto.runes,
          ...escape.allMatches(texto).map(
                (m) => int.parse(m.group(1)!, radix: 16),
              ),
        ];
        for (final p in puntos) {
          if (p >= 0x2600 && p <= 0x2BFF) usados.putIfAbsent(p, () => f.path);
        }
      }

      final fuera = usados.keys.where((p) => !manifiesto.contains(p)).toList();
      expect(
        fuera,
        isEmpty,
        reason: 'glifos sin fuente empaquetada — correr '
            'tool/generar_fuente_glifos.py: '
            '${fuera.map((p) => 'U+${p.toRadixString(16).toUpperCase()} '
                '${String.fromCharCode(p)} (${usados[p]})').join(', ')}',
      );
    });
  });
}
