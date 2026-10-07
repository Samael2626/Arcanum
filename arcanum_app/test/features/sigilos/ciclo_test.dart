// Ciclo del sigilo: cargas anotadas, soltar (la intencion se borra y el
// dibujo queda), privacidad del texto por defecto de las capas, lectura
// robusta de la entrada y los fallos que encontro la revision del 5-oct.
import 'dart:async';
import 'dart:convert';

import 'package:arcanum_app/features/grimorio/grimorio_detail.dart';
import 'package:arcanum_app/features/grimorio/grimorio_editor.dart';
import 'package:arcanum_app/features/sigilos/sigil_radial.dart';
import 'package:arcanum_app/features/sigilos/sigil_store.dart';
import 'package:arcanum_app/features/sigilos/taller_carga.dart';
import 'package:arcanum_app/features/sigilos/taller_screen.dart';
import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'taller_fakes.dart';

const _intencion = 'Mi práctica mantiene enfoque sereno';

/// Documento con todo lo que el soltado debe conservar: capas con texto por
/// defecto, ediciones de letra, un trazo oculto y un remate por punta.
SigilDoc _docCompleto() {
  final doc = SigilDoc(
    layers: [
      Layer.create('c1', LayerType.ringLatin),
      Layer.create('c2', LayerType.inscription),
      Layer.create('c3', LayerType.caption),
    ],
    terminals: 'pattee',
  )..generate(_intencion);
  doc.sigil.letters.first.user = LetterEdit(dx: .1, drot: 30, fx: true);
  doc.rebuild();
  doc.sigil.hidden = [doc.sigil.visible.first.key];
  doc.rebuild();
  return doc;
}

SigilEntry _entry(String content) =>
    (decodeSigilEntry(content) as SigilReadable).entry;
String _plain(String ciphertext) => utf8.decode(base64Decode(ciphertext));

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

