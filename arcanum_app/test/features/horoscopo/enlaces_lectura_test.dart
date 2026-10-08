// El horoscopo ya no es un callejon: al pie de la lectura salen la carta natal
// y, si el cielo trae regente del dia, las plantas de ese regente.
//
// Lo que se fija: que los enlaces aparecen solo con la lectura abierta, que el
// de plantas NO se inventa un planeta que no vino, y que cada uno abre su
// destino real (cara de Cielo o Saber filtrado).
import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/privacy/ai_consent_service.dart';
import 'package:arcanum_app/core/state/flow_providers.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/features/hoy/presentation/widgets/sky_today_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {
    'id': 'user-a',
    'birth_lat': '4.710000',
    'birth_lon': '-74.070000',
  });
}

class _ConsentimientoDado extends AiConsentService {
  @override
  Future<bool> ensureGranted(
    BuildContext context, {
    required String userId,
    bool forcePrompt = false,
  }) async => true;
}

class _Api extends ArcanumApi {
  _Api(this.regente) : super(Dio());

  final String? regente;

  @override
  Future<Map<String, dynamic>> skyToday() async => {
    'date': '2026-09-05',
    'day_ruler': regente,
    'today': {
      'transit': 'moon',
      'natal': 'midheaven',
      'aspect': 'trine',
      'angle': 120,
      'orb': 0.66,
      'separation': 119.34,
      'applying': true,
    },
    'chapter': null,
    'year': null,
    'ingress': null,
    'profection': null,
    'sect': 'day',
    'total_aspects': 3,
  };

  @override
  Future<Map<String, dynamic>> horoscope({DateTime? day}) async => {
    'date': '2026-09-05',
    'requested_date': '2026-09-05',
    'is_previous': false,
    'text': 'La Luna llega a trígono con tu Medio Cielo.',
    'today': null,
    'chapter': null,
  };

  @override
  Future<Map<String, dynamic>> celestialOverview() async => {};
}

Future<ProviderContainer> _montar(
  WidgetTester tester, {
  required String? regente,
  bool abrir = true,
}) async {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      arcanumApiProvider.overrideWithValue(_Api(regente)),
      authProvider.overrideWith(_Auth.new),
      aiConsentServiceProvider.overrideWithValue(_ConsentimientoDado()),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: '/horoscopo',
    routes: [
      GoRoute(
        path: '/horoscopo',
        builder: (_, _) =>
            const Scaffold(body: SingleChildScrollView(child: SkyTodayCard())),
      ),
      GoRoute(path: '/hoy', builder: (_, _) => const Text('PANTALLA CIELO')),
      GoRoute(path: '/saber', builder: (_, _) => const Text('PANTALLA SABER')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: buildArcanumTheme(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (abrir) {
    await tester.tap(find.textContaining('Abrir el sello'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }
  return container;
}

Future<void> _tocar(WidgetTester tester, String texto) async {
  final f = find.text(texto);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('con el sello cerrado no hay enlaces todavia', (tester) async {
    await _montar(tester, regente: 'sun', abrir: false);
    expect(find.text('Ver tu carta'), findsNothing);
    expect(find.text('Plantas del Sol'), findsNothing);
  });

  testWidgets('la lectura abierta ofrece la carta y las plantas del regente', (
    tester,
  ) async {
    await _montar(tester, regente: 'sun');
    expect(find.text('Ver tu carta'), findsOneWidget);
    expect(find.text('Plantas del Sol'), findsOneWidget);
  });

  testWidgets('el articulo va bien puesto: de Marte, de la Luna', (
    tester,
  ) async {
    await _montar(tester, regente: 'mars');
    expect(find.text('Plantas de Marte'), findsOneWidget);
  });

  testWidgets('sin regente en los datos no se inventa el enlace de plantas', (
    tester,
  ) async {
    await _montar(tester, regente: null);
    expect(find.text('Ver tu carta'), findsOneWidget);
    expect(find.textContaining('Plantas de'), findsNothing);
  });

  testWidgets('Ver tu carta abre Cielo en la cara de la carta natal', (
    tester,
  ) async {
    final c = await _montar(tester, regente: 'sun');
    expect(c.read(cieloCaraProvider), 0);
    await _tocar(tester, 'Ver tu carta');
    expect(c.read(cieloCaraProvider), 1);
    expect(find.text('PANTALLA CIELO'), findsOneWidget);
  });

  testWidgets('Plantas del regente abre Saber filtrado por ese planeta', (
    tester,
  ) async {
    final c = await _montar(tester, regente: 'venus');
    await _tocar(tester, 'Plantas de Venus');
    expect(c.read(materiaPlanetProvider), 'venus');
    expect(find.text('PANTALLA SABER'), findsOneWidget);
  });

  testWidgets('los enlaces miden al menos 48 dp de alto', (tester) async {
    await _montar(tester, regente: 'sun');
    for (final t in ['Ver tu carta', 'Plantas del Sol']) {
      final boton = find.ancestor(
        of: find.text(t),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(tester.getSize(boton.first).height, greaterThanOrEqualTo(48));
    }
  });
}
