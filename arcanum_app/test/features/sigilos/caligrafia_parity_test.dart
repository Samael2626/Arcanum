// Paridad de la caligrafia (curva y pluma) con el prototipo: el SVG que
// exporta Dart es el del navegador y el lienzo pinta lo mismo que el SVG.
// Casos: _fixtures_calli.mjs -> caligrafia.json y png_calli/
import 'dart:convert';
import 'dart:io';

import 'package:arcanum_sigilos/engine/style.dart';
import 'package:arcanum_sigilos/ui/scene_painter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'painter_parity_test.dart'
    show decodePng, diffPct, kMaxPct, painterImage;
import 'svg_parity_test.dart' show diffSvg, docFor;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cases =
      ((jsonDecode(
                    File(
                      'test/features/sigilos/fixtures/caligrafia.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>)['svgs']
              as List)
          .cast<Map<String, dynamic>>();
  final pngs =
      Directory(
          'test/features/sigilos/fixtures/png_calli',
        ).listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  String nombre(Map<String, dynamic> c) {
    final st = c['style'] as Map<String, dynamic>;
    return '${c['text']} · ${c['mode']} · ${(c['layers'] as List).length} capas · ${st['calli']} · ${st['preset']}'
        '${st['line'] == 'double' ? ' doble' : ''}${st['relief'] == true ? ' relieve' : ''}${st['glow'] == true ? ' resplandor' : ''}'
        ' · remate ${c['terminals']}${(c['endStyles'] as Map).isNotEmpty ? ' + uno' : ''}';
  }

  test(
    'hay referencias de las dos caligrafias con relieve, resplandor y doble',
    () {
      final cal = cases.map((c) => (c['style'] as Map)['calli']).toSet();
      expect(cal, {'curva', 'pluma'});
      for (final k in ['curva', 'pluma']) {
        final de = cases.where((c) => (c['style'] as Map)['calli'] == k);
        expect(
          de.any((c) => (c['style'] as Map)['relief'] == true),
          isTrue,
          reason: k,
        );
        expect(
          de.any((c) => (c['style'] as Map)['glow'] == true),
          isTrue,
          reason: k,
        );
        expect(
          de.any((c) => (c['style'] as Map)['line'] == 'double'),
          isTrue,
          reason: k,
        );
      }
      expect(pngs.length, greaterThan(10));
    },
  );

  test('la caligrafia viaja en el JSON del estilo y por defecto es recta', () {
    const st = SigilStyle(calli: 'pluma');
    expect(SigilStyle.fromJson(st.toJson()).calli, 'pluma');
    expect(const SigilStyle().calli, 'none');
    expect(st.copyWith(width: 120).calli, 'pluma');
    // un guardado anterior a la caligrafia no la trae: se abre recto
    final viejo = const SigilStyle().toJson()..remove('calli');
    expect(SigilStyle.fromJson(viejo).calli, 'none');
  });

  for (final c in cases) {
    test('SVG = prototipo · ${nombre(c)}', () {
      expect(diffSvg(docFor(c).buildSVG(), c['svg'] as String), isNull);
    });
  }

  for (final f in pngs) {
    final i = int.parse(RegExp(r'cal(\d+)\.png').firstMatch(f.path)![1]!);
    testWidgets('lienzo = SVG en el navegador · ${nombre(cases[i])}', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final doc = docFor(cases[i]);
        final s = doc.scene(transparent: doc.transparent);
        final got = await painterImage([s.bg, s.fg], 400);
        final ref = await decodePng(f.readAsBytesSync());
        final pct = await diffPct(got, ref);
        expect(
          pct,
          lessThan(kMaxPct),
          reason: '${pct.toStringAsFixed(3)} % de pixeles distintos',
        );
      });
    });
  }

  test('la pluma pinta rellenos y la curva trazos', () {
    final pluma = cases.firstWhere(
      (c) =>
          (c['style'] as Map)['calli'] == 'pluma' &&
          (c['style'] as Map)['glow'] != true &&
          (c['style'] as Map)['relief'] != true,
    );
    final s = docFor(pluma).scene();
    final capa = s.fg.firstWhere((g) => g.layer == 'pluma');
    expect(capa.items.every((it) => it.fill), isTrue);
    expect(capa.w, isNull);
    expect(s.fg.any((g) => g.layer == 'core'), isFalse);
    final curva = cases.firstWhere(
      (c) => (c['style'] as Map)['calli'] == 'curva',
    );
    final core = docFor(curva).scene().fg.firstWhere((g) => g.layer == 'core');
    expect(core.items.any((it) => it.d.contains(' Q ')), isTrue);
    expect(pathOf(core.items.first.d).getBounds().isFinite, isTrue);
  });
}
