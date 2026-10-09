import 'package:arcanum_app/features/onboarding/application/pending_profile_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'onboarding_pending_profile': '{"birth_city":"Bogotá"}',
      'onboarding_birth_date': '2000-01-01',
      'onboarding_birth_city': 'Bogotá',
    });
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'descarta el legado sin dueño y solo entrega el perfil a su cuenta',
    () async {
      final store = SecurePendingProfileStore();
      expect(await store.readFor('user-a'), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('onboarding_pending_profile'), isNull);
      expect(prefs.getString('onboarding_birth_date'), isNull);
      expect(prefs.getString('onboarding_birth_city'), isNull);

      await store.save('user-a', {'birth_city': 'Bogotá'});
      expect(await store.readFor('user-b'), isNull);
      expect(await store.readFor('user-a'), {'birth_city': 'Bogotá'});
      expect(prefs.getString('onboarding_pending_profile'), isNull);

      await store.clear();
      expect(await store.readFor('user-a'), isNull);
    },
  );
}
