import 'dart:math' as math;

import 'package:arcanum_app/features/tarot/table/table_sound.dart';
import 'package:arcanum_app/features/tarot/table/table_sound_player.dart';
import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/tarot/application/table_controller.dart';
import 'package:arcanum_app/features/tarot/table/table_panel.dart';
import 'package:arcanum_app/features/tarot/tarot_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {'id': 'u1'});
}

/// El servidor de la mesa, con los catalogos y las lecturas que pide la pantalla.
class _Server extends FakeServer {
  @override
  Future<List<Map<String, dynamic>>> tarotDecks() async => [
    {
      'slug': 'rws',
      'name': 'Rider–Waite–Smith',
      'description': '',
      'allow_reversed': true,
      'art': 'rws',
      'card_count': 78,
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> tarotSpreads() async => [];

  @override
  Future<List<Map<String, dynamic>>> tarotReadings({int limit = 20}) async =>
      [];
}

void main() {
  group('donde sale el panel', () {
    const screen = Size(390, 800);
    const panel = Size(300, 160);
    BoxConstraints loose() => BoxConstraints.loose(screen);

    test('encima de lo tocado, centrado sobre ello', () {
      final at = const PanelLayout(
        Rect.fromLTWH(170, 500, 50, 80),
      ).getPositionForChild(screen, panel);
      expect(at.dy + panel.height, 500 - TablePanel.gap);
      expect(at.dx + panel.width / 2, 195);
    });

    test('si arriba no cabe, debajo', () {
      final at = const PanelLayout(
        Rect.fromLTWH(170, 60, 50, 80),
      ).getPositionForChild(screen, panel);
      expect(at.dy, 140 + TablePanel.gap);
    });

    test('pegado a un borde no se sale de la pantalla', () {
      final left = const PanelLayout(
        Rect.fromLTWH(0, 500, 40, 60),
      ).getPositionForChild(screen, panel);
      final right = const PanelLayout(
        Rect.fromLTWH(370, 500, 40, 60),
      ).getPositionForChild(screen, panel);
      expect(left.dx, TablePanel.margin);
      expect(right.dx + panel.width, screen.width - TablePanel.margin);
    });

    test('nunca mas ancho que la pantalla ni mas alto que el 60 %', () {
      final c = const PanelLayout(Rect.zero).getConstraintsForChild(loose());
      expect(c.maxWidth, TablePanel.maxWidth);
      expect(c.maxHeight, screen.height * .6);
      final narrow = const PanelLayout(
        Rect.zero,
      ).getConstraintsForChild(BoxConstraints.loose(const Size(320, 600)));
      expect(narrow.maxWidth, 320 - 2 * TablePanel.margin);
    });
  });

  testWidgets('tocar fuera del panel lo cierra', (tester) async {
    var closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned.fill(
              child: TablePanel(
                anchor: const Rect.fromLTWH(150, 500, 60, 90),
                title: 'Pregunta abierta',
                onClose: () => closed++,
                child: const Text('«¿Qué viene?»'),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PREGUNTA ABIERTA'), findsOneWidget);
    await tester.tap(find.text('«¿Qué viene?»'));
    expect(closed, 0, reason: 'tocar dentro no cierra');
    await tester.tapAt(const Offset(20, 20));
    expect(closed, 1);
  });

  group('en la pantalla de la mesa', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      Map<String, Object> prefs = const {},
    }) async {
      SharedPreferences.setMockInitialValues(prefs);
      FlutterSecureStorage.setMockInitialValues({});
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = ProviderContainer(
        overrides: [
          tableSoundPlayerProvider.overrideWithValue(const SilentPlayer()),
          arcanumApiProvider.overrideWithValue(_Server()),
          authProvider.overrideWith(_Auth.new),
        ],
      );
      addTearDown(c.dispose);
      await tester.runAsync(() => c.read(tableControllerProvider.future));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: TarotTableScreen()),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // la ayuda de gestos sale la primera vez y tapa la mesa
      if (find.text('Entendido').evaluate().isNotEmpty) {
        await tester.tap(find.text('Entendido'));
        await tester.pump(const Duration(seconds: 1));
      }
    }

    /// Mantiene el dedo en el paño hasta que abre su radial y elige `label`.
    Future<void> clothMenu(WidgetTester tester, String label) async {
      final g = await tester.startGesture(const Offset(195, 300));
      // la mesa cuenta el tiempo con un reloj real
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 480)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      // orden fijo del radial del paño: la primera arriba y luego en el
      // sentido del reloj (Sellar pregunta, Recoger todo, Lecturas, Silenciar)
      expect(find.text(label), findsOneWidget);
      const order = [
        'Sellar pregunta',
        'Recoger todo',
        'Lecturas',
        'Silenciar',
      ];
      final angle =
          -math.pi / 2 + order.indexOf(label) * 2 * math.pi / order.length;
      final target =
          const Offset(195, 300) +
          Offset(math.cos(angle), math.sin(angle)) * 90;
      await g.moveTo(target);
      await tester.pump();
      await g.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('sellar la pregunta se escribe en un panel junto al sello', (
      tester,
    ) async {
      await pumpScreen(tester);
      await clothMenu(tester, 'Sellar pregunta');
      expect(find.text('SELLAR LA PREGUNTA'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.enterText(find.byType(TextField), '¿Qué viene?');
      await tester.tap(find.text('Sellar').last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('SELLAR LA PREGUNTA'), findsNothing);
      expect(find.bySemanticsLabel('Pregunta sellada'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('las lecturas salen en un panel y atras lo cierra', (
      tester,
    ) async {
      await pumpScreen(tester);
      await clothMenu(tester, 'Lecturas');
      expect(find.text('LECTURAS GUARDADAS'), findsOneWidget);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      expect(
        find.text('Todavía no has cerrado ningún círculo.'),
        findsOneWidget,
      );
      // atras cierra el panel y la mesa sigue
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('LECTURAS GUARDADAS'), findsNothing);
      expect(find.byType(TarotTableScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Silenciar apaga la vibracion y se recuerda al volver', (
      tester,
    ) async {
      await pumpScreen(tester);
      await clothMenu(tester, 'Silenciar');
      expect(find.text('Mesa en silencio: ni suena ni vibra.'), findsOneWidget);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(TarotTableScreen.mutedKey), isTrue);

      // al volver a entrar, el radial del paño ofrece volver a oir
      await tester.pumpWidget(const SizedBox());
      await pumpScreen(tester, prefs: {TarotTableScreen.mutedKey: true});
      final g = await tester.startGesture(const Offset(195, 300));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 480)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('Sonido'), findsOneWidget);
      expect(find.text('Silenciar'), findsNothing);
      await g.up();
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
