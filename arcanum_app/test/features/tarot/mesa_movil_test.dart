// Fallos de la mesa vistos en el GN2200 (03-oct-2026, `.qa-mesa/gn2200-caos-cartas.png`)
// reproducidos sin pantalla: carta que sale enorme, toques que se pierden con
// la red lenta, cartas sueltas encima de la tirada, abanico que tapa sello y
// bordado, y camara que deja la mesa fuera de pantalla.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/tarot/application/table_controller.dart';
import 'package:arcanum_app/features/tarot/domain/table_models.dart';
import 'package:arcanum_app/features/tarot/domain/table_state.dart';
import 'package:arcanum_app/features/tarot/table/gesture_grammar.dart';
import 'package:arcanum_app/features/tarot/table/table_camera.dart';
import 'package:arcanum_app/features/tarot/table/table_director.dart';
import 'package:arcanum_app/features/tarot/table/table_geometry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {'id': 'u1'});
}

class _Effects extends TableEffects {
  final toasts = <String>[];
  final errors = <Object>[];
  var interpretation = 0;
  final seals = <Seal>[];

  @override
  void toast(String message) => toasts.add(message);
  @override
  void error(Object error) => errors.add(error);
  @override
  void openInterpretation() => interpretation++;
  @override
  void openSealInfo(Seal seal) => seals.add(seal);
}

/// Servidor que no contesta hasta que el test lo suelta: la red lenta del móvil.
class _SlowServer extends FakeServer {
  bool slow = false;
  final List<Completer<void>> waiting = [];

  @override
  Future<Map<String, dynamic>> tarotTableOp(
    String sessionId,
    String op,
    Map<String, dynamic> body,
  ) async {
    if (slow) {
      final gate = Completer<void>();
      waiting.add(gate);
      await gate.future;
    }
    return super.tarotTableOp(sessionId, op, body);
  }

  /// Contesta la peticion mas antigua que este esperando.
  void answerOne() => waiting.removeAt(0).complete();

  /// Mazo de 78, como Rider–Waite–Smith: el abanico real.
  @override
  Future<Map<String, dynamic>> tarotOpenTable(
    String deck, {
    String? fromReading,
  }) async {
    final out = await super.tarotOpenTable(deck, fromReading: fromReading);
    piles = {
      'p0': [for (var i = 0; i < 78; i++) 'c$i'],
    };
    return {...out, ...await tarotCurrentTable() ?? const {}};
  }
}

/// Pantalla util del GN2200 (1080 x 2400 a 3x) sin barras del sistema.
const gn2200 = Size(360, 760);

SpreadDef _spread(String slug, double scale, List<(double, double, int)> s) =>
    SpreadDef(
      slug: slug,
      name: slug,
      description: '',
      cardScale: scale,
      labelByName: true,
      slots: [
        for (var i = 0; i < s.length; i++)
          SpreadSlotDef(
            x: s[i].$1,
            y: s[i].$2,
            rotation: s[i].$3,
            name: 'Hueco ${i + 1}',
            meaning: 'm.',
          ),
      ],
    );

// Coordenadas reales de `arcanum-api/app/domain/spreads.py`.
final three = _spread('three_card', .9, [
  (.2, .46, 0),
  (.5, .46, 0),
  (.8, .46, 0),
]);
final celtic = _spread('celtic_cross', .56, [
  (.34, .5, 0),
  (.34, .5, 90),
  (.34, .8, 0),
  (.13, .5, 0),
  (.34, .2, 0),
  (.55, .5, 0),
  (.86, .87, 0),
  (.86, .62, 0),
  (.86, .38, 0),
  (.86, .13, 0),
]);

/// Rectangulo de mesa que ocupa una pose de carta (girada incluida).
Rect rectOf(TablePose p) {
  final hw = TableGeometry.cardW * p.scale / 2,
      hh = TableGeometry.cardH * p.scale / 2;
  final a = p.rot * math.pi / 180;
  final w = (hw * math.cos(a)).abs() + (hh * math.sin(a)).abs();
  final h = (hw * math.sin(a)).abs() + (hh * math.cos(a)).abs();
  return Rect.fromCenter(center: p.offset, width: w * 2, height: h * 2);
}

double overlap(Rect a, Rect b) {
  final i = a.intersect(b);
  return i.width <= 0 || i.height <= 0 ? 0 : i.width * i.height;
}

