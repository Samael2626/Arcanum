// La tarjeta de compartir se monta fuera de cuadro y NO debe ocupar sitio.
//
// `Transform.translate` mueve el pintado, no el layout: la tarjeta escondida
// seguia ocupando sus 450 px dentro de la columna y eso era un pegote de
// blanco al final de la pantalla, visto en un movil real. Lo que se prueba
// aqui es la tension entre las dos cosas -- que no ocupe alto, y que se siga
// midiendo entera, porque sin layout no hay capa que capturar y `toImage`
// devolveria una imagen vacia.
import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/privacy/ai_consent_service.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/features/horoscopo/widgets/tarjeta_compartir.dart';
import 'package:arcanum_app/features/hoy/presentation/widgets/sky_today_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {
    'id': 'user-a', 'birth_lat': '4.710000', 'birth_lon': '-74.070000',
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
  _Api() : super(Dio());

  @override
  Future<Map<String, dynamic>> skyToday() async => {
    'date': '2026-09-10', 'day_ruler': 'sun',
    'today': {
      'transit': 'moon', 'natal': 'midheaven', 'aspect': 'trine',
      'angle': 120, 'orb': 0.66, 'separation': 119.34, 'applying': true,
    },
    'chapter': null, 'year': null, 'ingress': null,
    'profection': null, 'sect': 'day', 'total_aspects': 3,
  };

  @override
  Future<Map<String, dynamic>> horoscope({DateTime? day}) async => {
    'date': '2026-09-10', 'requested_date': '2026-09-10',
    'is_previous': false, 'today': null, 'chapter': null,
    'text': 'La Luna llega a trígono con tu Medio Cielo.',
  };

  @override
  Future<Map<String, dynamic>> celestialOverview() async => {};
}

Future<void> _abrir(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        arcanumApiProvider.overrideWithValue(_Api()),
        authProvider.overrideWith(_Auth.new),
        aiConsentServiceProvider.overrideWithValue(_ConsentimientoDado()),
      ],
      child: MaterialApp(
        theme: buildArcanumTheme(),
        home: const Scaffold(
          body: SingleChildScrollView(child: SkyTodayCard()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Abrir el sello del Sol'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('la tarjeta escondida no deja hueco al final', (tester) async {
    await _abrir(tester);

    final finDelBoton = tester.getRect(find.text('Compartir')).bottom;
    final finDeTodo = tester.getRect(find.byType(SkyTodayCard)).bottom;

    // 450 px era el hueco medido con el fallo; lo que queda debajo del boton
    // es el respiro propio de la tarjeta, que ronda los 44.
    expect(
      finDeTodo - finDelBoton,
      lessThan(120),
      reason: 'la tarjeta tiene que acabar donde acaba el contenido real',
    );
  });

  testWidgets('pero se sigue midiendo entera, o no hay nada que capturar',
      (tester) async {
    await _abrir(tester);

    final caja = tester.renderObject<RenderBox>(find.byType(TarjetaCompartir));
    expect(caja.size.height, greaterThan(100));
    expect(caja.size.width, greaterThan(100));

    // Y se pinta lejos: si alguien quita el `Transform`, esto lo caza antes
    // de que la tarjeta duplicada aparezca en mitad de la pantalla.
    expect(tester.getRect(find.byType(TarjetaCompartir)).bottom, lessThan(0));
  });
}
