// Saber sale a la practica: al pie de la ficha de una planta (y de un sello)
// estan «Anotar en el Grimorio» y, si tiene planeta, «Su hora en Cielo».
//
// Se fija que cada enlace aparece solo con su dato, que abre su destino real y
// que el titulo llega precargado al editor sin pasar por el cifrado.
import 'dart:async';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/monetization/monetization_service.dart';
import 'package:arcanum_app/core/state/flow_providers.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/features/arte/arte_screen.dart';
import 'package:arcanum_app/features/grimorio/grimorio_editor.dart';
import 'package:arcanum_app/features/saber/sellos/sello_modelo.dart';
import 'package:arcanum_app/features/saber/sellos/sellos_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(AuthStatus.authenticated, {'id': 'user-a'});
}

class _Api extends ArcanumApi {
  _Api() : super(Dio());

  @override
  Future<List<Map<String, dynamic>>> materiaList({
    String? itemType,
    String? planet,
    String? q,
  }) async => const [
    {
      'slug': 'romero',
      'item_type': 'herb',
      'name': 'Romero',
      'planet': 'sun',
      'element': 'fire',
    },
    {
      'slug': 'sal',
      'item_type': 'stone',
      'name': 'Sal',
      'planet': null,
      'element': 'earth',
    },
  ];

  @override
  Future<Map<String, dynamic>> materiaDetail(String slug) async => {
    'properties': {'fuente': 'Culpeper'},
  };

  @override
  // sin puente que pintar: la seccion se queda esperando y no ocupa sitio
  Future<Map<String, dynamic>> materiaBridge(String slug) =>
      Completer<Map<String, dynamic>>().future;
}

void _pantallaAlta(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<ProviderContainer> _montarPlantas(WidgetTester tester) async {
  _pantallaAlta(tester);
  final container = ProviderContainer(
    overrides: [
      arcanumApiProvider.overrideWithValue(_Api()),
      authProvider.overrideWith(_Auth.new),
      subscriptionProvider.overrideWith(
        (ref) => Stream.value(const SubscriptionState()),
      ),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: '/saber',
    routes: [
      GoRoute(
        path: '/saber',
        builder: (_, _) => const Scaffold(body: ArteScreen()),
      ),
      GoRoute(path: '/hoy', builder: (_, _) => const Text('PANTALLA CIELO')),
      GoRoute(
        path: '/grimorio',
        builder: (_, _) => const Text('PANTALLA GRIMORIO'),
      ),
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
  return container;
}

Future<void> _abrirFicha(WidgetTester tester, String nombre) async {
  await tester.tap(find.text(nombre).first);
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, String texto) async {
  final f = find.text(texto);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ficha de una planta', () {
    testWidgets('con planeta ofrece anotar y su hora', (tester) async {
      await _montarPlantas(tester);
      await _abrirFicha(tester, 'Romero');
      expect(find.text('Anotar en el Grimorio'), findsOneWidget);
      expect(find.text('Su hora en Cielo'), findsOneWidget);
    });

    testWidgets('sin planeta no se inventa la hora', (tester) async {
      await _montarPlantas(tester);
      await _abrirFicha(tester, 'Sal');
      expect(find.text('Anotar en el Grimorio'), findsOneWidget);
      expect(find.text('Su hora en Cielo'), findsNothing);
    });

    testWidgets('Anotar abre el editor del Grimorio con el nombre', (
      tester,
    ) async {
      final c = await _montarPlantas(tester);
      await _abrirFicha(tester, 'Romero');
      await _tocar(tester, 'Anotar en el Grimorio');
      expect(c.read(grimoireComposeProvider), isTrue);
      expect(c.read(grimoireComposeTitleProvider), 'Romero');
      expect(find.text('PANTALLA GRIMORIO'), findsOneWidget);
    });

    testWidgets('Su hora en Cielo abre la cara Ahora', (tester) async {
      final c = await _montarPlantas(tester);
      c.read(cieloCaraProvider.notifier).set(1);
      await _abrirFicha(tester, 'Romero');
      await _tocar(tester, 'Su hora en Cielo');
      expect(c.read(cieloCaraProvider), 0);
      expect(find.text('PANTALLA CIELO'), findsOneWidget);
    });

    testWidgets('los enlaces miden al menos 48 dp', (tester) async {
      await _montarPlantas(tester);
      await _abrirFicha(tester, 'Romero');
      for (final t in ['Anotar en el Grimorio', 'Su hora en Cielo']) {
        await tester.ensureVisible(find.text(t));
        await tester.pumpAndSettle();
        final boton = find.ancestor(
          of: find.text(t),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        );
        expect(tester.getSize(boton.first).height, greaterThanOrEqualTo(48));
      }
    });
  });

  group('ficha de un sello', () {
    late CatalogoSellos cat;

    setUpAll(() async {
      cat = CatalogoSellos.parse(
        await rootBundle.loadString(CatalogoSellos.assetPath),
      );
    });

    Future<void> montar(
      WidgetTester tester, {
      ValueChanged<SelloPieza>? onAnnotate,
      ValueChanged<SelloPieza>? onPlanetHour,
    }) async {
      _pantallaAlta(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildArcanumTheme(),
          home: Scaffold(
            body: SellosScreen(
              catalogoOverride: Future.value(cat),
              onAnnotate: onAnnotate,
              onPlanetHour: onPlanetHour,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('un sello planetario ofrece anotar y su hora', (tester) async {
      SelloPieza? anotado;
      SelloPieza? hora;
      await montar(
        tester,
        onAnnotate: (p) => anotado = p,
        onPlanetHour: (p) => hora = p,
      );
      await tester.tap(find.text('Sello').first);
      await tester.pumpAndSettle();
      expect(find.text('Su hora en Cielo'), findsOneWidget);
      await _tocar(tester, 'Anotar en el Grimorio');
      expect(anotado?.planet, isNotNull);
      // la ficha se cierra al salir hacia la practica
      expect(find.text('Anotar en el Grimorio'), findsNothing);
      expect(hora, isNull);
    });

    testWidgets('Su hora en Cielo entrega la pieza con su planeta', (
      tester,
    ) async {
      SelloPieza? hora;
      await montar(tester, onAnnotate: (_) {}, onPlanetHour: (p) => hora = p);
      await tester.tap(find.text('Sello').first);
      await tester.pumpAndSettle();
      await _tocar(tester, 'Su hora en Cielo');
      expect(hora?.planet, isNotNull);
    });

    testWidgets('un sello de la Goetia no tiene planeta: solo anotar', (
      tester,
    ) async {
      await montar(tester, onAnnotate: (_) {}, onPlanetHour: (_) {});
      final goetia = cat.de('goetia1916').first;
      expect(goetia.planet, isNull);
      await tester.tap(find.text('Goetia'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(goetia.name!).first);
      await tester.pumpAndSettle();
      expect(find.text('Anotar en el Grimorio'), findsOneWidget);
      expect(find.text('Su hora en Cielo'), findsNothing);
    });

    testWidgets('sin quien navegue, la ficha no muestra enlaces', (
      tester,
    ) async {
      await montar(tester);
      await tester.tap(find.text('Sello').first);
      await tester.pumpAndSettle();
      expect(find.text('Anotar en el Grimorio'), findsNothing);
      expect(find.text('Su hora en Cielo'), findsNothing);
    });
  });

  group('editor del Grimorio', () {
    testWidgets('acepta un titulo precargado', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildArcanumTheme(),
            home: const GrimorioEditor(initialTitle: 'Romero'),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (w) => w is EditableText && w.controller.text == 'Romero',
        ),
        findsOneWidget,
      );
    });
  });
}
