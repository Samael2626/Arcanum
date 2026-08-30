import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/shared/widgets/content_report_sheet.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingApi extends ArcanumApi {
  _RecordingApi() : super(Dio());

  Map<String, String?>? report;

  @override
  Future<void> createContentReport({
    required String source,
    required String contentRef,
    required String reason,
    String? note,
  }) async {
    report = {
      'source': source,
      'content_ref': contentRef,
      'reason': reason,
      'note': note,
    };
  }
}

void main() {
  testWidgets('envia una razon desde el bottom sheet y confirma', (
    tester,
  ) async {
    final api = _RecordingApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentReportButton(
            api: api,
            source: 'oracle',
            contentRef: 'conversation-123',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Reportar esta respuesta'));
    await tester.pumpAndSettle();
    expect(find.text('Ofensiva'), findsOneWidget);
    expect(find.text('Peligrosa'), findsOneWidget);
    expect(find.text('Sin sentido'), findsOneWidget);

    await tester.tap(find.text('Peligrosa'));
    await tester.enterText(find.byType(TextField), 'Puede causar dano');
    await tester.tap(find.text('Enviar reporte'));
    await tester.pumpAndSettle();

    expect(api.report, {
      'source': 'oracle',
      'content_ref': 'conversation-123',
      'reason': 'peligrosa',
      'note': 'Puede causar dano',
    });
    expect(find.text('Reporte enviado. Gracias.'), findsOneWidget);
  });
}
