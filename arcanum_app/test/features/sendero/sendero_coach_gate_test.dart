import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/sendero/application/sendero_controller.dart';
import 'package:arcanum_app/features/sendero/application/sendero_guide_controller.dart';
import 'package:arcanum_app/features/sendero/domain/sendero_catalog.dart';
import 'package:arcanum_app/features/sendero/presentation/sendero_coach_gate.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api extends ArcanumApi {
  _Api(this.remote) : super(Dio());

  final List<Map<String, dynamic>> remote;
  final saved = <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> senderoProgress() async => remote;

  @override
  Future<Map<String, dynamic>> updateSenderoProgress({
    required String journeyId,
    required int version,
    required int step,
    required String status,
  }) async {
    final row = {
      'journey_id': journeyId,
      'version': version,
      'step': step,
      'status': status,
      'reward_fragments': 0,
    };
    saved.add(row);
    return row;
  }
}

class _Auth extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(AuthStatus.authenticated, {'id': 'coach-user'});
}

Map<String, dynamic> _completed(String id, int version, int step) => {
  'journey_id': id,
  'version': version,
  'step': step,
  'status': 'completed',
};

GoRouter _router() {
  late final GoRouter router;
  router = GoRouter(
    initialLocation: '/hoy',
    routes: [
      ShellRoute(
        builder: (_, _, child) =>
            SenderoCoachGate(router: router, child: child),
        routes: [
          GoRoute(
            path: '/hoy',
            builder: (_, _) => const Scaffold(body: Text('CIELO')),
          ),
          GoRoute(
            path: '/saber',
            builder: (_, _) => const Scaffold(body: Text('SABER')),
          ),
          GoRoute(
            path: '/horoscopo',
            builder: (_, _) => const Scaffold(body: Text('HOROSCOPO')),
          ),
        ],
      ),
    ],
  );
  return router;
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _Api api,
  GoRouter router,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        arcanumApiProvider.overrideWithValue(api),
        authProvider.overrideWith(_Auth.new),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.text('CIELO')));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('pista por seccion aparece una vez y no concede Fragmentos', (
    tester,
  ) async {
    final api = _Api([_completed('orientation', 2, 2)]);
    final router = _router();
    addTearDown(router.dispose);
    await _mount(tester, api, router);

    expect(find.text('Sendero en Cielo'), findsOneWidget);
    expect(api.saved.where((row) => row['journey_id'] == 'cielo'), isEmpty);
    await tester.tap(find.text('Ahora no'));
    await tester.pump();
    router.go('/saber');
    await tester.pumpAndSettle();
    expect(find.text('Sendero en Saber'), findsOneWidget);
    await tester.tap(find.text('Ahora no'));
    await tester.pump();
    router.go('/hoy');
    await tester.pumpAndSettle();
    expect(find.text('Sendero en Cielo'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('sendero_context_seen_coach-user'),
      containsAll(['cielo:2', 'saber:2']),
    );
  });

  testWidgets('desvio conserva paso y ofrece explorar la seccion actual', (
    tester,
  ) async {
    final api = _Api([]);
    final router = _router();
    addTearDown(router.dispose);
    final container = await _mount(tester, api, router);
    final guide = container.read(senderoGuideProvider.notifier);
    guide.start(senderoJourneyById('orientation')!);
    guide.onAction('menu');
    await guide.idle;
    router.go('/saber');
    await tester.pumpAndSettle();

    expect(find.text('Sendero te sigue'), findsOneWidget);
    expect(container.read(senderoGuideProvider)?.step, 1);
    expect(find.text('Volver a Cielo'), findsOneWidget);
    expect(find.text('Explorar Saber'), findsOneWidget);
    expect(find.text('Pausar'), findsOneWidget);
    await tester.tap(find.text('Volver a Cielo'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/hoy');
    expect(container.read(senderoGuideProvider)?.step, 1);
    expect(find.text('Abre el menú para continuar'), findsOneWidget);
    router.go('/saber');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explorar Saber'));
    await tester.pump();
    expect(container.read(senderoGuideProvider)?.journey.id, 'saber');
    final saved = container
        .read(senderoControllerProvider)
        .value?['orientation:2'];
    expect(saved?.step, 1);
    expect(saved?.status, 'in_progress');

    guide.start(senderoJourneyById('orientation')!, saved: saved);
    expect(container.read(senderoGuideProvider)?.step, 1);
  });

  testWidgets('al completar sugiere la siguiente sin abrirla', (tester) async {
    final api = _Api([
      _completed('orientation', 2, 2),
      _completed('cielo', 2, 1),
    ]);
    final router = _router();
    addTearDown(router.dispose);
    final container = await _mount(tester, api, router);

    container
        .read(senderoCompletionProvider.notifier)
        .show(senderoJourneyById('cielo')!, 1);
    await tester.pump();
    expect(find.text('Lección recorrida'), findsOneWidget);
    expect(find.textContaining('Un Fragmento Arcano despertó'), findsOneWidget);
    expect(find.text('Explorar Horóscopo'), findsOneWidget);
    expect(container.read(senderoGuideProvider), isNull);
    await tester.tap(find.text('Ahora no'));
    await tester.pump();
    expect(container.read(senderoGuideProvider), isNull);
  });

  testWidgets('la revelacion usa el incremento confirmado por servidor', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    final container = await _mount(tester, _Api([]), router);

    container
        .read(senderoCompletionProvider.notifier)
        .show(senderoJourneyById('orientation')!, 3);
    await tester.pump();

    expect(
      find.textContaining('3 Fragmentos Arcanos despertaron'),
      findsOneWidget,
    );
    expect(find.textContaining('Un Fragmento Arcano despertó'), findsNothing);
  });

  test('borrar cuenta limpia las pistas locales', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('sendero_context_seen_coach-user', ['cielo:2']);
    await clearSenderoLocalData();
    expect(prefs.containsKey('sendero_context_seen_coach-user'), isFalse);
  });
}
