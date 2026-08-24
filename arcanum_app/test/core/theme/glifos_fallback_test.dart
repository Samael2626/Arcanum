import 'dart:io';

import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Los signos del zodíaco y los glifos planetarios NO están en Cormorant
/// Garamond ni en Crimson Pro. Comprobado leyendo su tabla `cmap`: **0 de 12 en
/// las dos**. Sin un respaldo declarado, cada dispositivo decide qué fuente los
/// pinta — y en algunos Android eso significa emoji de colores dentro de la
/// rueda natal.
///
/// Es un fallo que NO se ve en CI ni en el emulador de quien lo escribió: se ve
/// en el teléfono de otra persona. Por eso está aquí.
void main() {
  group('respaldo de glifos', () {
    test('el fallback nombra la fuente de símbolos', () {
      expect(kGlyphFallback, contains('Noto Sans Symbols'));
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
          contains('Noto Sans Symbols'),
          reason: 'ArcanumText.$nombre no declara el respaldo de glifos',
        );
      });
    });

    test('el tema lo propaga al textTheme', () {
      final tema = buildArcanumTheme();
      expect(
        tema.textTheme.bodyMedium?.fontFamilyFallback,
        contains('Noto Sans Symbols'),
      );
    });

    test('la fuente está declarada en pubspec y el fichero existe', () {
      // Declararla en el tema sin empaquetarla deja el fallback en nada: Flutter
      // no avisa, simplemente no la encuentra.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec,
        contains('family: Noto Sans Symbols'),
        reason: 'la familia no está declarada en pubspec.yaml',
      );
      expect(
        pubspec,
        contains('assets/fonts/NotoSansSymbols-Regular.ttf'),
        reason: 'el asset de la fuente no está declarado',
      );
      expect(
        File('assets/fonts/NotoSansSymbols-Regular.ttf').existsSync(),
        isTrue,
        reason: 'falta el fichero de la fuente',
      );
      // La OFL obliga a distribuir el texto de la licencia junto a la fuente.
      expect(
        File('assets/fonts/NotoSansSymbols-OFL.txt').existsSync(),
        isTrue,
        reason: 'falta el texto de la licencia OFL junto a la fuente',
      );
    });
  });
}
