// Pantalla del taller en la app: forjar, radial, deshacer, guardar cifrado en
// el Grimorio (sin la intencion en el titulo) y la entrada vista desde el
// Grimorio (editor y detalle).
import 'dart:convert';

import 'package:arcanum_app/features/grimorio/grimorio_detail.dart';
import 'package:arcanum_app/features/grimorio/grimorio_editor.dart';
import 'package:arcanum_app/features/sigilos/sigil_store.dart';
import 'package:arcanum_app/features/sigilos/taller_screen.dart';
import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'taller_fakes.dart';

/// El panel del taller es una lista vertical: se arrastra con el dedo hasta que
/// el rotulo entra en la zona visible (entre la barra de pestañas y el pie).
Finder get _panelVertical => find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical).first;
Future<void> _llevarA(WidgetTester t, String r) async {
  final alto = t.view.physicalSize.height / t.view.devicePixelRatio;
  for (var n = 0; n < 20; n++) {
    final y = t.getRect(find.text(r)).center.dy;
    if (y > 520 && y < alto - 80) return;
    await t.drag(_panelVertical, Offset(0, y >= alto - 80 ? -250 : 250));
    await t.pumpAndSettle();
  }
  fail('no se pudo llevar «$r» a la zona visible');
}
Future<void> _bajarA(WidgetTester t, String r) => _llevarA(t, r);
Future<void> _subirA(WidgetTester t, String r) => _llevarA(t, r);

const _intencion = 'Mi práctica mantiene enfoque sereno';

Future<TallerScreenState> _forjar(WidgetTester tester, FakeApi api) async {
  phoneView(tester);
  await tester.pumpWidget(tallerApp(const TallerScreen(), api));
  expect(find.text('Escribe tu intención y pulsa «Forjar».'), findsOneWidget);
  await tester.enterText(find.byType(TextField).first, _intencion);
  await tester.tap(find.text('Forjar'));
  await tester.pump();
  return tester.state<TallerScreenState>(find.byType(TallerScreen));
}

/// Punto de pantalla sobre un trazo propio de una letra.
Offset _sobreLetra(WidgetTester tester, SigilDoc doc) {
  final p = doc.sigil.prims.firstWhere((q) => q.units.length == 1 && q is LinePrim) as LinePrim;
  final a = doc.sigil.view!.toCanvas(p.a), b = doc.sigil.view!.toCanvas(p.b);
  final r = tester.getRect(find.byType(SigilCanvas));
  return Offset(r.left + (a.x + b.x) / 2 * r.width / kSize, r.top + (a.y + b.y) / 2 * r.width / kSize);
}

