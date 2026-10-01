import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/sendero/application/sendero_controller.dart';
import 'package:arcanum_app/features/sendero/application/sendero_guide_controller.dart';
import 'package:arcanum_app/features/sendero/domain/sendero_catalog.dart';
import 'package:arcanum_app/features/sendero/presentation/sendero_invitation.dart';
import 'package:arcanum_app/features/sendero/presentation/sendero_screen.dart';
import 'package:arcanum_app/features/sendero/presentation/sendero_spotlight.dart';
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

class _SpotlightFixture extends ConsumerWidget {
  const _SpotlightFixture({required this.targetAtBottom});

  final bool targetAtBottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetKey = ref.read(senderoGuideTargetsProvider).keyFor('menu');
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: targetAtBottom ? 700 : 40,
            left: 40,
            child: SizedBox(key: targetKey, width: 48, height: 48),
          ),
          Positioned.fill(
            child: SenderoSpotlight(
              guide: SenderoGuideState(
                journey: senderoJourneyById('orientation')!,
                step: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
    final guide = container.read(senderoGuideProvider.notifier);
    guide.start(journey);
    guide.onAction('horoscope_card');
    expect(container.read(senderoGuideProvider)?.step, 0);
    guide.onAction('menu');
    expect(container.read(senderoGuideProvider)?.step, 1);
    guide.pause();
    expect(container.read(senderoGuideProvider), isNull);

    await guide.idle;
    guide.start(
      journey,
      saved: container.read(senderoControllerProvider).value?['orientation:2'],
    );
    expect(container.read(senderoGuideProvider)?.step, 1);
    guide.onAction('section_horoscopo');
    guide.onAction('horoscope_card');
    expect(container.read(senderoGuideProvider), isNull);
    await guide.idle;
    expect(
      container
          .read(senderoControllerProvider)
          .value?['orientation:2']
          ?.isCompleted,
      isTrue,
    );
    expect(
      container.read(senderoCompletionProvider)?.journey.id,
      'orientation',
    );

    guide.start(
      journey,
      saved: container.read(senderoControllerProvider).value?['orientation:2'],
    );
    expect(container.read(senderoGuideProvider)?.step, 0);
    guide.pause();
  });

  testWidgets('hub muestra todas las camaras y estado completado', (
    tester,
  ) async {
    final api = _SenderoApi()
      ..remote = [
        {
          'journey_id': 'orientation',
          'version': 2,
          'step': 2,
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

  testWidgets('invitacion no bloquea la app mientras el usuario explora', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arcanumApiProvider.overrideWithValue(_SenderoApi()),
          authProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        ],
        child: MaterialApp(
          home: SenderoInvitationGate(
            child: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('Explorar Cielo'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('sendero_invitation_card')),
      findsOneWidget,
    );
    await tester.tap(find.text('Explorar Cielo'));
    await tester.pump();
    expect(taps, 1);
    expect(
      find.byKey(const ValueKey('sendero_invitation_card')),
      findsOneWidget,
    );
  });

  testWidgets('invitacion inicia guia sobre Cielo sin abrir el hub', (
    tester,
  ) async {
    final api = _SenderoApi();
    final router = GoRouter(
      initialLocation: '/hoy',
      routes: [
        GoRoute(
          path: '/hoy',
          builder: (_, _) =>
              const SenderoInvitationGate(child: Scaffold(body: Text('CIELO'))),
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
    await tester.tap(find.text('Empezar guía'));
    await tester.pumpAndSettle();

    expect(find.text('CIELO'), findsOneWidget);
    expect(find.byType(SenderoScreen), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.text('CIELO')),
    );
    expect(container.read(senderoGuideProvider)?.journey.id, 'orientation');
    expect(container.read(senderoGuideProvider)?.step, 0);
  });

  for (final targetAtBottom in [false, true]) {
    testWidgets(
      'el cartel sigue al objetivo sin taparlo: ${targetAtBottom ? 'abajo' : 'arriba'}',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: _SpotlightFixture(targetAtBottom: targetAtBottom),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(_SpotlightFixture)),
        );
        final target = tester.getRect(
          find.byKey(
            container.read(senderoGuideTargetsProvider).keyFor('menu'),
          ),
        );
        final card = tester.getRect(
          find.byKey(const ValueKey('sendero_guide_card')),
        );
        if (targetAtBottom) {
          expect(card.bottom, lessThan(target.top));
        } else {
          expect(card.top, greaterThan(target.bottom));
        }
      },
    );
  }
}
