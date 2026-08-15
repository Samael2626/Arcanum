import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('modulo Nombre y Umbral no importa clientes HTTP ni analytics', () {
    final root = Directory('lib/features/name_threshold');
    final source = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(source, isNot(contains("package:dio/")));
    expect(source, isNot(contains("package:http/")));
    expect(source, isNot(contains('firebase_analytics')));
    expect(source, isNot(contains('firebase_crashlytics')));
    expect(source, isNot(contains('ArcanumApi')));
    expect(source, isNot(contains('package:cloud_firestore/')));
    expect(source, isNot(contains('HttpClient')));
    expect(source, isNot(contains('logEvent')));
  });

  test('el catalogo y la cola de apellidos no dependen de red ni de Flutter UI', () {
    for (final path in [
      'lib/features/name_threshold/data/name_catalog.dart',
      'lib/features/name_threshold/data/name_sources.dart',
      'lib/features/name_threshold/data/surname_queue.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('dart:io')), reason: path);
      expect(source, isNot(contains('package:flutter/material.dart')),
          reason: path);
    }
  });

  // La frontera de la fase anterior era "Tarot y Cielos no pueden nombrar el
  // modulo". Con los Puentes del Umbral pasa a ser "solo pueden nombrar la
  // puerta": la unica ruta importable es `name_threshold/bridge.dart`, que
  // exporta la resonancia ya recortada y el provider que la cierra. El perfil,
  // el almacenamiento cifrado, el controlador, el catalogo y el conversor
  // fonetico siguen fuera de su alcance, y ahora el test lo fija por ruta en
  // vez de por ausencia.
  group('los modulos receptores solo cruzan por la puerta declarada', () {
    const consumers = [
      'lib/features/tarot',
      'lib/features/cielos',
      'lib/features/oraculo',
    ];

    String sourceOf(String path) => Directory(path)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    test('ningun receptor importa nada del modulo salvo bridge.dart', () {
      final imports = RegExp(r"import '[^']*name_threshold/([^']*)'");
      for (final path in consumers) {
        final found = imports
            .allMatches(sourceOf(path))
            .map((match) => match.group(1)!)
            .toSet();
        expect(
          found.difference({'bridge.dart'}),
          isEmpty,
          reason: '$path importa rutas internas del modulo',
        );
      }
    });

    test('ningun receptor alcanza el perfil ni su almacenamiento', () {
      for (final path in consumers) {
        final source = sourceOf(path);
        for (final forbidden in [
          'readingIdentityProvider',
          'ReadingIdentityProfile',
          'ReadingIdentityRepository',
          'ReadingNamePart',
          'ConfirmedHebrewForm',
          'NameCatalog',
          'HebrewGematria',
          'SpanishHebrewConverter',
        ]) {
          expect(source, isNot(contains(forbidden)), reason: '$path · $forbidden');
        }
      }
    });
  });
}
