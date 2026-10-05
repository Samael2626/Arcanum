// Humo de la mesa (especificacion §6): al romper el sello y al cerrar el
// circulo, con los numeros del prototipo (`fx.smoke`).
import 'dart:math' as math;

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/tarot/application/table_controller.dart';
import 'package:arcanum_app/features/tarot/table/table_director.dart';
import 'package:arcanum_app/features/tarot/table/table_haptics.dart';
import 'package:arcanum_app/features/tarot/table/table_smoke.dart';
import 'package:arcanum_app/features/tarot/table/table_view.dart';
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

class _Effects extends TableEffects {}

class _Buzzes extends TableHaptics {
  final played = <Buzz>[];
  @override
  Future<void> play(Buzz buzz) async => played.add(buzz);
}

void main() {
  group('una voluta', () {
    final rnd = math.Random(3);
    final wisps = [
      for (var i = 0; i < 200; i++)
        SmokeWisp.at(const Offset(100, 400), Duration.zero, rnd),
    ];

    test('sube, se ensancha y se apaga', () {
      for (final w in wisps) {
        final a = w.at(Duration.zero), b = w.at(const Duration(seconds: 1));
        expect(b.center.dy, lessThan(a.center.dy));
        expect(b.radius, greaterThan(a.radius));
        expect(
          w.lifeAt(const Duration(seconds: 1)),
          lessThan(w.lifeAt(Duration.zero)),
        );
      }
    });

    test('dura entre 1,4 y 2,8 s, como en el prototipo', () {
      expect(
        wisps.every((w) => w.lifeAt(const Duration(milliseconds: 1350)) > 0),
        isTrue,
      );
      expect(
        wisps.every((w) => w.lifeAt(const Duration(milliseconds: 2800)) <= 0),
        isTrue,
      );
    });

    test('sale en una franja de 20 alrededor del punto', () {
      for (final w in wisps) {
        expect((w.x - 100).abs(), lessThanOrEqualTo(10));
        expect(w.y, 400);
        expect(w.r, inInclusiveRange(6, 14));
      }
    });
  });

  group('la capa', () {
    Future<SmokeEmitter> pumpLayer(
      WidgetTester tester, {
      bool still = false,
    }) async {
      final emitter = SmokeEmitter();
      addTearDown(emitter.dispose);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: still),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SmokeLayer(emitter: emitter, random: math.Random(1)),
          ),
        ),
      );
      return emitter;
    }

    SmokePainter? painter(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<SmokePainter>()
        .firstOrNull;

    testWidgets('pinta las volutas pedidas y se apaga sola', (tester) async {
      final e = await pumpLayer(tester);
      expect(painter(tester), isNull);
      e.puff(const Offset(80, 300), 16);
      await tester.pump();
      expect(painter(tester)!.wisps, hasLength(16));
      e.puff(const Offset(200, 300), 26);
      await tester.pump(const Duration(milliseconds: 16));
      expect(painter(tester)!.wisps, hasLength(42));
      for (var i = 0; i < 70; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(painter(tester), isNull, reason: 'a los 3,5 s no queda humo');
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('con «reducir movimiento» no hay humo', (tester) async {
      final e = await pumpLayer(tester, still: true);
      e.puff(const Offset(80, 300), 16);
      await tester.pump();
      expect(painter(tester), isNull);
    });
  });

  group('en la mesa', () {
    testWidgets('romper el sello y cerrar el circulo echan humo y vibran', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      tester.view
        ..physicalSize = const Size(360, 760)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = ProviderContainer(
        overrides: [
          arcanumApiProvider.overrideWithValue(FakeServer()),
          authProvider.overrideWith(_Auth.new),
        ],
      );
      addTearDown(c.dispose);
      await tester.runAsync(() => c.read(tableControllerProvider.future));
      final buzz = _Buzzes();
      final dir = TableDirector(
        ops: c.read(tableControllerProvider.notifier),
        effects: _Effects(),
        haptics: buzz,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: Scaffold(body: TarotTableView(director: dir)),
          ),
        ),
      );
      await tester.pump();
      SmokePainter? painter() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<SmokePainter>()
          .firstOrNull;

      dir.sealBroken();
      await tester.pump();
      final seal = painter()!;
      expect(seal.wisps, hasLength(16));
      final at = dir.camera.toScreen(TableDirector.sealAt);
      expect(
        seal.wisps.every((w) => (w.x - at.dx).abs() <= 10 && w.y == at.dy),
        isTrue,
        reason: 'sale del sello, en pantalla',
      );
      dir.circleClosed();
      await tester.pump();
      expect(painter()!.wisps, hasLength(42));
      expect(buzz.played, [Buzz.breakSeal, Buzz.closeCircle]);

      // en silencio no vibra, pero el humo se ve igual
      dir.muted = true;
      dir.circleClosed();
      await tester.pump();
      expect(buzz.played, hasLength(2));
      expect(painter()!.wisps, hasLength(68));
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
