import 'package:arcanum_app/features/lecturas/data/library_repository.dart';
import 'package:arcanum_app/features/lecturas/domain/library_models.dart';
import 'package:arcanum_app/features/lecturas/library_messages.dart';
import 'package:arcanum_app/features/lecturas/presentation/lecturas_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositorio que siempre falla con el 500 real de /library.
class _FailingLibraryRepository implements LibraryRepository {
  _FailingLibraryRepository(this.error);
  final Object error;

  @override
  Future<List<LibraryWorkSummary>> works({bool forceRefresh = false}) async =>
      throw error;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DioException _serverError() => DioException(
      requestOptions: RequestOptions(
        path: '/library',
        baseUrl: 'https://arcanum-code-production.up.railway.app',
      ),
      response: Response(
        requestOptions: RequestOptions(path: '/library'),
        statusCode: 500,
        data: {
          'detail': "ResponseValidationError: 2 validation errors:\n"
              "  {'type': 'missing', 'loc': ('response', 0, 'chapter_count')}"
        },
      ),
    );

Future<void> _pumpLecturas(WidgetTester tester, Object error) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        libraryRepositoryProvider
            .overrideWithValue(_FailingLibraryRepository(error)),
      ],
      child: const MaterialApp(home: Scaffold(body: LecturasScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('un 500 de /library no filtra nada tecnico', (tester) async {
    await _pumpLecturas(tester, _serverError());

    expect(find.text(libraryUnavailableMessage), findsOneWidget);
    for (final leak in [
      'DioException',
      '500',
      'RequestOptions',
      '/library',
      'railway',
      'ResponseValidationError',
      'chapter_count',
      'validation',
    ]) {
      expect(find.textContaining(leak), findsNothing,
          reason: 'la pantalla filtro "$leak"');
    }
  });

  testWidgets('un error inesperado tampoco se muestra crudo', (tester) async {
    await _pumpLecturas(tester, StateError('socket cerrado en /library'));

    expect(find.text(libraryUnavailableMessage), findsOneWidget);
    expect(find.textContaining('socket cerrado'), findsNothing);
    expect(find.textContaining('StateError'), findsNothing);
  });
}
