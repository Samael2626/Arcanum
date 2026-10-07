import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/sendero/application/sendero_controller.dart';
import 'package:arcanum_app/features/sendero/application/sendero_guide_controller.dart';
import 'package:arcanum_app/features/sendero/domain/sendero_catalog.dart';
import 'package:arcanum_app/features/sendero/presentation/sendero_invitation.dart';
import 'package:arcanum_app/features/sendero/presentation/sendero_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SenderoApi extends ArcanumApi {
  _SenderoApi() : super(Dio());

  final saved = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> remote = [];

  @override
  Future<List<Map<String, dynamic>>> senderoProgress() async => remote;

  @override
  Future<Map<String, dynamic>> updateSenderoProgress({
    required String journeyId,
    required int version,
    required int step,
    required String status,
  }) async {
    final value = {
      'journey_id': journeyId,
      'version': version,
      'step': step,
      'status': status,
    };
    saved.add(value);
    return value;
  }
}

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(AuthStatus.authenticated, {'id': 'sendero-test-user'});
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('avance local es monotono y completar es terminal', () async {
    final api = _SenderoApi();
    final container = ProviderContainer(
      overrides: [
        arcanumApiProvider.overrideWithValue(api),
        authProvider.overrideWith(_AuthenticatedAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(senderoControllerProvider.future);

    final notifier = container.read(senderoControllerProvider.notifier);
    await notifier.advance(journeyId: 'cielo', version: 1, step: 1);
    await notifier.advance(
      journeyId: 'cielo',
      version: 1,
      step: 0,
      status: 'completed',
    );
    await notifier.advance(journeyId: 'cielo', version: 1, step: 0);

    final progress = container
        .read(senderoControllerProvider)
        .value!['cielo:1']!;
    expect(progress.step, 1);
    expect(progress.status, 'completed');
    expect(api.saved.last['status'], 'completed');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('sendero_progress_v1_sendero-test-user'), isTrue);
  });

  // Actualizado el 07-oct-2026: el Primer umbral ya no pasa por el menu (las
  // secciones viven en los mosaicos de la portada), asi que tocar el menu
  // tampoco cuenta. Lo que se vigila es lo de siempre: solo el gesto esperado
  // avanza, se puede pausar y retomar, y repetir tras completar empieza de 0.
  test('guia avanza solo por el gesto esperado y permite repetir', () async {
    final api = _SenderoApi();
    final container = ProviderContainer(
      overrides: [
        arcanumApiProvider.overrideWithValue(api),
        authProvider.overrideWith(_AuthenticatedAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(senderoControllerProvider.future);

    final journey = senderoJourneyById('orientation')!;
    final saved = 'orientation:${journey.version}';
    final guide = container.read(senderoGuideProvider.notifier);
    guide.start(journey);
    guide.onAction('help');
    expect(container.read(senderoGuideProvider)?.step, 0);
    guide.onAction('menu');
    expect(container.read(senderoGuideProvider)?.step, 0);
    guide.onAction('section_horoscopo');
    expect(container.read(senderoGuideProvider)?.step, 1);
    guide.pause();
    expect(container.read(senderoGuideProvider), isNull);

    // Retoma donde se quedo: la ayuda existe en cualquier seccion.
    await guide.idle;
    guide.start(
      journey,
      saved: container.read(senderoControllerProvider).value?[saved],
    );
    expect(container.read(senderoGuideProvider)?.step, 1);
    guide.onAction('section_horoscopo');
    expect(container.read(senderoGuideProvider)?.step, 1);
    guide.onAction('help');
    expect(container.read(senderoGuideProvider), isNull);
    await guide.idle;
    expect(
      container.read(senderoControllerProvider).value?[saved]?.isCompleted,
      isTrue,
    );

    guide.start(
      journey,
      saved: container.read(senderoControllerProvider).value?[saved],
    );
    expect(container.read(senderoGuideProvider)?.step, 0);
    guide.pause();
  });

  // Un paso que depende de algo abierto (el cajon, para Ajustes) no se retoma
  // a medias: al volver el cajon esta cerrado, y se empieza por abrirlo. Antes
  // lo vigilaba el Primer umbral, cuando su segundo paso era el del menu.
  test('guia retoma desde el principio si el paso pide el cajon', () async {
    final api = _SenderoApi();
    final container = ProviderContainer(
      overrides: [
        arcanumApiProvider.overrideWithValue(api),
        authProvider.overrideWith(_AuthenticatedAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(senderoControllerProvider.future);

    final journey = senderoJourneyById('account')!;
    final guide = container.read(senderoGuideProvider.notifier);
    guide.start(journey);
    guide.onAction('settings');
    expect(container.read(senderoGuideProvider)?.step, 0);
    guide.onAction('menu');
    expect(container.read(senderoGuideProvider)?.step, 1);
    guide.pause();

    await guide.idle;
    guide.start(
      journey,
      saved: container
          .read(senderoControllerProvider)
          .value?['account:${journey.version}'],
    );
    expect(container.read(senderoGuideProvider)?.step, 0);
    guide.pause();
  });

  testWidgets('hub muestra todas las camaras y estado completado', (
    tester,
  ) async {
    // La version sale del catalogo y no va escrita: el progreso cuenta por
    // version, y el 07-oct-2026 el Primer umbral subio a la 3 con la portada
    // nueva. Con un 2 fijo, el hub lo daba por no explorado.
    final api = _SenderoApi()
      ..remote = [
        {
          'journey_id': 'orientation',
          'version': senderoJourneyById('orientation')!.version,
          'step': 1,
          'status': 'completed',
        },
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arcanumApiProvider.overrideWithValue(api),
          authProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        ],
        child: const MaterialApp(home: SenderoScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        '1 de ${senderoJourneys.where((journey) => journey.available).length} recorridos explorados.',
      ),
      findsOneWidget,
    );
    expect(find.text('Primer umbral'), findsOneWidget);
    expect(find.text('Cielo'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Fragmentos Arcanos'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Fragmentos Arcanos'), findsOneWidget);
  });

  testWidgets('primera entrada lleva la guia a Cielo y permite pausarla', (
    tester,
  ) async {
    final api = _SenderoApi();
    final router = GoRouter(
      initialLocation: '/sendero',
      routes: [
        GoRoute(path: '/sendero', builder: (_, _) => const SenderoScreen()),
        GoRoute(
          path: '/hoy',
          builder: (_, _) => const Scaffold(body: Text('CIELO')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arcanumApiProvider.overrideWithValue(api),
          authProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CIELO'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.text('CIELO')),
    );
    expect(container.read(senderoGuideProvider)?.journey.id, 'orientation');
    container.read(senderoGuideProvider.notifier).pause();
    await tester.pump();
    expect(container.read(senderoGuideProvider), isNull);
    expect(find.text('CIELO'), findsOneWidget);
  });

  testWidgets('invitacion permite no recordarlo y sincroniza la decision', (
    tester,
  ) async {
    final api = _SenderoApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arcanumApiProvider.overrideWithValue(api),
          authProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        ],
        child: const MaterialApp(
          home: SenderoInvitationGate(child: Scaffold(body: Text('CIELO'))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Una guía breve para recorrer ARCANUM a tu ritmo. Puedes dejarla en cualquier momento.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('No recordarlo'));
    await tester.pumpAndSettle();

    expect(api.saved.last['status'], 'dismissed');
    expect(find.text('CIELO'), findsOneWidget);
  });
}
