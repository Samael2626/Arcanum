// Miniatura cifrada del sigilo para la lista del Grimorio: se dibuja de verdad,
// viaja cifrada en el alta y en la edicion, no bloquea el guardado si falla,
// y la lista cae a la capitular si no se puede leer.
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:arcanum_app/core/crypto/grimoire_crypto.dart';
import 'package:arcanum_app/features/grimorio/grimorio_screen.dart';
import 'package:arcanum_app/features/sigilos/sigil_store.dart';
import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'taller_fakes.dart';

const _intencion = 'Mi práctica mantiene enfoque sereno';
const _png = [137, 80, 78, 71];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la miniatura es un PNG de 160 px con el sigilo dibujado', () async {
    final png = (await renderSigilPreview(SigilDoc()..generate(_intencion)))!;
    expect(png.sublist(0, 4), _png);
    final codec = await ui.instantiateImageCodec(png);
    final img = (await codec.getNextFrame()).image;
    expect([img.width, img.height], [kPreviewPx, kPreviewPx]);
    // no es un cuadro liso: hay tinta sobre el fondo
    final px = (await img.toByteData())!.buffer.asUint32List();
    expect(px.toSet().length, greaterThan(4));
    expect(await renderSigilPreview(SigilDoc()), isNull);
  });

  test('alta y edicion llevan la miniatura cifrada', () async {
    final api = FakeApi();
    final store = SigilStore(api, FakeCrypto(), null, preview: (_) async => Uint8List.fromList(_png));
    final e = SigilEntry(SigilDoc()..generate(_intencion));
    final id = await store.save(e);
    final body = api.created.single;
    expect(base64Decode(utf8.decode(base64Decode(body['encrypted_preview'] as String))), _png);
    expect(body['preview_iv'], 'iv');
    await store.save(e, entryId: id);
    expect(api.updated.single.$2['encrypted_preview'], isA<String>());
  });

  test('si la miniatura falla, el sigilo se guarda igual, sin ella', () async {
    final api = FakeApi();
    final store = SigilStore(api, FakeCrypto(), null, preview: (_) async => throw StateError('sin GPU'));
    await store.save(SigilEntry(SigilDoc()..generate(_intencion)));
    expect(api.created.single.containsKey('encrypted_preview'), isFalse);
    expect(api.created.single['encrypted_content'], isA<String>());
  });

  Widget thumb(String ciphertext, String iv) => ProviderScope(
        overrides: [grimoireCryptoProvider.overrideWithValue(FakeCrypto())],
        child: MaterialApp(
            home: Center(child: SigilThumb(ciphertext: ciphertext, iv: iv, fallback: const Text('capitular')))),
      );

  testWidgets('la lista dibuja la miniatura descifrada', (t) async {
    final png = (await t.runAsync(() => renderSigilPreview(SigilDoc()..generate(_intencion))))!;
    final enc = await FakeCrypto().encryptText(base64Encode(png));
    await t.pumpWidget(thumb(enc.ciphertext, 'iv-ok'));
    await t.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('capitular'), findsNothing);
  });

  testWidgets('miniatura ilegible: queda la capitular', (t) async {
    await t.pumpWidget(thumb('esto no es base64 !!', 'iv-roto'));
    await t.pump();
    expect(find.text('capitular'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
