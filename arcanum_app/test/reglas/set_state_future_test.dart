// Regla aprendida (grimorio_detail el 5-oct; cielos y lecturas el 7-oct): una
// flecha que asigna un Future dentro de setState devuelve ese Future a
// setState, y en depuracion lanza. Se escribe con llaves.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ningun setState devuelve un Future (flecha que asigna una carga)', () {
    // lo que devuelve un Future: un campo *future*, una carga (_load...) o Future.algo
    final malo = RegExp(r'setState\(\(\)\s*=>\s*(_\w*[Ff]uture\w*\s*=|_\w+\s*=\s*(_?load\w*\(|Future\.))');
    final hallados = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final lineas = f.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        if (malo.hasMatch(lineas[i])) hallados.add('${f.path}:${i + 1}');
      }
    }
    expect(hallados, isEmpty, reason: 'usar setState(() { _x = carga(); })');
  });
}
