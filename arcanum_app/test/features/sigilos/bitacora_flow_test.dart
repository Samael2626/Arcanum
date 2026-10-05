// Tras soltar, la Bitacora ofrece una anotacion voluntaria: se cifra solo la
// observacion, nunca la intencion ni el documento del sigilo.
import 'dart:convert';

import 'package:arcanum_app/features/sigilos/bitacora_sheet.dart';
import 'package:arcanum_app/features/sigilos/taller_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'taller_fakes.dart';

void main() {
  testWidgets('soltar y anotar cifra solo la observacion', (t) async {
    final api = FakeApi();
    phoneView(t);
    await t.pumpWidget(tallerApp(
      Scaffold(body: Builder(builder: (c) => TextButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const TallerScreen())), child: const Text('abrir')))),
      api,
    ));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'Mi intención secreta');
    await t.tap(find.text('Forjar'));
    await t.pump();
    await t.tap(find.text('Guardar'));
    await t.pump();
    await t.tap(find.text('Guardar en el Grimorio'));
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    await t.tap(find.text('Cargar'));
    await t.pumpAndSettle();
    await t.tap(find.text('Empezar'));
    for (var i = 0; i < 31; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    await t.tap(find.text('Olvidar'));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    await t.tap(find.text('Soltar'));
    await t.pumpAndSettle();
    expect(find.byType(BitacoraSheet), findsOneWidget);
    await t.enterText(find.descendant(of: find.byType(BitacoraSheet), matching: find.byType(TextField)), 'La respiración me ayudó a concentrarme.');
    await t.tap(find.text('Guardar en la Bitácora'));
    await t.pumpAndSettle();
    // la primera alta es el sigilo (ya soltado, sin intencion); la segunda, la nota
    expect(api.created, hasLength(2));
    final body = api.created.last;
    expect(body['entry_type'], 'ritual');
    expect(body['title'] as String, startsWith('Práctica de sigilo, '));
    expect(body['title'] as String, isNot(contains('intención')));
    expect(utf8.decode(base64Decode(body['encrypted_content'] as String)), 'La respiración me ayudó a concentrarme.');
    expect(find.byType(TallerScreen), findsNothing);
  });
}
