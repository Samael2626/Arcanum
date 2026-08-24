import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arcanum_app/features/onboarding/application/onboarding_controller.dart';
import 'package:arcanum_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/auth/auth_repository.dart';
import 'package:arcanum_app/core/auth/token_storage.dart';

class _OfflineAuthRepository extends AuthRepository {
  _OfflineAuthRepository() : super(Dio(), TokenStorage());

  @override
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    throw AuthException('offline test');
  }
}

/// Repositorio que sí acepta el perfil y anota lo que recibió, para verificar
/// que el reintento manda los datos REALES y no un default.
class _RecordingAuthRepository extends AuthRepository {
  _RecordingAuthRepository() : super(Dio(), TokenStorage());

  final sent = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    sent.add(data);
    return data;
  }
}

void main() {
  // Use an in-memory mock for SharedPreferences so the controller can read/write
  // without touching real storage.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final authRepository = _OfflineAuthRepository();

  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
  );

  Widget wrap() => ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
    child: const MaterialApp(home: OnboardingScreen()),
  );

  testWidgets('starts on welcome step and shows sigil + title', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();
    expect(find.text('Bienvenido a tu grimorio'), findsOneWidget);
    expect(find.text('⛧'), findsOneWidget);
    expect(find.text('Comenzar'), findsOneWidget);
  });

  testWidgets('has no back button on the first step', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();
    // AppBar leading is null on step 0
    final back = find.byTooltip('Back');
    expect(back, findsNothing);
  });

  testWidgets('pide autorizacion sensible separada antes de datos natales', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Comenzar'));
    await tester.pump();

    expect(find.text('Tus datos sensibles'), findsOneWidget);
    expect(find.textContaining('Entregarlos es voluntario'), findsOneWidget);
    expect(find.text('Acepto compartirlos'), findsOneWidget);
    expect(find.text('Continuar sin datos sensibles'), findsOneWidget);
  });

  testWidgets('next advances step and back retreats it', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final notifier = container.read(onboardingProvider.notifier);
    expect(container.read(onboardingProvider).step, 0);
    notifier.next();
    expect(container.read(onboardingProvider).step, 1);
    notifier.next();
    expect(container.read(onboardingProvider).step, 2);
    notifier.back();
    expect(container.read(onboardingProvider).step, 1);
  });

  testWidgets('setters persist data into OnboardingData', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final notifier = container.read(onboardingProvider.notifier);

    await notifier.setDisplayName('Samael');
    final dob = DateTime(1990, 5, 12);
    await notifier.setBirthDate(dob);
    await notifier.setBirthTime('13:42');
    await notifier.setBirthCountry('Colombia');
    await notifier.setBirthCity('Bogotá');

    final data = container.read(onboardingProvider).data;
    expect(data.displayName, 'Samael');
    expect(data.birthDate, dob);
    expect(data.birthTime, '13:42');
    expect(data.birthCountry, 'Colombia');
    expect(data.birthCity, 'Bogotá');
  });

  testWidgets(
    'finish sin lugar resuelto falla ruidoso (nunca default oculto)',
    (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(onboardingProvider.notifier);
      notifier.setSensitiveDataConsent(true);

      expect(() => notifier.finish(), throwsA(isA<StateError>()));
    },
  );

  testWidgets('finish no persiste datos sensibles sin autorizacion', (
    tester,
  ) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final notifier = container.read(onboardingProvider.notifier);
    notifier.setResolvedLocation(
      displayName: 'Bogotá, Colombia',
      lat: '4.710000',
      lon: '-74.070000',
      timezone: 'America/Bogota',
    );

    expect(() => notifier.finish(), throwsA(isA<StateError>()));
  });

  testWidgets('rechazo completa onboarding sin datos sensibles', (
    tester,
  ) async {
    final online = _RecordingAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(online)],
    );
    addTearDown(container.dispose);

    await container
        .read(onboardingProvider.notifier)
        .finishWithoutSensitiveData();

    expect(online.sent, [
      {'onboarding_completed': true},
    ]);
  });

  testWidgets(
    'finish flips onboarding_completed to true tras confirmar lugar',
    (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(onboardingProvider.notifier);
      notifier.setSensitiveDataConsent(true);

      notifier.setResolvedLocation(
        displayName: 'Bogotá, Colombia',
        lat: '4.710000',
        lon: '-74.070000',
        timezone: 'America/Bogota',
      );

      expect(await notifier.isCompleted(), isFalse);
      await notifier.finish();
      expect(await notifier.isCompleted(), isTrue);
    },
  );

  testWidgets('reset clears completion flag', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final notifier = container.read(onboardingProvider.notifier);
    notifier.setSensitiveDataConsent(true);

    notifier.setResolvedLocation(
      displayName: 'Bogotá, Colombia',
      lat: '4.710000',
      lon: '-74.070000',
      timezone: 'America/Bogota',
    );
    await notifier.finish();
    expect(await notifier.isCompleted(), isTrue);
    await notifier.reset();
    expect(await notifier.isCompleted(), isFalse);
  });

  // ── Perfil pendiente: el fallo de red no puede perder los datos ──────────
  //
  // Bug real (2026-07-21): finish() tragaba el fallo de updateProfile y marcaba
  // el onboarding completo igual. El comentario prometía un reintento "en el
  // próximo arranque autenticado" que NO existía: updateProfile solo se
  // llamaba desde aquí. Resultado: fecha, hora y lugar de nacimiento se
  // quedaban solo en el dispositivo, el onboarding no volvía a mostrarse, y la
  // carta natal era imposible (422) para siempre, sin arreglo posible.
  group('perfil pendiente de reintento', () {
    const kPending = 'onboarding_pending_profile';

    void confirmPlace(OnboardingNotifier n) {
      n.setSensitiveDataConsent(true);
      n.setResolvedLocation(
        displayName: 'Bogotá, Colombia',
        lat: '4.710000',
        lon: '-74.070000',
        timezone: 'America/Bogota',
      );
    }

    testWidgets('un fallo de red encola el perfil en vez de perderlo', (
      tester,
    ) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(onboardingProvider.notifier);

      confirmPlace(notifier);
      await notifier.setBirthCity('Bogotá');
      await notifier.finish();

      // El flujo no se bloquea…
      expect(await notifier.isCompleted(), isTrue);

      // …pero los datos quedan guardados para reintentarlos.
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kPending);
      expect(raw, isNotNull, reason: 'el perfil debe quedar encolado');

      final payload = jsonDecode(raw!) as Map<String, dynamic>;
      expect(payload['birth_lat'], '4.710000');
      expect(payload['birth_lon'], '-74.070000');
      expect(payload['birth_timezone'], 'America/Bogota');
      expect(payload['birth_city'], 'Bogotá');
      expect(payload['onboarding_completed'], isTrue);
    });

    testWidgets('el reintento envía el perfil encolado y lo limpia', (
      tester,
    ) async {
      final online = _RecordingAuthRepository();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(online)],
      );
      addTearDown(container.dispose);

      SharedPreferences.setMockInitialValues({
        kPending: jsonEncode({
          'onboarding_completed': true,
          'birth_lat': '4.710000',
          'birth_timezone': 'America/Bogota',
        }),
      });

      final notifier = container.read(onboardingProvider.notifier);
      expect(await notifier.flushPendingProfile(), isTrue);

      expect(online.sent, hasLength(1));
      expect(online.sent.single['birth_lat'], '4.710000');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(kPending),
        isNull,
        reason: 'enviado con éxito, no debe reintentarse otra vez',
      );
    });

    testWidgets('sin nada encolado, el reintento no llama al backend', (
      tester,
    ) async {
      final online = _RecordingAuthRepository();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(online)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(onboardingProvider.notifier);
      expect(await notifier.flushPendingProfile(), isFalse);
      expect(online.sent, isEmpty);
    });

    testWidgets('si el reintento vuelve a fallar, el perfil se conserva', (
      tester,
    ) async {
      final container = makeContainer(); // repositorio offline
      addTearDown(container.dispose);

      SharedPreferences.setMockInitialValues({
        kPending: jsonEncode({'birth_lat': '4.710000'}),
      });

      final notifier = container.read(onboardingProvider.notifier);
      await tryFlushPendingProfile(notifier); // no debe propagar

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(kPending),
        isNotNull,
        reason: 'sigue pendiente para el próximo arranque',
      );
    });

    testWidgets('borrar la cuenta elimina el perfil pendiente', (tester) async {
      // Si sobreviviera, los datos de nacimiento de un usuario se enviarían
      // a la cuenta siguiente en el mismo dispositivo.
      SharedPreferences.setMockInitialValues({
        kPending: jsonEncode({'birth_lat': '4.710000'}),
        'onboarding_completed': true,
      });

      await clearOnboardingLocalData();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kPending), isNull);
      expect(prefs.getBool('onboarding_completed'), isNull);
    });

    testWidgets('reset también limpia el perfil pendiente', (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(onboardingProvider.notifier);

      confirmPlace(notifier);
      await notifier.finish();
      expect(
        (await SharedPreferences.getInstance()).getString(kPending),
        isNotNull,
      );

      await notifier.reset();
      expect(
        (await SharedPreferences.getInstance()).getString(kPending),
        isNull,
      );
    });
  });

  testWidgets('isLast is true on step 5', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final n = container.read(onboardingProvider.notifier);
    n.next();
    n.next();
    n.next();
    n.next();
    n.next();
    expect(container.read(onboardingProvider).step, 5);
    expect(container.read(onboardingProvider).isLast, isTrue);
    expect(container.read(onboardingProvider).isFirst, isFalse);
  });
}
