import 'package:arcanum_app/core/crypto/grimoire_crypto.dart';
import 'package:arcanum_app/features/name_threshold/application/bridge_resonance.dart';
import 'package:arcanum_app/features/name_threshold/application/reading_identity_controller.dart';
import 'package:arcanum_app/features/name_threshold/data/reading_identity_repository.dart';
import 'package:arcanum_app/features/name_threshold/domain/name_resonance.dart';
import 'package:arcanum_app/features/name_threshold/domain/reading_identity.dart';
import 'package:arcanum_app/features/name_threshold/domain/threshold_bridge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStorage implements ReadingIdentityStorage {
  ReadingIdentityProfile? value;

  @override
  Future<void> delete() async => value = null;
  @override
  Future<ReadingIdentityProfile?> load() async => value;
  @override
  Future<void> save(ReadingIdentityProfile profile) async => value = profile;
}

Future<(ProviderContainer, ReadingIdentityController, _MemoryStorage)>
_bootstrap() async {
  final memory = _MemoryStorage();
  final container = ProviderContainer(
    overrides: [
      readingIdentityRepositoryProvider.overrideWithValue(
        ReadingIdentityRepository(memory),
      ),
    ],
  );
  await container.read(readingIdentityProvider.future);
  return (container, container.read(readingIdentityProvider.notifier), memory);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('sin encender nada, ningun puente ve el nombre', () async {
    final (container, controller, _) = await _bootstrap();
    addTearDown(container.dispose);

    await controller.addPart(
      type: NamePartType.givenName,
      originalText: 'Adán',
      dialect: ReadingDialect.latinAmerica,
    );

    expect(container.read(readingIdentityProvider).value!.bridges, isEmpty);
    for (final bridge in ThresholdBridge.values) {
      expect(
        container.read(nameResonanceProvider(bridge)),
        isNull,
        reason: bridge.name,
      );
    }
  });

  test('encender un puente no enciende los otros dos', () async {
    final (container, controller, _) = await _bootstrap();
    addTearDown(container.dispose);

    await controller.addPart(
      type: NamePartType.givenName,
      originalText: 'Adán',
      dialect: ReadingDialect.latinAmerica,
    );
    await controller.setBridge(ThresholdBridge.tarot, true);

    expect(container.read(nameResonanceProvider(ThresholdBridge.tarot)),
        isNotNull);
    expect(container.read(nameResonanceProvider(ThresholdBridge.skies)), isNull);
    expect(container.read(nameResonanceProvider(ThresholdBridge.oracle)), isNull);
  });

  test('revocar borra de verdad: ni provider ni almacenamiento', () async {
    final (container, controller, memory) = await _bootstrap();
    addTearDown(container.dispose);

    await controller.addPart(
      type: NamePartType.givenName,
      originalText: 'Adán',
      dialect: ReadingDialect.latinAmerica,
    );
    await controller.setBridge(ThresholdBridge.oracle, true);
    expect(container.read(nameResonanceProvider(ThresholdBridge.oracle)),
        isNotNull);

    await controller.setBridge(ThresholdBridge.oracle, false);

    expect(container.read(nameResonanceProvider(ThresholdBridge.oracle)), isNull);
    expect(container.read(readingIdentityProvider).value!.bridges, isEmpty);
    expect(memory.value!.bridges, isEmpty);
    expect(memory.value!.toJson()['bridges'], isEmpty);
  });

  test('el perfil cifrado no conserva el puente revocado', () async {
    const secureStorage = FlutterSecureStorage();
    final storage = EncryptedReadingIdentityStorage(
      storage: secureStorage,
      crypto: GrimoireCrypto(),
    );
    final now = DateTime.utc(2026, 8, 15);
    final base = ReadingIdentityProfile(
      parts: const [],
      createdAt: now,
      updatedAt: now,
      bridges: const {ThresholdBridge.oracle},
    );
    await storage.save(base);
    expect((await storage.load())!.bridges, {ThresholdBridge.oracle});

    await storage.save(base.withBridges(const {}, now));
    expect((await storage.load())!.bridges, isEmpty);
  });

  test('un perfil v1 se abre con todos los puentes apagados', () {
    final now = DateTime.utc(2026, 8, 13).toIso8601String();
    final restored = ReadingIdentityProfile.fromJson({
      'schema_version': 1,
      'parts': <Object>[],
      'created_at': now,
      'updated_at': now,
    });
    expect(restored.bridges, isEmpty);
  });

  test('un puente desconocido en el JSON no concede permiso', () {
    final now = DateTime.utc(2026, 8, 15).toIso8601String();
    final restored = ReadingIdentityProfile.fromJson({
      'schema_version': 2,
      'parts': <Object>[],
      'created_at': now,
      'updated_at': now,
      'bridges': ['horoscopo', 'tarot'],
    });
    expect(restored.bridges, {ThresholdBridge.tarot});
  });

  test('un perfil de solo apellidos no cruza ningun puente', () async {
    final (container, controller, _) = await _bootstrap();
    addTearDown(container.dispose);

    await controller.addPart(
      type: NamePartType.surname,
      originalText: 'Rodríguez',
      dialect: ReadingDialect.latinAmerica,
    );
    await controller.setBridge(ThresholdBridge.tarot, true);
    await controller.setBridge(ThresholdBridge.oracle, true);

    for (final bridge in ThresholdBridge.values) {
      expect(container.read(nameResonanceProvider(bridge)), isNull,
          reason: bridge.name);
    }
  });

  test('el apellido no aparece en la resonancia ni con el puente abierto',
      () async {
    final (container, controller, _) = await _bootstrap();
    addTearDown(container.dispose);

    await controller.addPart(
      type: NamePartType.givenName,
      originalText: 'Adán',
      dialect: ReadingDialect.latinAmerica,
    );
    await controller.addPart(
      type: NamePartType.surname,
      originalText: 'ApellidoCanario',
      dialect: ReadingDialect.latinAmerica,
    );
    await controller.setBridge(ThresholdBridge.tarot, true);
    await controller.setBridge(ThresholdBridge.oracle, true);

    final resonance =
        container.read(nameResonanceProvider(ThresholdBridge.tarot))!;
    expect(resonance.givenName, 'Adán');
    expect(resonance.prose, isNot(contains('ApellidoCanario')));
    expect(resonance.oracleClause, isNot(contains('ApellidoCanario')));
  });

  test('borrar el perfil se lleva el consentimiento por delante', () async {
    final (container, controller, memory) = await _bootstrap();
    addTearDown(container.dispose);

    await controller.addPart(
      type: NamePartType.givenName,
      originalText: 'Adán',
      dialect: ReadingDialect.latinAmerica,
    );
    await controller.setBridge(ThresholdBridge.tarot, true);
    await controller.deleteProfile();

    expect(memory.value, isNull);
    expect(container.read(readingIdentityProvider).value, isNull);
    expect(container.read(nameResonanceProvider(ThresholdBridge.tarot)), isNull);
  });

  group('gematria a traves del puente', () {
    test('la forma contemplativa viaja como contemplativa', () async {
      final (container, controller, _) = await _bootstrap();
      addTearDown(container.dispose);

      await controller.addPart(
        type: NamePartType.givenName,
        originalText: 'Adán',
        dialect: ReadingDialect.latinAmerica,
      );
      final partId =
          container.read(readingIdentityProvider).value!.parts.single.id;
      await controller.confirmForm(
        partId: partId,
        pointedHebrew: 'אדם',
        pronunciation: '/adan/',
        origin: HebrewFormOrigin.arcanumContemplative,
        ruleVersion: 'phon-he-1.0.0',
      );
      await controller.setBridge(ThresholdBridge.tarot, true);

      final resonance =
          container.read(nameResonanceProvider(ThresholdBridge.tarot))!;
      expect(resonance.gematriaValue, 45);
      expect(
        resonance.gematriaOriginLabel,
        HebrewFormOrigin.arcanumContemplative.label,
      );
      expect(resonance.gematriaLine, isNot(contains('histórica')));
    });

    test(
      'una tradicion no hebrea no abre gematria historica por el puente',
      () async {
        final (container, controller, _) = await _bootstrap();
        addTearDown(container.dispose);

        // Sofía es tradicion griega: allowsHistoricalGematria == false.
        await controller.addPart(
          type: NamePartType.givenName,
          originalText: 'Sofía',
          dialect: ReadingDialect.latinAmerica,
        );
        final partId =
            container.read(readingIdentityProvider).value!.parts.single.id;
        // Forma marcada como historica pese a la tradicion: el puente debe
        // negarse a mostrarla en vez de degradar la etiqueta.
        await controller.confirmForm(
          partId: partId,
          pointedHebrew: 'סופיה',
          pronunciation: '/sofia/',
          origin: HebrewFormOrigin.historicalDocumented,
          ruleVersion: 'catalog-hebrew-1.0.0',
        );
        await controller.setBridge(ThresholdBridge.tarot, true);

        final resonance =
            container.read(nameResonanceProvider(ThresholdBridge.tarot))!;
        expect(resonance.gematriaValue, isNull);
        expect(resonance.gematriaLine, isNull);
      },
    );
  });

  group('limite editorial del texto de puente', () {
    // El puente sugiere una resonancia; no dicta una interpretacion. Estas
    // formulas convierten una sugerencia en un veredicto sobre la persona.
    const forbidden = [
      'indica que',
      'te corresponde',
      'te hace',
      'significa para ti',
      'tu destino',
      'estas destinad',
      'vas a tener',
      'predice',
      'revela que eres',
      'por tu nombre',
    ];

    test('ninguna prosa de resonancia usa formulas deterministas', () {
      final now = DateTime.utc(2026, 8, 15);
      for (final entryName in ['Adán', 'Sofía', 'NombreSinFicha']) {
        final resonance = NameResonance.fromProfile(
          ReadingIdentityProfile(
            parts: [
              ReadingNamePart(
                id: 'p',
                type: NamePartType.givenName,
                originalText: entryName,
                dialect: ReadingDialect.latinAmerica,
                createdAt: now,
              ),
            ],
            createdAt: now,
            updatedAt: now,
          ),
        )!;
        final texts = [
          resonance.prose,
          resonance.oracleClause ?? '',
          ...ThresholdBridge.values.map((bridge) => bridge.footnote),
          ...ThresholdBridge.values.map((bridge) => bridge.consentCaption),
        ].join(' ').toLowerCase();
        for (final formula in forbidden) {
          expect(texts, isNot(contains(formula)), reason: '$entryName · $formula');
        }
      }
    });
  });
}
