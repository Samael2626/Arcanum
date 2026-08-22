/// El sello del cielo, comprobado donde se ve.
///
/// Lo que se fija: que NO genere nada hasta que se rompe el lacre, que el lacre
/// lleve el glifo del regente del dia, que se muestre la separacion REAL, y que
/// un cielo sin transitos lo diga en vez de inventarse una figura.
import 'package:arcanum_app/features/hoy/presentation/widgets/sello_del_cielo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _trigono = {
  'transit': 'moon',
  'natal': 'midheaven',
  'aspect': 'trine',
  'angle': 120,
  'orb': 0.66,
  'separation': 119.34,
};

Future<void> _montar(
  WidgetTester tester, {
  Map<String, dynamic>? aspecto = _trigono,
  String? regente = 'venus',
  bool abierto = false,
  VoidCallback? onAbrir,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SelloDelCielo(
        aspecto: aspecto,
        regente: regente,
        abierto: abierto,
        onAbrir: onAbrir ?? () {},
      ),
    ),
  ));
}

void main() {
  testWidgets('cerrado, invita a romper el lacre', (tester) async {
    await _montar(tester);
    expect(find.text('ROMPER EL LACRE'), findsOneWidget);
  });

  testWidgets('NO genera nada hasta que se toca', (tester) async {
    var llamadas = 0;
    await _montar(tester, onAbrir: () => llamadas++);
    // El fallo que esto previene: la tarjeta anterior generaba el horoscopo al
    // construirse, o sea al abrir la app, leyera alguien o no.
    expect(llamadas, 0);

    await tester.tap(find.byType(SelloDelCielo));
    await tester.pump();
    expect(llamadas, 1);
  });

  testWidgets('ya abierto no vuelve a disparar', (tester) async {
    var llamadas = 0;
    await _montar(tester, abierto: true, onAbrir: () => llamadas++);
    await tester.tap(find.byType(SelloDelCielo));
    await tester.pump();
    // La sorpresa se gasta una vez al dia, y eso es lo que la hace valer.
    expect(llamadas, 0);
    expect(find.text('ROMPER EL LACRE'), findsNothing);
  });

  testWidgets('el lacre lleva el glifo del regente del día', (tester) async {
    await _montar(tester, regente: 'venus');
    expect(find.text('♀'), findsOneWidget);
  });

  testWidgets('sin regente, el lacre no se queda vacío', (tester) async {
    await _montar(tester, regente: null);
    expect(find.text('✦'), findsOneWidget);
  });

  testWidgets('nombra el tránsito en español, ángulos incluidos',
      (tester) async {
    await _montar(tester);
    // `midheaven` no esta en el mapa de planetas: si no se tradujera aparte,
    // saldria la clave cruda en una app en espanol.
    expect(find.text('Luna trígono Medio Cielo'), findsOneWidget);
  });

  testWidgets('muestra la separación REAL, no el ángulo nominal',
      (tester) async {
    await _montar(tester);
    // 119,3 y no 120: es la razon de ser de toda la pieza.
    expect(find.textContaining('119,3'), findsOneWidget);
    expect(find.textContaining('120,0'), findsNothing);
  });

  testWidgets('sin separación lo declara en vez de inventarla', (tester) async {
    await _montar(tester, aspecto: {
      'transit': 'moon', 'natal': 'sun', 'aspect': 'square', 'angle': 90,
    });
    expect(find.textContaining('no disponible'), findsOneWidget);
  });

  testWidgets('un cielo sin tránsitos lo dice y no dibuja nada',
      (tester) async {
    await _montar(tester, aspecto: null);
    expect(find.textContaining('en calma'), findsOneWidget);
    expect(find.text('ROMPER EL LACRE'), findsNothing);
  });

  testWidgets('en reposo no hay animación corriendo', (tester) async {
    // El guardian de rendimiento de Hoy existe por esto. `pumpAndSettle`
    // se cuelga si algo anima para siempre.
    await _montar(tester);
    await tester.pumpAndSettle();
    expect(find.text('ROMPER EL LACRE'), findsOneWidget);
  });
}
