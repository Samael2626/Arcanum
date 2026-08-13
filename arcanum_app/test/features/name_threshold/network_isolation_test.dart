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

  test('Tarot y Cielos no dependen del perfil de lectura', () {
    for (final path in ['lib/features/tarot', 'lib/features/cielos']) {
      final source = Directory(path)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');
      expect(source, isNot(contains('name_threshold')));
      expect(source, isNot(contains('readingIdentityProvider')));
    }
  });
}
