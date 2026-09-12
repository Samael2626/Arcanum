// Las cuatro inconsistencias menores que cerró la entrega 5.
//
// Cada una salió del mapa de navegación, no de un fallo reportado: son cosas
// que solo se ven cuando se pone el árbol entero delante. Se prueban juntas
// porque son la misma clase de deuda — dos sitios que hacen lo mismo de dos
// maneras — y porque así se ve de un vistazo si alguna vuelve.
import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/features/cielos/cielos_screen.dart';
import 'package:arcanum_app/features/saber/saber_screen.dart';
import 'package:arcanum_app/shared/widgets/login_prompt.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SinSesion extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.unauthenticated, null);
}

/// Saber monta Plantas y Biblioteca a la vez, y las dos piden su catalogo al
/// construirse. Sin doblarlo, las llamadas se van al Dio real y el test muere
/// con temporizadores pendientes.
class _ApiMuda extends ArcanumApi {
  _ApiMuda() : super(Dio());

  @override
  Future<List<Map<String, dynamic>>> materiaList({
    String? itemType,
    String? planet,
    String? q,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> libraryWorks() async => [];

  @override
  Future<List<Map<String, dynamic>>> allProgress() async => [];
}

Future<void> _montar(WidgetTester tester, Widget pantalla) async {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        arcanumApiProvider.overrideWithValue(_ApiMuda()),
        authProvider.overrideWith(_SinSesion.new),
      ],
      child: MaterialApp(
        theme: buildArcanumTheme(),
        home: Scaffold(body: pantalla),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Cielos usa el aviso de sesión COMPARTIDO', (tester) async {
    // Tenía uno propio, calcado del compartido pero con su glifo escrito a
    // mano en un `TextStyle` crudo — o sea, sin el respaldo de la fuente de
    // glifos. Grimorio, Oráculo y la tradición ya usaban el compartido.
    await _montar(tester, const CielosScreen());
    expect(find.byType(LoginPrompt), findsOneWidget);
    expect(find.text('Tu cielo te espera'), findsOneWidget);
  });

  testWidgets('el conmutador de Saber se puede tocar sin fallar', (
    tester,
  ) async {
    // Se quedó en 40 dp desde que se escribió; el de Cielo nació con 48.
    await _montar(tester, const SaberScreen());
    await tester.pump();
    for (final rotulo in ['Plantas', 'Biblioteca']) {
      final caja = tester.getRect(
        find.ancestor(
          of: find.text(rotulo),
          matching: find.byType(InkWell),
        ).first,
      );
      expect(
        caja.height,
        greaterThanOrEqualTo(48),
        reason: '$rotulo se queda por debajo de lo que se puede tocar',
      );
    }
  });
}
