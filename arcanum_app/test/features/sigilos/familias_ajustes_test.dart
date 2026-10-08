// Ajustes sobre la integracion de las familias v2 (8-oct): datos rotos que no
// tumban el Grimorio, teclado estable en las pantallas de familia, pantalla
// completa, y el soltar con el diseño de main (la intencion sale de la vista,
// la bitacora lo dice bien y tambien se ofrece desde el Grimorio).
import 'dart:convert';

import 'package:arcanum_app/features/grimorio/grimorio_detail.dart';
import 'package:arcanum_app/features/grimorio/grimorio_editor.dart';
import 'package:arcanum_app/features/sigilos/bitacora_sheet.dart';
import 'package:arcanum_app/features/sigilos/compare_screen.dart';
import 'package:arcanum_app/features/sigilos/kamea_screen.dart';
import 'package:arcanum_app/features/sigilos/personal_screen.dart';
import 'package:arcanum_app/features/sigilos/rosa_screen.dart';
import 'package:arcanum_app/features/sigilos/sigil_store.dart';
import 'package:arcanum_app/features/sigilos/taller_carga.dart';
import 'package:arcanum_app/features/sigilos/taller_screen.dart';
import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'taller_fakes.dart';

const _intencion = 'Mi práctica mantiene enfoque sereno';

Future<void> _avanzar(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _cargarYOlvidar(WidgetTester t) async {
  final b = find.widgetWithText(OutlinedButton, 'Cargar');
  await t.ensureVisible(b);
  await t.tap(b);
  await _avanzar(t);
  await t.tap(find.text('Empezar'));
  for (var i = 0; i < 31; i++) {
    await t.pump(const Duration(seconds: 1));
  }
  await t.tap(find.text('Olvidar'));
  await _avanzar(t);
}

void main() {
  group('datos rotos', () {
    final roto = {'x': 1};
    final casos = <String, Object? Function(String)>{
      kKameaMark: decodeKameaEntry,
      kRosaMark: decodeRosaEntry,
      kPersonalMark: decodePersonalEntry,
      kCompareMark: decodeCompareEntry,
    };
    for (final MapEntry(key: marca, value: decode) in casos.entries) {
      test('$marca con datos rotos: null, sin excepcion', () {
        // incompleto: puede rellenar con valores por defecto, pero nunca lanzar
        expect(() => decode(jsonEncode({'taller': marca, 'doc': roto})), returnsNormally);
        // ni siquiera un mapa: antes era un TypeError que tumbaba el detalle
        expect(decode(jsonEncode({'taller': marca, 'doc': 'no es un mapa'})), isNull);
      });
    }
  });

  group('teclado en las pantallas de familia', () {
    final pantallas = <String, Widget>{
      'kamea': const KameaScreen(),
      'rosa': const RosaScreen(),
      'sello personal': const PersonalScreen(),
      'comparar': const CompareScreen(),
    };
    for (final MapEntry(key: nombre, value: pantalla) in pantallas.entries) {
      testWidgets('$nombre: subir el teclado no quita el foco al campo', (t) async {
        phoneView(t);
        await t.pumpWidget(tallerApp(pantalla, FakeApi()));
        await t.pump();
        final campo = find.byType(TextField);
        if (campo.evaluate().isEmpty) return; // pantalla sin campo de texto
        await t.tap(campo.first);
        await t.pump();
        // teclado de 420 dp: el alto libre queda por debajo del ancho (GN2200)
        t.view.viewInsets = const FakeViewPadding(bottom: 420 * 3);
        addTearDown(t.view.resetViewInsets);
        await t.pumpAndSettle();
        expect(t.state<EditableTextState>(find.byType(EditableText).first).widget.focusNode.hasFocus, isTrue, reason: '$nombre perdio el foco');
      });
    }
  });

  testWidgets('las familias se abren en el navegador raiz, fuera del marco del Grimorio', (t) async {
    phoneView(t);
    final anidado = GlobalKey<NavigatorState>();
    await t.pumpWidget(tallerApp(
        Scaffold(
          appBar: AppBar(title: const Text('Cabecera del Grimorio')),
          body: Navigator(key: anidado, onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const GrimorioEditor())),
        ),
        FakeApi()));
    await t.tap(find.text('Sigilo'));
    await t.pump();
    final comparar = find.text('Comparar tres sistemas');
    await t.ensureVisible(comparar);
    await t.tap(comparar);
    await t.pumpAndSettle();
    expect(find.byType(CompareScreen), findsOneWidget);
    expect(find.text('Cabecera del Grimorio'), findsNothing);
    expect(anidado.currentState!.canPop(), isFalse);
  });

  testWidgets('la bitacora dice lo que de verdad queda tras soltar', (t) async {
    phoneView(t);
    await t.pumpWidget(tallerApp(const Scaffold(body: BitacoraSheet(savedCopy: true)), FakeApi()));
    expect(find.textContaining('ya sin la intención'), findsOneWidget);
    expect(find.textContaining('permanece allí'), findsNothing);
  });

  testWidgets('al soltar, el sigilo y la intencion salen de la vista antes de la bitacora', (t) async {
    phoneView(t);
    final api = FakeApi();
    await t.pumpWidget(tallerApp(
        Scaffold(body: Builder(builder: (c) => TextButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const TallerScreen())), child: const Text('abrir')))),
        api));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, _intencion);
    await t.tap(find.text('Forjar'));
    await t.pump();
    final st = t.state<TallerScreenState>(find.byType(TallerScreen));
    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();
    await _cargarYOlvidar(t);
    await t.tap(find.text('Soltar'));
    await _avanzar(t);
    expect(find.byType(BitacoraSheet), findsOneWidget);
    expect(st.debugDoc.sigil.prims, isEmpty);
    // el campo de la intencion queda vacio (aunque la pestaña Crear no se vea)
    expect(st.debugIntentionText, isEmpty);
  });

  testWidgets('soltar desde el detalle del Grimorio tambien ofrece la bitacora', (t) async {
    phoneView(t);
    final plain = encodeSigilEntry(SigilEntry(SigilDoc()..generate(_intencion)));
    final api = FakeApi()
      ..detail = {'id': 's', 'entry_type': 'sigil', 'title': 'Sigilo del 1 de octubre', 'encrypted_content': base64Encode(utf8.encode(plain)), 'content_iv': 'iv', 'entry_date': '2026-10-01T10:00:00Z'};
    await t.pumpWidget(tallerApp(const GrimorioDetail(id: 's'), api));
    await _avanzar(t);
    await _cargarYOlvidar(t);
    expect(find.byType(TallerCarga), findsNothing);
    await t.tap(find.text('Soltar'));
    await _avanzar(t);
    expect(find.byType(BitacoraSheet), findsOneWidget);
    expect(find.textContaining('ya sin la intención'), findsOneWidget);
  });
}
