import 'dart:io';
import 'dart:ui' as ui;

import 'package:arcanum_app/features/saber/sellos/sello_modelo.dart';
import 'package:arcanum_app/features/saber/sellos/sello_painter.dart';
import 'package:arcanum_sigilos/arcanum_sigilos.dart' show pathOf;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// Contrato del catálogo histórico: los mismos invariantes que
/// `_verify_export.mjs` del prototipo, comprobados sobre el asset que viaja
/// en la app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CatalogoSellos cat;

  setUpAll(() async {
    cat = CatalogoSellos.parse(
      await rootBundle.loadString(CatalogoSellos.assetPath),
    );
  });

  test('la app contiene solo las 23 piezas de Agrippa', () {
    expect(cat.items, hasLength(23));
    expect(cat.de('agrippa1651'), hasLength(23));
    expect(cat.de('goetia1916'), isEmpty);
    expect(cat.sources.keys, contains('agrippa1651'));
    expect(cat.sources.keys, isNot(contains('goetia1916')));
    expect({for (final p in cat.items) p.id}, hasLength(23));
  });

  test('el catalogo no incluye parejas ni rangos goeticos', () {
    expect(cat.goetiaRanks, isEmpty);
    for (final p in cat.items) {
      expect(cat.pareja(p), isNull);
    }
  });

  test('cada pieza cita fuente, edición, escaneo y licencia', () {
    for (final p in cat.items) {
      final f = cat.fuenteDe(p);
      expect(f.work, isNotEmpty, reason: p.id);
      expect(f.edition, isNotEmpty, reason: p.id);
      expect(f.scan, isNotEmpty, reason: p.id);
      expect(f.license, isNotEmpty, reason: p.id);
      expect(p.scanUrl, startsWith('https://archive.org/details/'));
      expect(p.page, greaterThan(0));
      expect(p.leaf, greaterThan(0));
    }
  });

  test('Agrippa: planeta y tipo por pieza', () {
    for (final p in cat.de('agrippa1651')) {
      expect(p.planet, isNotNull, reason: p.id);
      expect(p.kind, isNotNull, reason: p.id);
    }
    expect(cat.items.every((p) => p.source == 'agrippa1651'), isTrue);
  });

  test('el asset es idéntico al export del prototipo (sin deriva)', () {
    final f = File('../arcanum-sigil-prototype/export/catalogo-sellos.json');
    if (!f.existsSync()) return; // fuera del monorepo no hay con qué comparar
    expect(
      File(CatalogoSellos.assetPath).readAsStringSync(),
      f.readAsStringSync(),
    );
  });

  test('los 23 trazos se parsean y caen dentro de la caja del escaneo', () {
    for (final p in cat.items) {
      expect(p.paths, isNotEmpty, reason: p.id);
      var caja = Rect.zero;
      var primero = true;
      for (final (d, tx, ty) in p.paths) {
        final b = pathOf(d).getBounds().shift(Offset(tx, ty));
        expect(b.isFinite, isTrue, reason: p.id);
        caja = primero ? b : caja.expandToInclude(b);
        primero = false;
      }
      // margen del 3 % por el calco; fuera de eso el dibujo se saldría
      final m = 0.03 * (p.w > p.h ? p.w : p.h);
      expect(caja.left, greaterThanOrEqualTo(-m), reason: '${p.id} $caja');
      expect(caja.top, greaterThanOrEqualTo(-m), reason: '${p.id} $caja');
      expect(caja.right, lessThanOrEqualTo(p.w + m), reason: '${p.id} $caja');
      expect(caja.bottom, lessThanOrEqualTo(p.h + m), reason: '${p.id} $caja');
    }
  });

  test(
    'el pintor deja tinta en las 23 piezas y respeta el recuadro',
    () async {
      for (final p in cat.items) {
        final rec = ui.PictureRecorder();
        SelloPainter(
          p,
          Colors.black,
          margen: 4,
        ).paint(Canvas(rec), const Size(96, 96));
        final img = await rec.endRecording().toImage(96, 96);
        final bytes = (await img.toByteData())!.buffer.asUint8List();
        var tinta = 0;
        for (var i = 3; i < bytes.length; i += 4) {
          if (bytes[i] > 128) tinta++;
        }
        expect(tinta, greaterThan(20), reason: '${p.id} no deja tinta');
        // el margen de 4 px queda vacío en el borde exterior
        for (var x = 0; x < 96; x++) {
          for (final y in [0, 1, 94, 95]) {
            expect(
              bytes[(y * 96 + x) * 4 + 3],
              0,
              reason: '${p.id} pinta fuera',
            );
          }
        }
      }
    },
  );
}
