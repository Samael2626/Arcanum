// La lectura de otro día se declara antes del texto, no después.
//
// El plan gratuito genera una interpretación cada dos días: el segundo recibe
// la anterior. Lo que se prueba aquí es que eso NO se disfraza de lectura nueva
// y que el sello de arriba sigue siendo el de hoy.
import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/privacy/ai_consent_service.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/features/hoy/presentation/widgets/sky_today_card.dart';
import 'package:arcanum_app/shared/widgets/ai_output.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {
    'id': 'user-a',
    'birth_lat': '4.710000',
    'birth_lon': '-74.070000',
  });
}

/// Consiente sin preguntar: el diálogo ya tiene sus propios tests y aquí
/// estorbaría al único gesto que importa.
class _ConsentimientoDado extends AiConsentService {
  @override
  Future<bool> ensureGranted(
    BuildContext context, {
    required String userId,
    bool forcePrompt = false,
  }) async => true;
}

class _Api extends ArcanumApi {
  _Api({required this.esAnterior}) : super(Dio());

  final bool esAnterior;

  @override
  Future<Map<String, dynamic>> skyToday() async => {
    'date': '2026-09-05',
    'day_ruler': 'sun',
    'today': {
      'transit': 'moon', 'natal': 'midheaven', 'aspect': 'trine',
      'angle': 120, 'orb': 0.66, 'separation': 119.34, 'applying': true,
    },
    'chapter': null, 'year': null, 'ingress': null,
    'profection': null, 'sect': 'day', 'total_aspects': 3,
  };

  @override
  Future<Map<String, dynamic>> horoscope() async => {
    'date': esAnterior ? '2026-09-04' : '2026-09-05',
    'requested_date': '2026-09-05',
    'is_previous': esAnterior,
    'text': 'La Luna llega a trígono con tu Medio Cielo.',
    'today': null, 'chapter': null,
  };

  @override
  Future<Map<String, dynamic>> celestialOverview() async => {};
}

Future<void> _abrir(WidgetTester tester, {required bool esAnterior}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        arcanumApiProvider.overrideWithValue(_Api(esAnterior: esAnterior)),
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

/// El texto vive DOS veces en el árbol: en la pantalla y en la tarjeta que se
/// comparte, montada fuera de cuadro para poder capturarla. Los finders se
/// acotan a la lectura visible.
Finder _lecturaVisible(String texto) => find.descendant(
  of: find.byType(AiOutput),
  matching: find.text(texto),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('una lectura de otro día lo dice, con su fecha', (tester) async {
    await _abrir(tester, esAnterior: true);

    expect(find.text('Esta es tu lectura del 4 de septiembre.'), findsOneWidget);
    expect(find.textContaining('El cielo de arriba sí es el de hoy'), findsOneWidget);
    expect(find.text('Ver la suscripción'), findsOneWidget);
  });

  testWidgets('el aviso va ANTES del texto, no después', (tester) async {
    await _abrir(tester, esAnterior: true);

    final aviso = tester.getTopLeft(
      find.text('Esta es tu lectura del 4 de septiembre.'),
    );
    final texto = tester.getTopLeft(
      _lecturaVisible('La Luna llega a trígono con tu Medio Cielo.'),
    );
    expect(aviso.dy, lessThan(texto.dy),
        reason: 'leerlo creyendo que es de hoy y enterarse al final es peor '
            'que no tenerlo');
  });

  testWidgets('la lectura del día no lleva ningún aviso', (tester) async {
    await _abrir(tester, esAnterior: false);

    expect(find.textContaining('Esta es tu lectura'), findsNothing);
    expect(_lecturaVisible('La Luna llega a trígono con tu Medio Cielo.'),
        findsOneWidget);
  });
}
