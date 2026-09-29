import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/features/oraculo/tarot_learn.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends ArcanumApi {
  _Api() : super(Dio());

  final studied = <String>{};
  int calls = 0;

  @override
  Future<Map<String, dynamic>> studyTarotCard(String slug) async {
    calls++;
    return {'granted': studied.add(slug) ? 1 : 0};
  }
}

void main() {
  testWidgets('estudiar una carta muestra el fragmento real una sola vez', (
    tester,
  ) async {
    final api = _Api();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [arcanumApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTarotCardSheet(context, {
                  'slug': 'la-estrella',
                  'arcana': 'major',
                  'meaning_upright': 'Esperanza.',
                  'meaning_reversed': 'Desaliento.',
                }),
                child: const Text('Abrir ficha'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir ficha'));
    await tester.pumpAndSettle();

    final button = find.text('Marcar carta estudiada');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.textContaining('+1 Fragmento Arcano'), findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.textContaining('No se repite la recompensa'), findsOneWidget);
    expect(api.calls, 2);
  });
}
