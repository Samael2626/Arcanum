import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/features/arte/arte_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RetryMateriaApi extends ArcanumApi {
  _RetryMateriaApi() : super(Dio());

  var calls = 0;

  @override
  Future<List<Map<String, dynamic>>> materiaList({
    String? itemType,
    String? planet,
    String? q,
  }) async {
    calls++;
    if (calls == 1) throw Exception('offline');
    return const [];
  }
}

Widget _wrap(Widget child, {ArcanumApi? api}) => ProviderScope(
  overrides: [if (api != null) arcanumApiProvider.overrideWithValue(api)],
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  testWidgets('el error de Materia Arcana permite reintentar', (tester) async {
    final api = _RetryMateriaApi();
    await tester.pumpWidget(_wrap(const ArteScreen(), api: api));
    await tester.pump();

    expect(find.text('No se pudo abrir el herbario.'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();

    expect(api.calls, 2);
    expect(find.text('El herbario aún calla'), findsOneWidget);
  });

  testWidgets('filtros y tarjetas exponen semántica de controles', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final items = Future.value(const [
      {
        'slug': 'romero',
        'item_type': 'herb',
        'name': 'Romero',
        'planet': 'sun',
        'element': 'fuego',
      },
    ]);

    await tester.pumpWidget(_wrap(ArteScreen(itemsOverride: items)));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.bySemanticsLabel(RegExp(r'Filtrar por Hierbas')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(r'Filtrar por Sol')), findsOneWidget);
    expect(find.text('Romero'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Abrir Romero')), findsOneWidget);
    semantics.dispose();
  });
}
