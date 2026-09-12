// La tirada por la TRADICIÓN, dentro de Consultar.
//
// Antes vivía en `features/tarot/tarot_screen.dart`, una pantalla entera
// colgada de `/oraculo/tarot` a la que no llegaba ni un `push` ni un `go` en
// 329 commits. El caso de la clave de idempotencia venía de aquel test y se
// conserva íntegro: es la garantía de que un reintento no cobra dos veces.
//
// Lo nuevo es la puerta: el selector de intérprete. Se prueba que existe, que
// cambia de endpoint de verdad, y que al volver no deja puesta una tirada que
// la otra vía no sabe leer.
import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/features/oraculo/oraculo_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(AuthStatus.authenticated, {'id': 'test-user'});
}

class _Api extends ArcanumApi {
  _Api({this.fallaLaPrimera = false}) : super(Dio());

  final bool fallaLaPrimera;
  final List<String?> clavesClasicas = [];
  int llamadasAlOraculo = 0;

  @override
  Future<Map<String, dynamic>> tarotDrawOne({
    String? question,
    String? idempotencyKey,
  }) async {
    clavesClasicas.add(idempotencyKey);
    if (fallaLaPrimera && clavesClasicas.length == 1) {
      throw StateError('offline');
    }
    return {
      'id': 'lectura-1',
      'resolved': [
        {
          'slug': 'the-fool',
          'name': 'El Loco',
          'arcana': 'major',
          'reversed': false,
          'title_book_t': 'The Spirit of Aether',
          'meaning': 'El salto que todavía no sabe dónde cae.',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> tarotDraw(
    String spread, {
    String? idempotencyKey,
  }) async {
    llamadasAlOraculo++;
    return {
      'id': 'sesion-1',
      'cards_drawn': {
        'cards': [
          {'slug': 'the-fool', 'name': 'El Loco', 'drawn_upright': true},
        ],
      },
    };
  }
}

Future<void> _abrir(WidgetTester tester, _Api api) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        arcanumApiProvider.overrideWithValue(api),
        authProvider.overrideWith(_Auth.new),
      ],
      child: MaterialApp(
        theme: buildArcanumTheme(),
        home: const Scaffold(body: OraculoScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _elegirTradicion(WidgetTester tester) async {
  await tester.tap(find.text('Tradición'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la puerta existe y arranca en el oráculo', (tester) async {
    await _abrir(tester, _Api());

    // Discreto: un renglón con las dos vías a la vista.
    expect(find.text('LEE'), findsOneWidget);
    expect(find.text('Oráculo'), findsOneWidget);
    expect(find.text('Tradición'), findsOneWidget);
    // Y el renglón que paga el término, sin esperar a que lo toques.
    expect(
      find.text('Un modelo interpreta tu tirada y responde.'),
      findsOneWidget,
    );
    // Por defecto manda el oráculo, y entonces el aviso de IA es verdad.
    expect(find.textContaining('modelo de IA'), findsOneWidget);
    expect(find.text('Consultar al oráculo'), findsOneWidget);
  });

  testWidgets('la tradición no anuncia una IA que no interviene', (
    tester,
  ) async {
    await _abrir(tester, _Api());
    await _elegirTradicion(tester);

    expect(find.textContaining('modelo de IA'), findsNothing);
    // Las dos siguen a la vista: lo que cambia es cuál está marcada, y lo que
    // dice el renglón de debajo.
    expect(find.text('Oráculo'), findsOneWidget);
    expect(find.text('Tradición'), findsOneWidget);
    expect(
      find.text(
        'El significado del Book T, tal cual. Sin IA, pero cuenta como tirada.',
      ),
      findsOneWidget,
    );
    // "Sin IA" no puede leerse como "gratis": las dos vias gastan el mismo
    // cupo diario en el servidor, y el renglon de los limites lo dice.
    expect(find.textContaining('descuenta de tu cupo diario'), findsOneWidget);
    // Y aparece la tirada que solo sirve esta vía.
    expect(find.text('Una carta'), findsOneWidget);
  });

  testWidgets('tira de verdad por el endpoint clásico y trae el Book T', (
    tester,
  ) async {
    final api = _Api();
    await _abrir(tester, api);
    await _elegirTradicion(tester);

    await tester.tap(find.text('Una carta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sacar una carta'));
    await tester.pumpAndSettle();

    expect(api.clavesClasicas, hasLength(1));
    expect(api.llamadasAlOraculo, 0, reason: 'la vía clásica no toca la IA');
    expect(
      find.text('El salto que todavía no sabe dónde cae.'),
      findsOneWidget,
    );
    // Y no ofrece interpretar: no hay sesión que interpretar.
    expect(find.text('Pedir interpretación'), findsNothing);
  });

  testWidgets('volver al oráculo no deja puesta la tirada de la otra vía', (
    tester,
  ) async {
    final api = _Api();
    await _abrir(tester, api);
    await _elegirTradicion(tester);
    await tester.tap(find.text('Una carta'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Oráculo'));
    await tester.pumpAndSettle();

    // "Una carta" no existe en `/oracle/tarot/draw`: si sobreviviera, el botón
    // llamaría a una tirada que ese endpoint no sirve.
    expect(find.text('Una carta'), findsNothing);
    expect(find.text('Consultar al oráculo'), findsOneWidget);
  });

  testWidgets('las dos vías se pueden tocar sin fallar', (tester) async {
    await _abrir(tester, _Api());
    for (final rotulo in ['Oráculo', 'Tradición']) {
      final caja = tester.getRect(
        find
            .ancestor(of: find.text(rotulo), matching: find.byType(InkWell))
            .first,
      );
      expect(
        caja.height,
        greaterThanOrEqualTo(48),
        reason: '$rotulo se queda por debajo de lo que se puede tocar',
      );
    }
  });

  testWidgets('la vía activa no se puede volver a tocar', (tester) async {
    await _abrir(tester, _Api());
    // Arranca en el oráculo: tocarlo otra vez no hace nada, y el InkWell lo
    // dice con onTap nulo en vez de fingir que responde.
    final activo = tester.widget<InkWell>(
      find
          .ancestor(of: find.text('Oráculo'), matching: find.byType(InkWell))
          .first,
    );
    expect(activo.onTap, isNull);
  });

  testWidgets('un reintento reutiliza la clave y una tirada nueva la cambia', (
    tester,
  ) async {
    final api = _Api(fallaLaPrimera: true);
    await _abrir(tester, api);
    await _elegirTradicion(tester);
    await tester.tap(find.text('Una carta'));
    await tester.pumpAndSettle();

    final boton = find.text('Sacar una carta');
    await tester.tap(boton);
    await tester.pumpAndSettle();
    // El fallo se cuenta sin filtrar la traza: ni 'offline' ni 'StateError'.
    expect(find.textContaining('offline'), findsNothing);
    expect(find.textContaining('StateError'), findsNothing);

    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(api.clavesClasicas, hasLength(2));
    expect(api.clavesClasicas.first, isNotNull);
    expect(
      api.clavesClasicas[1],
      api.clavesClasicas.first,
      reason: 'reintentar lo mismo no puede cobrar dos veces',
    );
  });
}
