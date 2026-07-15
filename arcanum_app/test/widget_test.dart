import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/main.dart';

class _SilentArcanumApi extends ArcanumApi {
  _SilentArcanumApi() : super(Dio());

  final _today = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> today({
    double lat = 4.71,
    double lon = -74.07,
  }) => _today.future;
}

void main() {
  testWidgets('ARCANUM muestra el wordmark al arrancar', (tester) async {
    // ProviderScope vive en main(), no dentro de ArcanumApp: el harness debe
    // envolverlo o cualquier ConsumerWidget (HoyScreen) rompe al arrancar.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [arcanumApiProvider.overrideWithValue(_SilentArcanumApi())],
        child: const ArcanumApp(),
      ),
    );
    await tester.pump();
    expect(find.text('ARCANUM'), findsOneWidget);
  });
}