void main() {
  testWidgets('forjar dibuja el sigilo con el mismo motor que el prototipo', (tester) async {
    final st = await _forjar(tester, FakeApi());
    expect(find.text('Escribe tu intención y pulsa «Forjar».'), findsNothing);
    final ref = SigilDoc()..generate(_intencion);
    expect(st.debugDoc.buildSVG(), ref.buildSVG());
  });

  testWidgets('tocar una letra abre su radial; girar cambia el sigilo y deshacer lo devuelve', (tester) async {
    final st = await _forjar(tester, FakeApi());
    final antes = st.debugDoc.buildSVG();
    await tester.tapAt(_sobreLetra(tester, st.debugDoc));
    await tester.pump();
    expect(find.byTooltip('Girar +15°'), findsOneWidget);
    expect(find.byTooltip('Restaurar la letra'), findsOneWidget);
    await tester.tap(find.byTooltip('Girar +15°'));
    await tester.pump();
    expect(st.debugDoc.buildSVG(), isNot(antes));
    await tester.tap(find.byTooltip('Deshacer'));
    await tester.pump();
    expect(st.debugDoc.buildSVG(), antes);
    await tester.tap(find.byTooltip('Rehacer'));
    await tester.pump();
    expect(st.debugDoc.buildSVG(), isNot(antes));
  });

  testWidgets('los botones del radial y del lienzo miden 48 px', (tester) async {
    final st = await _forjar(tester, FakeApi());
    await tester.tapAt(_sobreLetra(tester, st.debugDoc));
    await tester.pump();
    for (final t in ['Girar −15°', 'Girar +15°', 'Reflejo horizontal', 'Reflejo vertical', 'Reducir', 'Ampliar', 'Restaurar la letra', 'Añadir']) {
      final size = tester.getSize(find.byTooltip(t).first);
      expect(size.width >= 48 && size.height >= 48, isTrue, reason: '$t mide $size');
    }
  });

  testWidgets('el boton + añade una estrella y el radial pasa a la capa', (tester) async {
    final st = await _forjar(tester, FakeApi());
    await tester.tap(find.byTooltip('Añadir'));
    await tester.pump();
    await tester.tap(find.byTooltip('Estrella'));
    await tester.pump();
    expect(st.debugDoc.layers.single.type, LayerType.star);
    expect(find.byTooltip('Quitar'), findsOneWidget);
    await tester.tap(find.byTooltip('Quitar'));
    await tester.pump();
    expect(st.debugDoc.layers, isEmpty);
  });

  testWidgets('un estilo de la pestaña Estilo cambia el sigilo', (tester) async {
    final st = await _forjar(tester, FakeApi());
    await tester.tap(find.text('Estilo'));
    await tester.pump();
    await tester.tap(find.text('Oro y negro'));
    await tester.pump();
    expect(st.debugDoc.style.preset, 'oro');
    expect(st.debugDoc.buildSVG(), contains('#c99a1a'));
  });

  testWidgets('Caligrafía: Pluma y Curva cambian cómo se pinta, un estilo no la borra y se guarda', (tester) async {
    final api = FakeApi();
    final st = await _forjar(tester, api);
    final recta = st.debugDoc.buildSVG();
    await tester.tap(find.text('Estilo'));
    await tester.pump();
    await tester.tap(find.text('Ajustar'));
    await tester.pumpAndSettle();

    // los tres rotulos se pueden tocar (>= 48 dp)
    for (final r in ['Recta', 'Curva', 'Pluma']) {
      final caja = tester.getRect(find.ancestor(of: find.text(r), matching: find.byType(ChoiceChip)).first);
      expect(caja.height, greaterThanOrEqualTo(48), reason: r);
    }

    await _bajarA(tester, 'Pluma');
    await tester.tap(find.text('Pluma'));
    await tester.pump();
    expect(st.debugDoc.style.calli, 'pluma');
    final pluma = st.debugDoc.buildSVG();
    expect(pluma, contains('data-layer="pluma"'));
    expect(pluma, isNot(equals(recta)));

    await _bajarA(tester, 'Curva');
    await tester.tap(find.text('Curva'));
    await tester.pump();
    expect(st.debugDoc.buildSVG(), contains(' Q '));

    // cambiar de estilo conserva la caligrafia
    await _subirA(tester, 'Oro y negro');
    await tester.tap(find.text('Oro y negro'));
    await tester.pump();
    expect(st.debugDoc.style.preset, 'oro');
    expect(st.debugDoc.style.calli, 'curva');

    // y vuelve a Recta con el SVG exacto del principio (mismo estilo base)
    await _bajarA(tester, 'Recta');
    await tester.tap(find.text('Recta'));
    await tester.pump();
    expect(st.debugDoc.style.calli, 'none');
    expect(st.debugDoc.buildSVG(), isNot(contains(' Q ')));

    // se guarda con el documento y se abre igual
    await _bajarA(tester, 'Pluma');
    await tester.tap(find.text('Pluma'));
    await tester.pump();
    final antes = st.debugDoc.buildSVG();
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    await tester.tap(find.text('Guardar en el Grimorio'));
    await tester.pumpAndSettle();
    final doc = (decodeSigilEntry(utf8.decode(base64Decode(api.created.single['encrypted_content'] as String))) as SigilReadable).entry.doc;
    expect(doc.style.calli, 'pluma');
    expect(doc.buildSVG(), antes);
  });

  testWidgets('guardar cifra el documento entero y el titulo no lleva la intencion', (tester) async {
    final api = FakeApi();
    final st = await _forjar(tester, api);
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    await tester.tap(find.text('Guardar en el Grimorio'));
    await tester.pumpAndSettle();
    final body = api.created.single;
    expect(body['entry_type'], 'sigil');
    expect(body['title'] as String, startsWith('Sigilo del '));
    expect((body['title'] as String).toLowerCase(), isNot(contains('práctica')));
    expect(body['moon_phase'], 'Creciente');
    final doc = (decodeSigilEntry(utf8.decode(base64Decode(body['encrypted_content'] as String))) as SigilReadable).entry.doc;
    expect(doc.sigil.intention, _intencion);
    expect(doc.buildSVG(), st.debugDoc.buildSVG());
    // guardar otra vez reescribe la misma entrada (antes se va el aviso, que tapa el boton)
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(api.updated.single.$1, 'sigilo-1');
    expect(api.created, hasLength(1));
  });

  testWidgets('en el editor del Grimorio, «Sigilo» lleva al taller en vez de al texto', (tester) async {
    phoneView(tester);
    await tester.pumpWidget(tallerApp(const GrimorioEditor(), FakeApi()));
    expect(find.text('Sellar entrada'), findsOneWidget);
    await tester.tap(find.text('Sigilo'));
    await tester.pump();
    expect(find.text('Abrir el taller'), findsOneWidget);
    expect(find.text('Sellar entrada'), findsNothing);
    await tester.tap(find.text('Abrir el taller'));
    await tester.pumpAndSettle();
    expect(find.byType(TallerScreen), findsOneWidget);
  });

  testWidgets('el detalle dibuja el sigilo; la intencion queda oculta hasta pedirla', (tester) async {
    phoneView(tester);
    final doc = SigilDoc()..generate(_intencion);
    final enc = await FakeCrypto().encryptText(encodeSigilEntry(SigilEntry(doc)));
    final api = FakeApi()
      ..detail = {'id': 'sigilo-1', 'entry_type': 'sigil', 'title': 'Sigilo del 30 de septiembre', 'encrypted_content': enc.ciphertext, 'content_iv': enc.iv, 'moon_phase': 'Creciente', 'entry_date': '2026-09-30T10:00:00Z'};
    await tester.pumpWidget(tallerApp(const GrimorioDetail(id: 'sigilo-1'), api));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Seguir en el taller'), findsOneWidget);
    expect(find.textContaining(_intencion), findsNothing);
    await tester.ensureVisible(find.text('Ver la intención'));
    await tester.tap(find.text('Ver la intención'));
    await tester.pump();
    expect(find.textContaining(_intencion), findsOneWidget);
  });

  testWidgets('una entrada «Sigilo» escrita a mano antes del taller sigue siendo texto', (tester) async {
    phoneView(tester);
    final enc = await FakeCrypto().encryptText('Dibujé un sigilo con las letras de mi nombre.');
    final api = FakeApi()
      ..detail = {'id': 'viejo', 'entry_type': 'sigil', 'title': 'Mi sigilo', 'encrypted_content': enc.ciphertext, 'content_iv': enc.iv, 'entry_date': '2026-09-01T10:00:00Z'};
    await tester.pumpWidget(tallerApp(const GrimorioDetail(id: 'viejo'), api));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.textContaining('Dibujé un sigilo'), findsOneWidget);
    expect(find.text('Seguir en el taller'), findsNothing);
  });
}
