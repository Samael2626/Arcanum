// Mejoras pensadas para el movil: pellizco con dos dedos (escala y giro con
// iman), vibracion al engancharse una guia, descripcion para el lector de
// pantalla e intencion que el teclado no aprende.
import 'package:arcanum_app/features/sigilos/taller_panels.dart';
import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

SigilDoc _doc() => SigilDoc()..generate('Mi práctica mantiene enfoque sereno');

void main() {
  group('pellizco (logica)', () {
    test('escala y gira la letra elegida; el giro se pega a 15 grados', () {
      final ctl = CanvasController(_doc())..sel = 'M';
      expect(ctl.beginPinch(), isTrue);
      expect(ctl.anchor(), isNull, reason: 'sin radial durante el pellizco');
      ctl.updatePinch(1.5, 43);
      final u = ctl.doc.sigil.letters.firstWhere((l) => l.ch == 'M').user;
      expect(u.ds, closeTo(1.5, 1e-9));
      expect(u.drot, 45, reason: '43 se pega a 45');
      ctl.updatePinch(1.5, 43, alt: true);
      expect(u.drot, 43, reason: 'con Alt, sin iman');
      ctl.updatePinch(9, 0);
      expect(u.ds, 2, reason: 'mismo tope que el radial');
      ctl.updatePinch(.01, 0);
      expect(u.ds, .4);
      ctl.endPinch();
      expect(ctl.pinching, isFalse);
      expect(ctl.anchor(), isNotNull);
    });

    test('en capas escala lo que cada tipo escala, con sus topes', () {
      final ctl = CanvasController(_doc());
      final star = ctl.addLayer(LayerType.star);
      ctl.beginPinch();
      ctl.updatePinch(1.3, 0);
      expect(star.scale, closeTo(130, 1e-9));
      ctl.updatePinch(5, -20);
      expect(star.scale, 160);
      expect(star.rot, 340);
      ctl.endPinch();
      final sym = ctl.addLayer(LayerType.symbol);
      ctl.beginPinch();
      ctl.updatePinch(.1, 0);
      expect(sym.size, 18);
      ctl.endPinch();
    });

    test('sin nada elegido no hay pellizco', () {
      final ctl = CanvasController(_doc());
      expect(ctl.beginPinch(), isFalse);
    });
  });

  testWidgets('dos dedos sobre una letra elegida la escalan en el lienzo', (tester) async {
    tester.view
      ..physicalSize = const Size(400 * 3, 400 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final ctl = CanvasController(_doc())..sel = 'M';
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox.square(dimension: 400, child: SigilCanvas(controller: ctl)))));
    final c = tester.getCenter(find.byType(SigilCanvas));
    final a = await tester.startGesture(c - const Offset(40, 0), pointer: 1);
    final b = await tester.startGesture(c + const Offset(40, 0), pointer: 2);
    await tester.pump();
    await a.moveTo(c - const Offset(60, 0));
    await b.moveTo(c + const Offset(60, 0));
    await tester.pump();
    final u = ctl.doc.sigil.letters.firstWhere((l) => l.ch == 'M').user;
    expect(u.ds, closeTo(1.5, 1e-6), reason: '80 px -> 120 px entre dedos');
    await a.up();
    await b.up();
    await tester.pump();
    expect(ctl.pinching, isFalse);
    expect(ctl.sel, 'M', reason: 'el primer dedo en un hueco no deshace la eleccion');
  });

  testWidgets('sin nada elegido, se pellizca la letra que toca el primer dedo', (tester) async {
    tester.view
      ..physicalSize = const Size(400 * 3, 400 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final ctl = CanvasController(_doc());
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox.square(dimension: 400, child: SigilCanvas(controller: ctl)))));
    final sg = ctl.doc.sigil;
    final p = sg.prims.firstWhere((q) => q.units.length == 1 && q is LinePrim) as LinePrim;
    final m = sg.view!.toCanvas(Pt((p.a.x + p.b.x) / 2, (p.a.y + p.b.y) / 2));
    final r = tester.getRect(find.byType(SigilCanvas)), k = r.width / kSize;
    final sobre = r.topLeft + Offset(m.x * k, m.y * k);
    final a = await tester.startGesture(sobre, pointer: 1);
    await tester.pump();
    final b = await tester.startGesture(sobre + const Offset(80, 0), pointer: 2);
    await tester.pump();
    await b.moveTo(sobre + const Offset(40, 0));
    await tester.pump();
    final l = sg.letters.firstWhere((x) => x.ch == p.units.single);
    expect(ctl.sel, l.ch);
    expect(l.user.ds, closeTo(.5, 1e-6), reason: '80 px -> 40 px entre dedos');
    expect(l.user.dx, 0, reason: 'el primer dedo no llego a mover la letra');
    await a.up();
    await b.up();
  });

  testWidgets('al engancharse una guia el telefono da un toque leve', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add('${call.method}:${call.arguments}');
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    tester.view
      ..physicalSize = const Size(400 * 3, 400 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final ctl = CanvasController(_doc());
    final sym = ctl.addLayer(LayerType.symbol, (l) => l
      ..x = 250
      ..y = 160);
    ctl.layerSel = null;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox.square(dimension: 400, child: SigilCanvas(controller: ctl)))));
    final r = tester.getRect(find.byType(SigilCanvas)), k = r.width / kSize;
    final g = await tester.startGesture(r.topLeft + Offset(250 * k, 160 * k));
    // recorrido por el lienzo: cada vez que el iman pasa de no tener guia a
    // tenerla debe haber exactamente un toque leve, y ninguno mas
    var engancha = 0, habia = false;
    for (var i = 0; i <= 40; i++) {
      await g.moveTo(r.topLeft + Offset((150 + i * 12.0) * k, (200 + (i % 7) * 9.0) * k));
      await tester.pump();
      final hay = ctl.guides.isNotEmpty;
      if (hay && !habia) engancha++;
      habia = hay;
    }
    await g.moveTo(r.topLeft + Offset(397 * k, 210 * k));
    await tester.pump();
    if (ctl.guides.isNotEmpty && !habia) engancha++;
    await g.up();
    final toques = calls.where((c) => c.startsWith('HapticFeedback')).toList();
    expect(engancha, greaterThan(1), reason: 'el recorrido cruza varias guias');
    expect(toques, hasLength(engancha));
    expect(toques.every((c) => c.contains('HapticFeedbackType.selectionClick')), isTrue);
    expect(sym.x, closeTo(400, 1e-6), reason: 'acaba pegado a la vertical del centro');
  });

  testWidgets('el lector de pantalla oye que hay en el lienzo', (tester) async {
    final handle = tester.ensureSemantics();
    final ctl = CanvasController(_doc())..sel = 'M';
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox.square(dimension: 300, child: SigilCanvas(controller: ctl)))));
    expect(find.bySemanticsLabel(RegExp(r'^Sigilo de \d+ letras: .*Elegida la letra M\.$')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('el teclado no sugiere, no corrige ni aprende la intencion', (tester) async {
    final ctl = CanvasController(SigilDoc());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CrearPanel(ctl: ctl, intention: TextEditingController(), onForge: () {}, onChanged: () {}, letterColors: false, onLetterColors: (_) {}),
        ),
      ),
    ));
    final f = tester.widget<TextField>(find.byType(TextField).first);
    expect(f.enableSuggestions, isFalse);
    expect(f.autocorrect, isFalse);
    expect(f.enableIMEPersonalizedLearning, isFalse);
  });
}
