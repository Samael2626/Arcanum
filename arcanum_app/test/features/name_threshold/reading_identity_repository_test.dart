import 'package:arcanum_app/core/crypto/grimoire_crypto.dart';
import 'package:arcanum_app/features/name_threshold/data/reading_identity_repository.dart';
import 'package:arcanum_app/features/name_threshold/domain/reading_identity.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('perfil queda cifrado y el texto plano no aparece en storage', () async {
    const canary = 'NombreCanarioPrivado';
    const secureStorage = FlutterSecureStorage();
    final storage = EncryptedReadingIdentityStorage(
      storage: secureStorage,
      crypto: GrimoireCrypto(),
    );
    final now = DateTime.utc(2026, 8, 13);
    final profile = ReadingIdentityProfile(
      parts: [
        ReadingNamePart(
          id: 'part-a',
          type: NamePartType.givenName,
          originalText: canary,
          dialect: ReadingDialect.latinAmerica,
          createdAt: now,
          confirmedForms: [
            ConfirmedHebrewForm(
              resultId: 'result-a',
              pointedHebrew: 'שֵׁם',
              baseHebrew: 'שם',
              pronunciation: '/sem/',
              origin: HebrewFormOrigin.userProvided,
              ruleVersion: 'user-provided-1.0.0',
              gematriaVersion: 'mispar-hechrechi-1.0.0',
              letters: const [
                GematriaLetter('ש', 300),
                GematriaLetter('ם', 40),
              ],
              value: 340,
              confirmedAt: now,
            ),
          ],
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );

    await storage.save(profile);
    final all = await secureStorage.readAll();
    expect(all.values.join(), isNot(contains(canary)));
    expect(all.values.join(), isNot(contains('שם')));
    expect((await storage.load())!.parts.single.originalText, canary);
  });

  test('borrar elimina todo el perfil local', () async {
    const secureStorage = FlutterSecureStorage();
    final storage = EncryptedReadingIdentityStorage(storage: secureStorage);
    final now = DateTime.utc(2026, 8, 13);
    await storage.save(
      ReadingIdentityProfile(parts: const [], createdAt: now, updatedAt: now),
    );
    await storage.delete();
    expect(await storage.load(), isNull);
  });
}
