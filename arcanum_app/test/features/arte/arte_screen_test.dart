import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/features/arte/arte_screen.dart';
import 'package:arcanum_app/features/arte/materia_engravings.dart';
import 'package:arcanum_app/features/arte/materia_specimen.dart';
import 'package:arcanum_app/shared/widgets/arcanum_mood.dart';
import 'package:arcanum_app/shared/widgets/arcanum_motion.dart';
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

class _CountingMateriaApi extends ArcanumApi {
  _CountingMateriaApi() : super(Dio());

  var calls = 0;

  @override
  Future<List<Map<String, dynamic>>> materiaList({
    String? itemType,
    String? planet,
    String? q,
  }) async {
    calls++;
    return const [
      {
        'slug': 'romero',
        'item_type': 'herb',
        'name': 'Romero',
        'planet': 'sun',
        'element': 'fire',
      },
      {
        'slug': 'amatista',
        'item_type': 'stone',
        'name': 'Amatista',
        'planet': 'jupiter',
        'element': 'air',
      },
    ];
  }
}

Widget _wrap(Widget child, {ArcanumApi? api}) => ProviderScope(
  overrides: [if (api != null) arcanumApiProvider.overrideWithValue(api)],
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  testWidgets('el catálogo compacto usa una silueta legible', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MateriaSpecimen(
          slug: 'romero',
          type: 'herb',
          mood: ArcanumMood.forPlanet('sun'),
          size: 102,
          compact: true,
        ),
      ),
    );

    expect(find.byType(MateriaGlyph), findsOneWidget);
    expect(find.byType(MateriaArt), findsNothing);
    expect(
      tester.widget<MateriaGlyph>(find.byType(MateriaGlyph)).variant,
      materiaVariant('romero', 'herb'),
    );
  });

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

  testWidgets('los filtros reutilizan el catálogo sin otra llamada', (
    tester,
  ) async {
    final api = _CountingMateriaApi();
    await tester.pumpWidget(_wrap(const ArteScreen(), api: api));
    await tester.pump();
    await tester.pump();

    expect(api.calls, 1);
    expect(find.text('Romero'), findsOneWidget);
    expect(find.text('Amatista'), findsOneWidget);

    await tester.tap(find.text('Hierbas'));
    await tester.pump();
    await tester.pump();

    expect(api.calls, 1);
    expect(find.text('Romero'), findsOneWidget);
    expect(find.text('Amatista'), findsNothing);
    expect(find.byType(ArcanumTilt), findsNothing);
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
