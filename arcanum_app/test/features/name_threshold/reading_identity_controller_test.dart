import 'package:arcanum_app/features/name_threshold/application/reading_identity_controller.dart';
import 'package:arcanum_app/features/name_threshold/data/reading_identity_repository.dart';
import 'package:arcanum_app/features/name_threshold/domain/reading_identity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

void main() {
  test(
    'cambiar grafia crea resultado nuevo y conserva version anterior',
    () async {
      final memory = _MemoryStorage();
      final container = ProviderContainer(
        overrides: [
          readingIdentityRepositoryProvider.overrideWithValue(
            ReadingIdentityRepository(memory),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(readingIdentityProvider.future);
      final controller = container.read(readingIdentityProvider.notifier);

      await controller.addPart(
        type: NamePartType.givenName,
        originalText: 'José',
        dialect: ReadingDialect.latinAmerica,
      );
      final partId = container
          .read(readingIdentityProvider)
          .value!
          .parts
          .single
          .id;
      await controller.confirmForm(
        partId: partId,
        pointedHebrew: 'חוסה',
        pronunciation: '/xose/',
        origin: HebrewFormOrigin.arcanumContemplative,
        ruleVersion: 'phon-he-1.0.0',
      );
      await controller.confirmForm(
        partId: partId,
        pointedHebrew: 'כוסה',
        pronunciation: '/xose/',
        origin: HebrewFormOrigin.arcanumContemplative,
        ruleVersion: 'phon-he-1.0.0',
      );

      final forms = container
          .read(readingIdentityProvider)
          .value!
          .parts
          .single
          .confirmedForms;
      expect(forms, hasLength(2));
      expect(forms[0].baseHebrew, 'חוסה');
      expect(forms[0].value, 79);
      expect(forms[1].baseHebrew, 'כוסה');
      expect(forms[1].value, 91);
      expect(forms[0].resultId, isNot(forms[1].resultId));
    },
  );
}
