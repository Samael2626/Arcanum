import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// P0: ningun lugar por defecto, en ningun sitio.
///
/// Bogota estuvo hardcodeada en `ArcanumApi.today()` como valor por defecto de
/// `lat`/`lon`. Toda la app mostraba la hora planetaria de un meridiano ajeno
/// sin que nada lo insinuara. Este test fija la ausencia por ruta, no por
/// memoria: si alguien vuelve a escribir unas coordenadas en el codigo, falla.
void main() {
  List<File> dartFiles(String path) => Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList(growable: false);

  test('ningun archivo de lib lleva las coordenadas de Bogota', () {
    // Las de la version anterior y sus redondeos mas probables.
    const agujas = ['4.71', '-74.07', '4.6097', '-74.0817'];
    for (final file in dartFiles('lib')) {
      final source = file.readAsStringSync();
      for (final aguja in agujas) {
        expect(
          source,
          isNot(contains(aguja)),
          reason: '${file.path} vuelve a traer un lugar inventado',
        );
      }
    }
  });

  test('today() exige lugar: no tiene coordenadas por defecto', () {
    final source = File('lib/core/api/arcanum_api.dart').readAsStringSync();
    final firma = RegExp(
      r'Future<Map<String, dynamic>> today\(\{(.*?)\}\)',
      dotAll: true,
    ).firstMatch(source);

    expect(firma, isNotNull, reason: 'la firma de today() cambio de forma');
    final parametros = firma!.group(1)!;
    expect(parametros, contains('required double lat'));
    expect(parametros, contains('required double lon'));
    // Un parametro con `=` en la firma es un valor por defecto: lo unico que
    // puede volver a colar un lugar sin que nadie lo pida.
    expect(parametros, isNot(contains('=')));
  });

  test('el lugar confirmado sale del perfil o no existe', () {
    final source = File(
      'lib/core/state/confirmed_place.dart',
    ).readAsStringSync();

    expect(source, contains("user['birth_lat']"));
    expect(source, contains("user['birth_lon']"));
    // Ni un fallback: si falta una de las dos, no hay lugar.
    expect(source, contains('if (lat == null || lon == null) return null;'));
    expect(source, isNot(contains('??  4')));
  });

  test('nadie llama a today() sin pasarle un lugar', () {
    final llamada = RegExp(r'\.today\(\s*\)');
    for (final file in dartFiles('lib')) {
      // Los comentarios quedan fuera: la documentacion del bug cita la firma
      // vieja a proposito, y un test que la prohibiera obligaria a borrar la
      // explicacion de por que existe el test.
      final codigo = file
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        llamada.hasMatch(codigo),
        isFalse,
        reason: '${file.path} pide el cielo sin decir de donde',
      );
    }
  });
}