/// Todos los estados que la camara permite, esquinas incluidas.
Iterable<TableCameraState> allowedCameras() sync* {
  for (final th in [
    TableCamera.minTheta,
    TableCamera.baseTheta,
    TableCamera.maxTheta,
  ]) {
    for (final yaw in [-TableCamera.maxYaw, 0.0, TableCamera.maxYaw]) {
      for (final z in [TableCamera.minZoom, 1.8, TableCamera.maxZoom]) {
        for (final pan in [
          Offset.zero,
          const Offset(-5000, -5000),
          const Offset(5000, 5000),
          const Offset(-5000, 5000),
        ]) {
          yield TableCameraState(
            theta: th,
            yaw: yaw,
            zoom: z,
            panX: pan.dx,
            panY: pan.dy,
          );
        }
      }
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _SlowServer server;
  late ProviderContainer c;
  late _Effects fx;
  late TableDirector dir;
  var clock = Duration.zero;
  var pointer = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    server = _SlowServer();
    c = ProviderContainer(
      overrides: [
        arcanumApiProvider.overrideWithValue(server),
        authProvider.overrideWith(_Auth.new),
      ],
    );
    await c.read(tableControllerProvider.future);
    fx = _Effects();
    dir = TableDirector(
      ops: c.read(tableControllerProvider.notifier),
      effects: fx,
      decks: const [
        DeckInfo(
          slug: 'rws',
          name: 'Rider–Waite–Smith',
          description: '',
          allowReversed: true,
          art: 'rws',
          cardCount: 78,
        ),
        DeckInfo(
          slug: 'mayores',
          name: 'Arcanos Mayores',
          description: '',
          allowReversed: true,
          art: 'rws',
          cardCount: 22,
        ),
      ],
      spreads: [three, celtic],
      random: math.Random(7),
    )..setViewport(gn2200);
    clock = Duration.zero;
  });
  tearDown(() => c.dispose());

  TableState table() => dir.table;
  TableController ops() => c.read(tableControllerProvider.notifier);
  Offset screenOf(Offset tablePoint) => dir.camera.toScreen(tablePoint);

  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void frame([int ms = 16]) {
    clock += Duration(milliseconds: ms);
    dir.tick(clock, Duration(milliseconds: ms));
  }

  /// Toque en un punto de PANTALLA, sin esperar al servidor.
  void tapScreen(Offset at) {
    final id = ++pointer;
    dir.pointerDown(id, at, clock);
    clock += const Duration(milliseconds: 60);
    dir.pointerUp(id, at, clock);
    frame();
  }

  Future<void> tap(Offset tableAt) async {
    tapScreen(screenOf(tableAt));
    clock += const Duration(milliseconds: 400);
    frame();
    await settle();
  }

  Future<void> openWithFan({String? spread}) async {
    await tap(shelfPose(0, 2).offset);
    if (spread != null) ops().arrange((s) => s.copyWith(spread: () => spread));
    final p = table().piles.single;
    await tap(Offset(p.x, p.y));
    expect(table().fan, isNotNull);
  }

  List<PieceView> fanCards() =>
      dir.pieces().where((p) => p.kind == PieceKind.fanCard).toList();

  /// Centro en pantalla de la parte VISIBLE de la carta i del abanico: la de
  /// encima la tapa salvo su borde, como en el móvil.
  Offset fanTapPoint(int i) {
    final fan = fanCards();
    final a = fan[i].pose, b = fan[math.min(i + 1, fan.length - 1)].pose;
    final mid = i + 1 < fan.length
        ? Offset((a.x + b.x) / 2 - (b.x - a.x) * 0, a.y)
        : a.offset;
    return screenOf(Offset.lerp(a.offset, mid, .5)!.translate(0, 10));
  }

  group('sacar del abanico con la red lenta', () {
    test(
      'el toque se ve al instante y un segundo toque no se pierde',
      () async {
        await openWithFan(spread: 'three_card');
        server.slow = true;
        final before = fanCards().length;

        tapScreen(fanTapPoint(10));
        // al instante, sin respuesta del servidor: la carta ya va de camino
        expect(dir.pendingTakes, hasLength(1));
        expect(
          dir.pieces().where((p) => p.kind == PieceKind.pendingCard),
          hasLength(1),
        );
        expect(fanCards(), hasLength(before - 1));

        // segundo toque con el primero aun en el aire
        tapScreen(fanTapPoint(30));
        expect(
          dir.pendingTakes,
          hasLength(2),
          reason: 'antes se descartaba en silencio por _busy',
        );

        await settle();
        server.answerOne();
        await settle();
        server.answerOne();
        await settle();
        expect(dir.pendingTakes, isEmpty);
        expect(table().cardInSlot(0), isNotNull);
        expect(table().cardInSlot(1), isNotNull);
        expect(table().cardInSlot(2), isNull);
        expect(fx.errors, isEmpty);
        expect(dir.takeTimings, hasLength(2));
      },
    );

    test('tres toques seguidos completan la tirada de tres', () async {
      await openWithFan(spread: 'three_card');
      server.slow = true;
      for (final i in [5, 20, 40]) {
        tapScreen(fanTapPoint(i));
      }
      expect(dir.pendingTakes, hasLength(3));
      for (var i = 0; i < 3; i++) {
        await settle();
        server.answerOne();
      }
      await settle();
      for (var i = 0; i < 3; i++) {
        final card = table().cardInSlot(i)!;
        expect(Offset(card.x, card.y), slotPose(three, i).offset);
        expect(card.scale, three.cardScale);
      }
    });

    test('Cruz Celta: diez toques, diez huecos, sin bloqueo', () async {
      await openWithFan(spread: 'celtic_cross');
      server.slow = true;
      for (var i = 0; i < 10; i++) {
        tapScreen(fanTapPoint(3 + i * 6));
        expect(dir.pendingTakes, hasLength(i + 1));
      }
      // el controlador las pide en fila: una respuesta deja pasar la siguiente
      for (var n = 0; n < 40 && dir.pendingTakes.isNotEmpty; n++) {
        await settle();
        if (server.waiting.isNotEmpty) server.answerOne();
      }
      for (var i = 0; i < 10; i++) {
        expect(table().cardInSlot(i), isNotNull, reason: 'hueco $i');
      }
      expect(dir.pendingTakes, isEmpty);
    });

    test(
      'si el servidor falla, la carta vuelve al abanico y se avisa',
      () async {
        await openWithFan(spread: 'three_card');
        final before = fanCards().length;
        server.failNext = StateError('red caida');
        tapScreen(fanTapPoint(10));
        await settle();
        expect(dir.pendingTakes, isEmpty);
        expect(fanCards(), hasLength(before));
        expect(fx.errors, hasLength(1));
        expect(table().cards, isEmpty);
      },
    );

    test('arrastre corto soltado antes de la respuesta: la carta no queda '
        'levantada, enorme ni encima del abanico', () async {
      await openWithFan(spread: 'three_card');
      server.slow = true;
      final at = fanTapPoint(12);
      final id = ++pointer;
      dir.pointerDown(id, at, clock);
      // el temblor de un dedo: algo mas que el umbral de toque
      dir.pointerMove(
        id,
        at.translate(0, -12),
        clock += const Duration(milliseconds: 30),
      );
      dir.pointerUp(
        id,
        at.translate(0, -12),
        clock += const Duration(milliseconds: 30),
      );
      frame();
      await settle();
      server.answerOne();
      await settle();
      frame();
      final card = dir.pieces().singleWhere((p) => p.kind == PieceKind.card);
      expect(card.lift, 0, reason: 'antes se quedaba a 64 para siempre');
      expect(card.dragging, isFalse);
      expect(card.pose.scale, lessThan(1), reason: 'antes salia a escala 1');
      expect(
        card.card!.slot,
        0,
        reason: 'soltada sobre el abanico: va al hueco',
      );
      // y se puede sacar otra sin moverla
      server.slow = false;
      await tap(fanCards()[30].pose.offset.translate(0, 20));
      expect(table().cardInSlot(1), isNotNull);
    });
  });

  group('cartas sueltas y superposiciones', () {
    test(
      'sin tirada, las cartas sacadas no se apilan ni tapan el abanico',
      () async {
        await openWithFan();
        for (final i in [5, 25, 45, 60]) {
          tapScreen(fanTapPoint(i));
          await settle();
        }
        final cards = table().cards;
        expect(cards, hasLength(4));
        final rects = [
          for (final k in cards)
            rectOf(TablePose(k.x, k.y, rot: k.rot, scale: k.scale)),
        ];
        for (var i = 0; i < rects.length; i++) {
          for (var j = i + 1; j < rects.length; j++) {
            expect(overlap(rects[i], rects[j]), 0, reason: 'cartas $i y $j');
          }
        }
        final fanBox = fanCards()
            .map((p) => rectOf(p.pose))
            .reduce((a, b) => a.expandToInclude(b));
        for (final r in rects) {
          expect(overlap(r, fanBox), 0);
        }
      },
    );

    for (final sp in [three, celtic]) {
      test('${sp.slug}: con la tirada llena, la carta de mas no tapa huecos, '
          'sello ni «Interpretar»', () async {
        await openWithFan(spread: sp.slug);
        ops().arrange((s) => s.copyWith(seal: () => const Seal(text: '¿?')));
        for (var i = 0; i < sp.cardCount; i++) {
          tapScreen(fanTapPoint(2 + i * 5));
          await settle();
        }
        // la tirada llena recoge el abanico: la de mas se saca reabriendolo
        expect(table().fan, isNull);
        final p = table().piles.single;
        await tap(Offset(p.x, p.y));
        tapScreen(fanTapPoint(2));
        await settle();
        final extra = table().cards.singleWhere((k) => k.slot == null);
        final r = rectOf(
          TablePose(extra.x, extra.y, rot: extra.rot, scale: extra.scale),
        );
        for (var i = 0; i < sp.cardCount; i++) {
          expect(overlap(r, rectOf(slotPose(sp, i))), 0, reason: 'hueco $i');
        }
        expect(overlap(r, TableDirector.sealRect), 0);
        expect(overlap(r, TableDirector.embroideryRect), 0);
      });
    }

    test(
      'con el abanico abierto, el sello y el bordado se pueden tocar',
      () async {
        await openWithFan(spread: 'three_card');
        ops().arrange((s) => s.copyWith(seal: () => const Seal(text: '¿?')));
        expect(dir.hitAt(TableDirector.sealAt), isA<HitSeal>());
        for (final i in [3, 20, 40]) {
          tapScreen(fanTapPoint(i));
          await settle();
        }
        ops().arrange((s) {
          var t = s;
          for (final k in s.cards) {
            t = t.updateCard(k.slug, (x) => x.copyWith(faceUp: true));
          }
          return t;
        });
        // tirada completa: el abanico se recogio solo y no tapa el bordado
        expect(table().fan, isNull);
        expect(dir.hitAt(TableDirector.embroideryAt), isA<HitEmbroidery>());
        // y si se reabre para una aclaratoria, el bordado sigue mandando
        final p = table().piles.single;
        await tap(Offset(p.x, p.y));
        expect(table().fan, isNotNull);
        expect(dir.hitAt(TableDirector.embroideryAt), isA<HitEmbroidery>());
      },
    );

    test('un monton cortado no cae sobre el bordado ni el sello', () async {
      await tap(shelfPose(0, 2).offset);
      ops().arrange((s) => s.copyWith(seal: () => const Seal(text: '¿?')));
      for (var n = 0; n < 3; n++) {
        final p = table().piles.first;
        await dir.debugCut(p.pid);
        await settle();
      }
      for (final p in table().piles) {
        final r = rectOf(TablePose(p.x, p.y, scale: TableGeometry.deckScale));
        expect(overlap(r, TableDirector.sealRect), 0, reason: p.pid);
        expect(overlap(r, TableDirector.embroideryRect), 0, reason: p.pid);
      }
    });
  });

  group('camara', () {
    test('en todos los estados permitidos la mesa queda en pantalla', () {
      for (final s in allowedCameras()) {
        final cam = TableCamera(from: s)..fit(gn2200);
        cam.clampToView();
        final center = cam.toTable(gn2200.center(Offset.zero));
        expect(
          TableGeometry.cloth.contains(center),
          isTrue,
          reason: 'centro de la pantalla fuera del paño con $s',
        );
      }
    });

    test('el zoom amplia sin deformar: ninguna carta queda detras de la camara '
        'ni crece mas que el zoom', () {
      const lifted = 64.0;
      double size(TableCamera cam, Offset at, double z) =>
          (cam.toScreen(at.translate(0, TableGeometry.cardH * .35), z: z) -
                  cam.toScreen(
                    at.translate(0, -TableGeometry.cardH * .35),
                    z: z,
                  ))
              .distance;
      var worst = 0.0;
      for (final s in allowedCameras()) {
        final cam = TableCamera(from: s)..fit(gn2200);
        cam.clampToView();
        final rest = TableCamera(
          from: TableCameraState(theta: s.theta, yaw: s.yaw),
        )..fit(gn2200);
        for (final at in [
          TableGeometry.homeSpot,
          const Offset(300, 450),
          const Offset(40, 880),
          const Offset(560, 880),
        ]) {
          for (final z in [0.0, lifted]) {
            final m = cam.matrix().storage;
            final w = m[3] * at.dx + m[7] * at.dy + m[11] * z + m[15];
            expect(w, greaterThan(0), reason: 'detras de la camara: $s');
            final h = size(cam, at, z);
            // antes, con 56 grados y zoom 2,6, crecia 8,6 veces (88 % del alto)
            expect(
              h,
              lessThanOrEqualTo(size(rest, at, z) * s.zoom + 1e-6),
              reason: 'crece mas que el zoom: $s en $at',
            );
            worst = math.max(worst, h);
          }
        }
      }
      // guarda contra lo visto en el GN2200, no un tamaño de diseño
      expect(worst, lessThan(gn2200.height / 2));
    });

    test('toque y dibujo coinciden con giro, inclinacion, zoom y altura', () {
      for (final s in allowedCameras()) {
        final cam = TableCamera(from: s)..fit(gn2200);
        cam.clampToView();
        for (final p in const [
          Offset(100, 300),
          Offset(470, 782),
          Offset(300, 600),
        ]) {
          for (final z in [0.0, 40.0, 64.0]) {
            final back = cam.toTable(cam.toScreen(p, z: z), z: z);
            expect((back - p).distance, lessThan(.01), reason: '$s z=$z');
          }
        }
      }
    });

    test('pellizcar acerca hacia donde estan los dedos', () {
      final cam = TableCamera()..fit(gn2200);
      const a = Offset(60, 520), b = Offset(160, 520);
      final under = cam.toTable((a + b) / 2);
      cam.startPinch(a, b);
      cam.updatePinch(a.translate(-60, 0), b.translate(60, 0));
      expect(cam.zoom, greaterThan(1.5));
      final now = cam.toTable((a + b) / 2);
      expect((now - under).distance, lessThan(1));
    });

    test(
      'la camara se guarda con la mesa y se restaura dentro de los limites',
      () async {
        await tap(shelfPose(0, 2).offset);
        final id = ++pointer;
        final from = screenOf(const Offset(300, 450));
        dir.pointerDown(id, from, clock);
        for (var i = 1; i <= 6; i++) {
          dir.pointerMove(
            id,
            from.translate(i * 20.0, i * 15.0),
            clock += const Duration(milliseconds: 16),
          );
        }
        dir.pointerUp(id, from.translate(120, 90), clock);
        frame();
        expect(table().camera.yaw, dir.camera.tYaw);
        expect(table().camera.theta, dir.camera.tTheta);

        final wild = TableCamera(
          from: const TableCameraState(
            theta: 200,
            yaw: -300,
            zoom: 40,
            panX: 9e9,
          ),
        )..fit(gn2200);
        expect(wild.theta, TableCamera.maxTheta);
        expect(wild.yaw, -TableCamera.maxYaw);
        expect(wild.zoom, TableCamera.maxZoom);
        wild.clampToView();
        expect(
          TableGeometry.cloth.contains(
            wild.toTable(gn2200.center(Offset.zero)),
          ),
          isTrue,
        );
      },
    );

    test('doble toque fuera de la mesa tambien la recentra', () async {
      await tap(shelfPose(0, 2).offset);
      dir.camera
        ..tYaw = 40
        ..tTheta = 56;
      for (var i = 0; i < 60; i++) {
        frame();
      }
      final outside = Offset(4, gn2200.height - 4);
      expect(dir.hitAtScreen(outside), isA<HitNothing>());
      tapScreen(outside);
      clock += const Duration(milliseconds: 100);
      tapScreen(outside);
      expect(dir.camera.tYaw, 0);
      expect(dir.camera.tTheta, TableCamera.baseTheta);
    });
  });

  group('toque sobre lo dibujado', () {
    test(
      'una carta levantada se toca donde se ve, con la mesa girada',
      () async {
        await openWithFan(spread: 'three_card');
        dir.camera.jumpTo(
          const TableCameraState(theta: 50, yaw: 30, zoom: 1.6),
        );
        dir.camera.clampToView();
        tapScreen(fanTapPoint(10));
        await settle();
        final card = table().cardInSlot(0)!;
        // mientras se arrastra va levantada 64: se dibuja mas cerca de la camara
        final drawn = dir.camera.toScreen(Offset(card.x, card.y), z: 64);
        dir.debugLift('card:${card.slug}', 64);
        final hit = dir.hitAtScreen(drawn);
        expect(hit, isA<HitCard>());
        expect((hit as HitCard).slug, card.slug);
      },
    );
  });
}
