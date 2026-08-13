import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/features/name_threshold/application/reading_identity_controller.dart';
import 'package:arcanum_app/features/name_threshold/data/reading_identity_repository.dart';
import 'package:arcanum_app/features/name_threshold/domain/hebrew_gematria.dart';
import 'package:arcanum_app/features/name_threshold/domain/reading_identity.dart';
import 'package:arcanum_app/features/name_threshold/presentation/identity_screen.dart';
import 'package:arcanum_app/features/name_threshold/presentation/name_part_screen.dart';
import 'package:arcanum_app/features/name_threshold/presentation/name_threshold_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _GoldenAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {
    'display_name': 'Nombre social',
  });
}

class _GoldenStorage implements ReadingIdentityStorage {
  ReadingIdentityProfile? value;
  _GoldenStorage(this.value);

  @override
  Future<void> delete() async => value = null;
  @override
  Future<ReadingIdentityProfile?> load() async => value;
  @override
  Future<void> save(ReadingIdentityProfile profile) async => value = profile;
}

void main() {
  final now = DateTime.utc(2026, 8, 13);
  final form = ConfirmedHebrewForm(
    resultId: 'result-a',
    pointedHebrew: 'יוֹסֵף',
    baseHebrew: 'יוסף',
    pronunciation: 'Español Colombia / LatAm: José',
    origin: HebrewFormOrigin.historicalDocumented,
    ruleVersion: 'catalog-hebrew-1.0.0',
    gematriaVersion: HebrewGematria.methodVersion,
    letters: HebrewGematria.breakdown('יוסף'),
    value: HebrewGematria.calculate('יוסף'),
    confirmedAt: now,
  );
  late ReadingIdentityProfile profile;

  setUp(() {
    profile = ReadingIdentityProfile(
      parts: [
        ReadingNamePart(
          id: 'part-jose',
          type: NamePartType.givenName,
          originalText: 'José',
          dialect: ReadingDialect.latinAmerica,
          createdAt: now,
          confirmedForms: [form],
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
  });

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    ReadingIdentityProfile? value,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_GoldenAuth.new),
          readingIdentityRepositoryProvider.overrideWithValue(
            ReadingIdentityRepository(_GoldenStorage(value)),
          ),
        ],
        child: MaterialApp(theme: buildArcanumTheme(), home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('captura Identidad', (tester) async {
    await pump(tester, const IdentityScreen(), value: profile);
    await expectLater(
      find.byType(IdentityScreen),
      matchesGoldenFile('goldens/01-identidad.png'),
    );
  });

  testWidgets('captura lista Nombre y Umbral', (tester) async {
    await pump(tester, const NameThresholdScreen(), value: profile);
    await expectLater(
      find.byType(NameThresholdScreen),
      matchesGoldenFile('goldens/02-nombre-y-umbral.png'),
    );
  });

  testWidgets('captura Archivo y calculo', (tester) async {
    await pump(
      tester,
      const NamePartScreen(partId: 'part-jose'),
      value: profile,
    );
    await expectLater(
      find.byType(NamePartScreen),
      matchesGoldenFile('goldens/03-archivo-calculo.png'),
    );
  });

  testWidgets('Samuel muestra relato y fuentes sin URL cruda', (tester) async {
    final samuel = ReadingIdentityProfile(
      parts: [
        ReadingNamePart(
          id: 'part-samuel',
          type: NamePartType.givenName,
          originalText: 'Samuel',
          dialect: ReadingDialect.latinAmerica,
          createdAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );

    await pump(
      tester,
      const NamePartScreen(partId: 'part-samuel'),
      value: samuel,
    );

    expect(find.text('Dios ha escuchado.'), findsOneWidget);
    expect(find.textContaining('Ana nombra a su hijo'), findsOneWidget);
    expect(find.text('Nota de archivo'), findsOneWidget);
    expect(find.textContaining('https://'), findsNothing);
  });

  testWidgets(
    'guardar una parte cierra el dialogo antes de actualizar perfil',
    (tester) async {
      await pump(tester, const NameThresholdScreen(), value: null);

      await tester.tap(find.text('Añadir parte del nombre'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Andrés');
      await tester.tap(find.text('Guardar cifrado'));
      await tester.pumpAndSettle();

      expect(find.text('Andrés'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
