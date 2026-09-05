// El arranque en frío: sin sesión, la app termina en /login.
//
// ESTO ES EL TEST DEL FALLO QUE BLOQUEÓ LA PRUEBA CERRADA. La app arrancaba en
// /hoy sin ninguna redirección, y Hoy era la única pantalla principal sin
// guarda: un tester recién instalado veía la luna y "No disponible sin tu
// lugar", sin una sola mención de la sesión ni forma de entrar desde ahí.
import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/router/app_router.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/features/auth/login_screen.dart';
import 'package:arcanum_app/features/auth/register_screen.dart';
import 'package:arcanum_app/features/hoy/hoy_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Una sesión que empieza donde se le diga y puede entrar a mitad del test.
class _AuthDePrueba extends AuthNotifier {
  static AuthStatus inicial = AuthStatus.unauthenticated;

  @override
  AuthState build() => AuthState(inicial, inicial == AuthStatus.authenticated
      ? const {'id': 'user-a', 'birth_lat': '4.71', 'birth_lon': '-74.07'}
      : null);

  void entrar() => state = const AuthState(AuthStatus.authenticated, {
    'id': 'user-a',
    'birth_lat': '4.71',
    'birth_lon': '-74.07',
  });
}

/// La app no debe llamar a nadie para decidir a dónde va.
class _ApiMuda extends ArcanumApi {
  _ApiMuda() : super(Dio());

  @override
  Future<Map<String, dynamic>> moon() async => {
    'illumination': 0.34, 'is_waxing': false,
    'phase_name': 'Cuarto Menguante', 'age_days': 24.0,
  };

  @override
  Future<Map<String, dynamic>> today({
    required double lat,
    required double lon,
  }) async => {
    'day_ruler': 'sun',
    'planetary_hour': {
      'planet': 'venus', 'minutes_remaining': 38,
      'is_daytime': true, 'hour_number': 4,
    },
    'moon': {
      'illumination': 0.34, 'is_waxing': false,
      'phase_name': 'Cuarto Menguante', 'age_days': 24.0,
    },
  };

  @override
  Future<Map<String, dynamic>> skyToday() async => {
    'date': '2026-09-05', 'day_ruler': 'sun', 'today': null, 'chapter': null,
    'year': null, 'ingress': null, 'profection': null, 'sect': 'day',
    'total_aspects': 0,
  };
}

Future<ProviderContainer> _arrancar(
  WidgetTester tester, {
  String? ruta,
  AuthStatus sesion = AuthStatus.unauthenticated,
}) async {
  _AuthDePrueba.inicial = sesion;
  final contenedor = ProviderContainer(
    overrides: [
      arcanumApiProvider.overrideWithValue(_ApiMuda()),
      authProvider.overrideWith(_AuthDePrueba.new),
    ],
  );
  addTearDown(contenedor.dispose);

  final router = contenedor.read(arcanumRouterProvider);
  if (ruta != null) router.go(ruta);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: contenedor,
      child: MaterialApp.router(
        theme: buildArcanumTheme(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return contenedor;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('sin sesión, cualquier ruta acaba en login', () {
    testWidgets('el arranque en frío no se queda en Hoy', (tester) async {
      await _arrancar(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HoyScreen), findsNothing);
    });

    for (final ruta in ['/hoy', '/cielos', '/grimorio', '/saber', '/oraculo',
                        '/horoscopo', '/perfil', '/settings', '/paywall']) {
      testWidgets('$ruta redirige a login', (tester) async {
        await _arrancar(tester, ruta: ruta);
        expect(find.byType(LoginScreen), findsOneWidget);
      });
    }

    testWidgets('pero registrarse sigue siendo alcanzable', (tester) async {
      await _arrancar(tester, ruta: '/register');
      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('el login no ofrece cerrarse: no hay nada que cerrar', (
      tester,
    ) async {
      // La X llevaba a /hoy, y la guarda devolvia aqui mismo: un boton que no
      // hacia nada. Con sesion, esta pantalla ya no se alcanza.
      await _arrancar(tester);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('y desde login se llega a crear cuenta', (tester) async {
      await _arrancar(tester);
      await tester.tap(find.text('¿Aún no tienes cuenta? Regístrate'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
    });
  });

  group('con sesión', () {
    testWidgets('la app arranca en Hoy', (tester) async {
      await _arrancar(tester, sesion: AuthStatus.authenticated);
      expect(find.byType(HoyScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('entrar desde login devuelve a Hoy sin tocar nada más', (
      tester,
    ) async {
      final contenedor = await _arrancar(tester);
      expect(find.byType(LoginScreen), findsOneWidget);

      // Lo que hace el botón "Entrar" cuando el servidor responde bien.
      (contenedor.read(authProvider.notifier) as _AuthDePrueba).entrar();
      await tester.pumpAndSettle();

      expect(find.byType(HoyScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('y ya no se puede volver a la pantalla de login', (
      tester,
    ) async {
      final contenedor = await _arrancar(
        tester,
        sesion: AuthStatus.authenticated,
      );
      contenedor.read(arcanumRouterProvider).go('/login');
      await tester.pumpAndSettle();

      expect(find.byType(HoyScreen), findsOneWidget);
    });
  });

  group('mientras se lee el token guardado', () {
    testWidgets('no se decide nada todavía', (tester) async {
      // Redirigir en `unknown` haría parpadear el login en CADA apertura de
      // quien sí tiene sesión: un fallo peor que el que se está arreglando.
      await _arrancar(tester, sesion: AuthStatus.unknown);
      expect(find.byType(LoginScreen), findsNothing);
    });
  });

  group('el router ya no es una variable global', () {
    testWidgets('cada arranque tiene el suyo, en su sitio de partida', (
      tester,
    ) async {
      // Siendo global, la ubicacion sobrevivia entre tests: uno que navegaba
      // dejaba al siguiente empezando donde lo dejo. Ya paso una vez.
      final a = await _arrancar(tester, sesion: AuthStatus.authenticated);
      a.read(arcanumRouterProvider).go('/perfil');
      await tester.pumpAndSettle();

      final b = ProviderContainer(
        overrides: [
          arcanumApiProvider.overrideWithValue(_ApiMuda()),
          authProvider.overrideWith(_AuthDePrueba.new),
        ],
      );
      addTearDown(b.dispose);

      expect(identical(a.read(arcanumRouterProvider),
          b.read(arcanumRouterProvider)), isFalse);
      // `currentConfiguration` esta vacia hasta que un widget lo monta; lo que
      // ya existe al construirlo es su punto de partida.
      expect(
        b.read(arcanumRouterProvider).routeInformationProvider.value.uri.path,
        '/hoy',
      );
      expect(
        a.read(arcanumRouterProvider).routerDelegate.currentConfiguration.uri
            .path,
        '/perfil',
        reason: 'el primero se movio, y eso no puede contagiar al segundo',
      );
    });
  });
}
