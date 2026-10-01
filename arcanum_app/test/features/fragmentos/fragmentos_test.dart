import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/features/fragmentos/presentation/fragmentos_screen.dart';
import 'package:arcanum_app/features/sendero/application/sendero_guide_controller.dart';
import 'package:arcanum_app/features/sendero/domain/sendero_catalog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends ArcanumApi {
  _Api({this.failOnce = false}) : super(Dio());

  final bool failOnce;
  final keys = <String>[];
  int balance = 15;

  Map<String, dynamic> get response => {
    'balance': balance,
    'credits_balance': balance == 15 ? 0 : 1,
    'conversion_rate': 12,
    'weekly_conversions_remaining': balance == 15 ? 3 : 2,
    'weekly_conversion_limit': 3,
    'tutorial_reward': 3,
  };

  @override
  Future<Map<String, dynamic>> fragmentsBalance() async => response;

  @override
  Future<Map<String, dynamic>> convertFragments(String idempotencyKey) async {
    keys.add(idempotencyKey);
    if (failOnce && keys.length == 1) {
      throw DioException(
        requestOptions: RequestOptions(path: '/fragments/convert'),
      );
    }
    balance -= 12;
    return response;
  }
}

Future<void> _mount(WidgetTester tester, _Api api) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [arcanumApiProvider.overrideWithValue(api)],
      child: const MaterialApp(home: FragmentosScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Sendero ilumina el saldo real y se puede cerrar', (
    tester,
  ) async {
    await _mount(tester, _Api());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FragmentosScreen)),
    );
    container
        .read(senderoGuideProvider.notifier)
        .start(senderoJourneyById('fragmentos')!);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sendero_guide_card')), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    expect(container.read(senderoGuideProvider), isNull);
  });

  testWidgets('muestra saldo real y cancelar no convierte', (tester) async {
    final api = _Api();
    await _mount(tester, api);
    expect(find.text('15 Fragmentos'), findsOneWidget);
    expect(find.textContaining('Sendero te da 3'), findsOneWidget);

    await tester.ensureVisible(find.text('Convertir en crédito'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Convertir en crédito'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(api.keys, isEmpty);

    await tester.ensureVisible(find.text('Convertir en crédito'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Convertir en crédito'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Convertir'));
    await tester.pumpAndSettle();
    expect(api.keys, hasLength(1));
    expect(find.text('3 Fragmentos'), findsOneWidget);
  });

  testWidgets('reintento tras fallo conserva la clave de conversion', (
    tester,
  ) async {
    final api = _Api(failOnce: true);
    await _mount(tester, api);
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.ensureVisible(find.text('Convertir en crédito'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Convertir en crédito'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Convertir'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }
    expect(api.keys, hasLength(2));
    expect(api.keys.first, api.keys.last);
    expect(find.text('3 Fragmentos'), findsOneWidget);
  });
}
