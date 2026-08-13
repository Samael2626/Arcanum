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