/// Avanza a mano: el Grimorio tiene animaciones que no se asientan nunca.
Future<void> _avanzar(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

/// Recorre la carga de 30 s y pulsa el boton final [boton].
Future<void> _cargar(WidgetTester t, String boton) async {
  await t.tap(find.text('Empezar'));
  for (var i = 0; i < 31; i++) {
    await t.pump(const Duration(seconds: 1));
  }
  await t.tap(find.text(boton));
  await _avanzar(t);
}

/// Pantalla de partida con su Scaffold: el taller se abre encima, como en la app.
Widget _lanzador() => Scaffold(
  body: Builder(
    builder: (c) => TextButton(
      onPressed: () => Navigator.push(
        c,
        MaterialPageRoute(builder: (_) => const TallerScreen()),
      ),
      child: const Text('abrir'),
    ),
  ),
);

Map<String, dynamic> _detail(String id, String plaintext) => {
  'id': id,
  'entry_type': 'sigil',
  'title': 'Sigilo del 1 de octubre',
  'encrypted_content': base64Encode(utf8.encode(plaintext)),
  'content_iv': 'iv',
  'entry_date': '2026-10-01T10:00:00Z',
};

void main() {
  group('motor', () {
    test('soltar borra la intencion y el dibujo sale identico', () {
      final doc = _docCompleto();
      final antes = doc.buildSVG();
      final suelto = releasedCopy(SigilEntry(doc), DateTime(2026, 10, 5));
      final json = encodeSigilEntry(suelto);
      expect(json.toLowerCase(), isNot(contains('práctica')));
      expect(json.toLowerCase(), isNot(contains('sereno')));
      final back = _entry(json);
      expect(back.isReleased, isTrue);
      expect(back.doc.sigil.intention, isEmpty);
      expect(back.doc.buildSVG(), antes);
      // el original no se toca: solo cambia si el guardado sale bien
      expect(doc.sigil.intention, _intencion);
    });

    test(
      'el texto por defecto de anillo, inscripcion y rotulo son las letras, nunca la intencion',
      () {
        final doc = _docCompleto();
        final svg = doc.buildSVG();
        for (final w in [
          'Mi',
          'práctica',
          'mantiene',
          'enfoque',
          'sereno',
          'PRÁCTICA',
          'SERENO',
        ]) {
          expect(svg, isNot(contains(w)), reason: w);
        }
        expect(doc.ctx.text, doc.units.join(' '));
        expect(doc.units, isNotEmpty);
      },
    );

    test('la pluma se mueve con las letras y no lleva halo', () {
      final doc = SigilDoc(
        style: const SigilStyle().copyWith(calli: 'pluma', glow: true),
      )..generate(_intencion);
      final fg = doc.scene().fg;
      final (_, mid, over) = splitAroundSigil(fg);
      expect(mid.map((g) => g.layer), contains('pluma'));
      expect(over.map((g) => g.layer), isNot(contains('pluma')));
      expect(fg.map((g) => g.layer), isNot(contains('pluma-halo')));
    });
  });

  group('lectura de la entrada', () {
    test('texto escrito a mano: null (se muestra como texto)', () {
      expect(decodeSigilEntry('Dibujé un sigilo.'), isNull);
      expect(decodeSigilEntry('{"otra":"cosa"}'), isNull);
      expect(decodeSigilEntry('{roto'), isNull);
    });

    test('version mas nueva o datos rotos: ilegible, sin excepcion', () {
      final doc = SigilDoc()..generate(_intencion);
      final j = doc.toJson()..['v'] = SigilDoc.kVersion + 1;
      expect(
        decodeSigilEntry(jsonEncode({'taller': kTallerMark, 'doc': j})),
        isA<SigilUnreadable>().having((u) => u.newerVersion, 'nueva', isTrue),
      );
      final roto = doc.toJson()..remove('method');
      expect(
        decodeSigilEntry(jsonEncode({'taller': kTallerMark, 'doc': roto})),
        isA<SigilUnreadable>().having((u) => u.newerVersion, 'nueva', isFalse),
      );
      final malEnum = doc.toJson()..['mode'] = 'espiral';
      expect(
        decodeSigilEntry(jsonEncode({'taller': kTallerMark, 'doc': malEnum})),
        isA<SigilUnreadable>(),
      );
    });

    test('las cargas van y vuelven', () {
      final e = SigilEntry(
        SigilDoc()..generate(_intencion),
        charges: [
          SigilCharge(
            at: DateTime(2026, 10, 5, 21, 40),
            seconds: 60,
            moon: 'Creciente',
            hour: 'jupiter',
            dayRuler: 'sun',
          ),
          SigilCharge(at: DateTime(2026, 10, 6, 7, 5), seconds: 30),
        ],
      );
      final back = _entry(encodeSigilEntry(e));
      expect(back.charges, hasLength(2));
      expect(back.charges.first.at, DateTime(2026, 10, 5, 21, 40));
      expect(
        [
          back.charges.first.seconds,
          back.charges.first.moon,
          back.charges.first.hour,
          back.charges.first.dayRuler,
        ],
        [60, 'Creciente', 'jupiter', 'sun'],
      );
      expect(back.charges.last.moon, isNull);
    });
  });

  group('taller', () {
    Future<TallerScreenState> forjar(WidgetTester t, FakeApi api) async {
      phoneView(t);
      await t.pumpWidget(tallerApp(_lanzador(), api));
      await t.tap(find.text('abrir'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, _intencion);
      await t.tap(find.text('Forjar'));
      await t.pump();
      await t.tap(find.text('Guardar'));
      await t.pump();
      return t.state<TallerScreenState>(find.byType(TallerScreen));
    }

    testWidgets('cargar y guardar anota la carga en la entrada', (t) async {
      final api = FakeApi();
      await forjar(t, api);
      await t.tap(find.text('Cargar'));
      await t.pumpAndSettle();
      await _cargar(t, 'Guardar');
      final e = _entry(
        _plain(api.created.single['encrypted_content'] as String),
      );
      expect(e.charges, hasLength(1));
      expect(e.charges.single.seconds, 30);
      expect(e.charges.single.moon, 'Creciente');
      expect(e.isReleased, isFalse);
      expect(e.doc.sigil.intention, _intencion);
    });

    testWidgets(
      'soltar un sigilo guardado avisa, borra la intencion y cierra el taller',
      (t) async {
        final api = FakeApi();
        await forjar(t, api);
        await t.tap(find.text('Guardar en el Grimorio'));
        await t.pumpAndSettle();
        await t.pump(const Duration(seconds: 5));
        await t.pumpAndSettle();
        await t.tap(find.text('Cargar'));
        await t.pumpAndSettle();
        await _cargar(t, 'Olvidar');
        expect(
          find.textContaining('se borrará de tu Grimorio para siempre'),
          findsOneWidget,
        );
        // «Volver» no suelta, pero la carga se hizo: se anota y la intencion sigue
        await t.tap(find.text('Volver'));
        await t.pumpAndSettle();
        final vuelta = _entry(
          _plain(api.updated.single.$2['encrypted_content'] as String),
        );
        expect(vuelta.isReleased, isFalse);
        expect(vuelta.charges, hasLength(1));
        expect(vuelta.doc.sigil.intention, _intencion);
        expect(find.byType(TallerScreen), findsOneWidget);
        await t.pump(const Duration(seconds: 5));
        await t.pumpAndSettle();

        await t.tap(find.text('Cargar'));
        await t.pumpAndSettle();
        await _cargar(t, 'Olvidar');
        await t.tap(find.text('Soltar'));
        await t.pumpAndSettle();
        expect(api.updated, hasLength(2));
        final (id, body) = api.updated.last;
        expect(id, 'sigilo-1');
        final plain = _plain(body['encrypted_content'] as String);
        expect(plain.toLowerCase(), isNot(contains('práctica')));
        final e = _entry(plain);
        expect(e.isReleased, isTrue);
        expect(e.charges, hasLength(2));
        expect(find.byType(TallerScreen), findsNothing);
        expect(find.text('Soltado. No lo busques.'), findsOneWidget);
      },
    );

    testWidgets(
      'soltar sin haber guardado avisa de que no queda nada y no llama a la API',
      (t) async {
        final api = FakeApi();
        await forjar(t, api);
        await t.tap(find.text('Cargar'));
        await t.pumpAndSettle();
        await _cargar(t, 'Olvidar');
        expect(find.textContaining('no se ha guardado'), findsOneWidget);
        await t.tap(find.text('Soltar'));
        await t.pumpAndSettle();
        expect(api.created, isEmpty);
        expect(api.updated, isEmpty);
        expect(find.byType(TallerScreen), findsNothing);
      },
    );

    testWidgets(
      'sin guardar, «Volver» deja la carga pendiente y viaja con el guardado',
      (t) async {
        final api = FakeApi();
        await forjar(t, api);
        await t.tap(find.text('Cargar'));
        await t.pumpAndSettle();
        await _cargar(t, 'Olvidar');
        await t.tap(find.text('Volver'));
        await t.pumpAndSettle();
        expect(api.created, isEmpty);
        expect(
          find.text('Carga anotada: se guardará con el sigilo.'),
          findsOneWidget,
        );
        await t.pump(const Duration(seconds: 5));
        await t.pumpAndSettle();
        await t.tap(find.text('Guardar en el Grimorio'));
        await t.pumpAndSettle();
        expect(
          _entry(
            _plain(api.created.single['encrypted_content'] as String),
          ).charges,
          hasLength(1),
        );
      },
    );

    testWidgets(
      'un cambio hecho mientras se guarda sigue contando como sin guardar',
      (t) async {
        final api = FakeApi()..hold = Completer<void>();
        final st = await forjar(t, api);
        await t.tap(find.text('Guardar en el Grimorio'));
        await t.pump();
        st.debugDoc.terminals = 'star'; // cambio durante el envio
        api.hold!.complete();
        await t.pumpAndSettle();
        await t.pump(const Duration(seconds: 5));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Cerrar'));
        await t.pumpAndSettle();
        expect(find.text('¿Salir sin guardar?'), findsOneWidget);
      },
    );

    testWidgets('cerrar el taller durante el guardado no revienta', (t) async {
      final api = FakeApi()..hold = Completer<void>();
      phoneView(t);
      await t.pumpWidget(tallerApp(_lanzador(), api));
      await t.tap(find.text('abrir'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, _intencion);
      await t.tap(find.text('Forjar'));
      await t.pump();
      await t.tap(find.text('Guardar'));
      await t.pump();
      await t.tap(find.text('Guardar en el Grimorio'));
      await t.pump();
      // el boton gira mientras guarda: nada se asienta, se avanza a mano
      await t.tap(find.byTooltip('Cerrar'));
      await t.pump(const Duration(milliseconds: 500));
      await t.tap(find.text('Salir'));
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byType(TallerScreen), findsNothing);
      api.hold!.complete();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  group('teclado', teclado);
  group('placa de fase', placaDeFase);
  group('pantalla entera', pantallaEntera);

  group('radial en lienzo chico', () {
    testWidgets(
      'el radial de seleccion cabe y no lanza aunque el lienzo mida 150',
      (t) async {
        final doc = SigilDoc()..generate(_intencion);
        final ctl = CanvasController(doc)..sel = doc.sigil.letters.first.ch;
        for (final side in [150.0, 196.0, 400.0]) {
          await t.pumpWidget(
            MaterialApp(
              home: Center(
                child: SizedBox.square(
                  dimension: side,
                  child: Stack(
                    children: [
                      SelectionRadial(ctl: ctl, side: side, onEdited: () {}),
                    ],
                  ),
                ),
              ),
            ),
          );
          expect(t.takeException(), isNull, reason: 'lado $side');
        }
      },
    );

    testWidgets('el + no saca botones fuera de un lienzo chico', (t) async {
      const side = 260.0;
      await t.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: side,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AddRadial(
                      open: true,
                      onToggle: (_) {},
                      onAdd: (_) {},
                      onSymbol: () {},
                      side: side,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final box = t.getRect(find.byType(AddRadial));
      for (final label in [
        'Círculo',
        'Cuadrado',
        'Anillo',
        'Estrella',
        'Inscripción',
        'Símbolo',
      ]) {
        final r = t.getRect(find.bySemanticsLabel(label).first);
        expect(
          box.contains(r.center),
          isTrue,
          reason: '$label en $r fuera de $box',
        );
      }
    });
  });

  group('detalle del Grimorio', () {
    testWidgets(
      'un sigilo soltado se ve con su fecha, sin intencion ni botones',
      (t) async {
        phoneView(t);
        final e = releasedCopy(
          SigilEntry(
            _docCompleto(),
            charges: [
              SigilCharge(
                at: DateTime(2026, 10, 3, 21, 40),
                seconds: 60,
                moon: 'Creciente',
                hour: 'jupiter',
              ),
              SigilCharge(at: DateTime(2026, 10, 4, 7, 5), seconds: 30),
            ],
          ),
          DateTime(2026, 10, 5),
        );
        final api = FakeApi()..detail = _detail('s', encodeSigilEntry(e));
        await t.pumpWidget(tallerApp(const GrimorioDetail(id: 's'), api));
        await _settle(t);
        expect(find.textContaining('Soltado el 5 de octubre'), findsOneWidget);
        for (final b in ['Cargar', 'Seguir en el taller', 'Ver la intención']) {
          expect(find.text(b), findsNothing, reason: b);
        }
        await t.ensureVisible(find.text('Cargado 2 veces'));
        expect(
          find.textContaining('3 de octubre, 21:40 · 60 s · ☽ Creciente'),
          findsOneWidget,
        );
        expect(find.textContaining('hora de Júpiter'), findsOneWidget);
      },
    );

    testWidgets(
      'un sigilo de una version mas nueva pide actualizar y no enseña el contenido',
      (t) async {
        phoneView(t);
        final j = (SigilDoc()..generate(_intencion)).toJson()
          ..['v'] = SigilDoc.kVersion + 1;
        final api = FakeApi()
          ..detail = _detail(
            's',
            jsonEncode({'taller': kTallerMark, 'doc': j}),
          );
        await t.pumpWidget(tallerApp(const GrimorioDetail(id: 's'), api));
        await _settle(t);
        expect(find.textContaining('Actualiza la app'), findsOneWidget);
        expect(find.textContaining('práctica'), findsNothing);
      },
    );

    testWidgets(
      'desde el detalle, Olvidar y luego «Volver» anota la carga sin soltar',
      (t) async {
        phoneView(t);
        final api = FakeApi()
          ..detail = _detail(
            's',
            encodeSigilEntry(SigilEntry(SigilDoc()..generate(_intencion))),
          );
        await t.pumpWidget(tallerApp(const GrimorioDetail(id: 's'), api));
        await _settle(t);
        await t.ensureVisible(find.text('Cargar'));
        await t.tap(find.text('Cargar'));
        await _avanzar(t);
        await _cargar(t, 'Olvidar');
        await t.tap(find.text('Volver'));
        await _avanzar(t);
        final e = _entry(
          _plain(api.updated.single.$2['encrypted_content'] as String),
        );
        expect(e.isReleased, isFalse);
        expect(e.charges, hasLength(1));
        expect(e.doc.sigil.intention, _intencion);
      },
    );

    testWidgets(
      '«Cargar» desde el detalle anota la carga en la misma entrada',
      (t) async {
        phoneView(t);
        final api = FakeApi()
          ..detail = _detail(
            's',
            encodeSigilEntry(SigilEntry(SigilDoc()..generate(_intencion))),
          );
        await t.pumpWidget(tallerApp(const GrimorioDetail(id: 's'), api));
        await _settle(t);
        await t.ensureVisible(find.text('Cargar'));
        await t.tap(find.text('Cargar'));
        await _avanzar(t);
        expect(find.byType(TallerCarga), findsOneWidget);
        await _cargar(t, 'Anotar');
        final (id, body) = api.updated.single;
        expect(id, 's');
        final e = _entry(_plain(body['encrypted_content'] as String));
        expect(e.charges.single.seconds, 30);
        expect(e.doc.sigil.intention, _intencion);
      },
    );
  });
}

// Encontrado en el movil (6-oct): al subir el teclado el alto libre baja del
// ancho, el taller se creia en horizontal, rehacia el panel y el campo perdia
// el foco: el teclado subia y se bajaba solo y no se podia escribir.
void teclado() {
  testWidgets(
    'subir el teclado no cambia la disposicion ni quita el foco al campo',
    (t) async {
      phoneView(t);
      await t.pumpWidget(tallerApp(const TallerScreen(), FakeApi()));
      await t.tap(find.byType(TextField).first);
      await t.pump();
      final campo = find.byType(EditableText).first;
      expect(
        t.state<EditableTextState>(campo).widget.focusNode.hasFocus,
        isTrue,
      );
      // teclado de 420 dp: el alto libre queda por debajo del ancho, como en el
      // GN2200 con la cabecera del Grimorio encima
      t.view.viewInsets = const FakeViewPadding(bottom: 420 * 3);
      await t.pumpAndSettle();
      expect(
        t
            .state<EditableTextState>(find.byType(EditableText).first)
            .widget
            .focusNode
            .hasFocus,
        isTrue,
        reason: 'el campo perdio el foco',
      );
      await t.enterText(
        find.byType(TextField).first,
        'Escribo con el teclado abierto',
      );
      expect(find.text('Escribo con el teclado abierto'), findsOneWidget);
      t.view.resetViewInsets();
    },
  );
}

// Encontrado en el movil (6-oct): el taller se abria dentro del marco del
// Grimorio (navegador anidado) y su cabecera quedaba encima del lienzo.
void pantallaEntera() {
  testWidgets(
    'el taller se abre en el navegador raiz, fuera del marco del Grimorio',
    (t) async {
      phoneView(t);
      final anidado = GlobalKey<NavigatorState>();
      await t.pumpWidget(
        tallerApp(
          Scaffold(
            appBar: AppBar(title: const Text('Cabecera del Grimorio')),
            body: Navigator(
              key: anidado,
              onGenerateRoute: (_) =>
                  MaterialPageRoute(builder: (_) => const GrimorioEditor()),
            ),
          ),
          FakeApi(),
        ),
      );
      await t.tap(find.text('Sigilo'));
      await t.pump();
      await t.tap(find.text('Abrir el taller'));
      await t.pumpAndSettle();
      expect(find.byType(TallerScreen), findsOneWidget);
      // la cabecera del marco ya no se ve: el taller cubre la pantalla
      expect(find.text('Cabecera del Grimorio'), findsNothing);
      expect(
        anidado.currentState!.canPop(),
        isFalse,
        reason: 'el taller entro en el navegador anidado',
      );
    },
  );
}

// Encontrado en el movil (6-oct): «EXHALA» en dorado fino no se leia sobre las
// lineas del sigilo. La fase va sobre una placa oscura.
void placaDeFase() {
  testWidgets('la fase de la respiracion va sobre una placa oscura', (t) async {
    phoneView(t);
    await t.pumpWidget(
      tallerApp(TallerCarga(doc: SigilDoc()..generate(_intencion)), FakeApi()),
    );
    await t.tap(find.text('Empezar'));
    await t.pump(const Duration(seconds: 1));
    final placa = find
        .ancestor(of: find.text('INHALA'), matching: find.byType(DecoratedBox))
        .first;
    final deco = t.widget<DecoratedBox>(placa).decoration as BoxDecoration;
    expect(deco.color!.a, greaterThan(.7));
    await t.pump(const Duration(seconds: 31));
  });
}
