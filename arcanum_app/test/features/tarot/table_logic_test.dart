import 'dart:math' as math;
import 'dart:ui';

import 'package:arcanum_app/features/tarot/domain/table_models.dart';
import 'package:arcanum_app/features/tarot/domain/table_state.dart';
import 'package:arcanum_app/features/tarot/table/card_physics.dart';
import 'package:arcanum_app/features/tarot/table/gesture_grammar.dart';
import 'package:arcanum_app/features/tarot/table/radial_logic.dart';
import 'package:arcanum_app/features/tarot/table/table_camera.dart';
import 'package:arcanum_app/features/tarot/table/table_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

const phone = Size(390, 844);

SpreadDef spread(List<(double, double)> xy, {double scale = .9}) => SpreadDef(
  slug: 'x',
  name: 'x',
  description: '',
  cardScale: scale,
  labelByName: false,
  slots: [
    for (final (x, y) in xy)
      SpreadSlotDef(x: x, y: y, rotation: 0, name: 'n', meaning: 'm.'),
  ],
);

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  group('camara', () {
    TableCamera cam({double theta = 30, double yaw = 0, double zoom = 1}) =>
        TableCamera(
          from: TableCameraState(theta: theta, yaw: yaw, zoom: zoom),
        )..fit(phone);

    test('la mesa entra entera a lo alto y el paño a lo ancho en un movil', () {
      final c = cam();
      for (final p in const [
        Offset(22, 0),
        Offset(578, 0),
        Offset(22, 900),
        Offset(578, 900),
      ]) {
        final s = c.toScreen(p);
        expect(s.dx, inInclusiveRange(0, phone.width), reason: '$p -> $s');
        expect(s.dy, inInclusiveRange(0, phone.height), reason: '$p -> $s');
      }
    });

    test(
      'lo cercano se ve mas grande: el borde de abajo es mas ancho que el de arriba',
      () {
        final c = cam();
        final top =
            c.toScreen(const Offset(600, 0)).dx - c.toScreen(Offset.zero).dx;
        final bottom =
            c.toScreen(const Offset(600, 900)).dx -
            c.toScreen(const Offset(0, 900)).dx;
        expect(bottom, greaterThan(top));
      },
    );

    test(
      'sin giro la mesa sale simetrica respecto al centro de la pantalla',
      () {
        final c = cam();
        for (final y in const [0.0, 450.0, 900.0]) {
          final l = c.toScreen(Offset(0, y)), r = c.toScreen(Offset(600, y));
          expect(
            (l.dx + r.dx) / 2,
            closeTo(phone.width / 2, 1e-6),
            reason: 'y=$y',
          );
        }
      },
    );

    test('un toque vuelve al mismo punto de la mesa con cualquier camara', () {
      final rnd = math.Random(4);
      for (final c in [
        cam(),
        cam(theta: 16, yaw: -40),
        cam(theta: 56, yaw: 40, zoom: 2.6),
        cam(theta: 44, yaw: 12, zoom: 1.4)..panX = 30,
      ]) {
        for (var i = 0; i < 50; i++) {
          final p = Offset(rnd.nextDouble() * 600, rnd.nextDouble() * 900);
          final back = c.toTable(c.toScreen(p));
          expect((back - p).distance, lessThan(1e-6), reason: '$p -> $back');
        }
      }
    });

    test('arrastrar va invertido y tiene tope', () {
      final c = cam();
      c.orbitBy(const Offset(40, 0));
      expect(c.tYaw, lessThan(0));
      c.orbitBy(const Offset(0, 40));
      expect(c.tTheta, greaterThan(30));
      c.orbitBy(const Offset(-5000, 5000));
      expect(c.tYaw, TableCamera.maxYaw);
      expect(c.tTheta, TableCamera.maxTheta);
    });

    test('al soltar la mesa sigue un poco en la direccion del gesto', () {
      final c = cam();
      final v = c.orbitBy(const Offset(10, 0));
      final before = c.tYaw;
      c.releaseOrbit(vyaw: v.vyaw, vtheta: v.vtheta);
      expect(c.tYaw, lessThan(before));
    });

    test('se acerca al destino igual a 60 que a 120 Hz', () {
      final a = cam(), b = cam();
      a.tYaw = b.tYaw = 30;
      for (var i = 0; i < 30; i++) {
        a.step(const Duration(microseconds: 16667));
      }
      for (var i = 0; i < 60; i++) {
        b.step(const Duration(microseconds: 8333));
      }
      expect(a.yaw, closeTo(b.yaw, .05));
      expect(a.yaw, greaterThan(29));
    });

    test('quieta no pide repintar', () {
      expect(cam().step(ms(16)), isFalse);
    });

    test('pellizcar acerca con tope, y doble toque recentra', () {
      final c = cam();
      c.startPinch(const Offset(150, 400), const Offset(250, 400));
      c.updatePinch(const Offset(100, 400), const Offset(300, 400));
      expect(c.zoom, closeTo(2, 1e-9));
      c.updatePinch(const Offset(0, 400), const Offset(390, 400));
      expect(c.zoom, TableCamera.maxZoom);
      c.updatePinch(const Offset(199, 400), const Offset(201, 400));
      expect(c.zoom, TableCamera.minZoom);
      c.reset();
      expect(c.state.toJson(), const TableCameraState().toJson());
    });
  });

  group('geometria', () {
    final three = spread([(.2, .46), (.5, .46), (.8, .46)]);

    test('los huecos caen en la zona de la tirada, como en el prototipo', () {
      final p = slotPose(three, 0);
      expect(p.x, closeTo(36 + .2 * 528, 1e-9));
      expect(p.y, closeTo(200 + .46 * 470, 1e-9));
      expect(p.scale, .9);
    });

    test('el iman atrapa cerca del hueco y suelta lejos', () {
      final s = slotPose(three, 1).offset;
      expect(nearestSlot(three, s.translate(30, -20)), 1);
      expect(nearestSlot(three, s.translate(0, 200)), isNull);
    });

    test('con cartas muy pequeñas el iman no baja de 46', () {
      final tiny = spread([(.5, .5)], scale: .1);
      final s = slotPose(tiny, 0).offset;
      expect(nearestSlot(tiny, s.translate(44, 0)), 0);
      expect(nearestSlot(tiny, s.translate(48, 0)), isNull);
    });

    test('las aclaratorias asoman a la derecha, cada una mas afuera', () {
      const host = TablePose(300, 400, scale: .9);
      final a = clarifierPose(host, 0), b = clarifierPose(host, 1);
      expect(a.x, greaterThan(host.x));
      expect(b.x, greaterThan(a.x));
      expect(a.rot, 9);
      expect(a.scale, closeTo(.9 * .82, 1e-9));
    });

    test('coordenadas locales: esquina y centro, tambien girada', () {
      const card = TablePose(300, 400, rot: 90);
      expect(localNormalized(card, const Offset(300, 400)), Offset.zero);
      // girada 90 grados en sentido horario, su borde de arriba mira a la derecha
      final top = localNormalized(
        card,
        Offset(300 + TableGeometry.cardH / 2, 400),
      );
      expect(top.dy, closeTo(-1, 1e-9));
      expect(top.dx, closeTo(0, 1e-9));
    });
  });

  group('gestos', () {
    const faceDownCorner = HitCard(
      slug: 'a',
      local: Offset(.8, .8),
      faceUp: false,
    );
    const faceUpCorner = HitCard(
      slug: 'a',
      local: Offset(.8, .8),
      faceUp: true,
    );
    const cardCenter = HitCard(slug: 'a', local: Offset.zero, faceUp: false);

    test('tocar y soltar enseguida es un toque', () {
      final g = GestureGrammar();
      g.down(1, Offset.zero, ms(0), cardCenter);
      g.move(1, const Offset(5, 0), ms(50));
      expect(g.up(1, const Offset(5, 0), ms(120)).single, isA<TapIntent>());
    });

    test('mantener 430 ms abre el radial; deslizar y soltar elige', () {
      final g = GestureGrammar();
      g.down(1, Offset.zero, ms(0), cardCenter);
      expect(g.tick(ms(429)), isEmpty);
      expect(g.deadline, ms(430));
      expect(g.tick(ms(430)).single, isA<OpenRadialIntent>());
      expect(
        g.move(1, const Offset(0, -90), ms(500)).single,
        isA<RadialMoveIntent>(),
      );
      expect(
        g.up(1, const Offset(0, -90), ms(600)).single,
        isA<RadialReleaseIntent>(),
      );
      expect(g.active, isFalse);
    });

    test(
      'soltar justo al vencer, sin tick de por medio, cuenta como mantener',
      () {
        final g = GestureGrammar();
        g.down(1, Offset.zero, ms(0), cardCenter);
        final out = g.up(1, Offset.zero, ms(440));
        expect(out.map((i) => i.runtimeType), [
          OpenRadialIntent,
          RadialReleaseIntent,
        ]);
      },
    );

    test('moverse antes de tiempo arrastra y ya no abre el radial', () {
      final g = GestureGrammar();
      g.down(1, Offset.zero, ms(0), cardCenter);
      final out = g.move(1, const Offset(20, 0), ms(100));
      expect((out.first as DragStartIntent).kind, DragKind.move);
      expect(g.tick(ms(1000)), isEmpty);
      final end =
          g.up(1, const Offset(30, 0), ms(1100)).single as DragEndIntent;
      expect(end.cancelled, isFalse);
    });

    test('la esquina voltea solo si la carta esta boca abajo', () {
      DragKind kindFor(Hit h) {
        final g = GestureGrammar()..down(1, Offset.zero, ms(0), h);
        return (g.move(1, const Offset(20, 0), ms(50)).first as DragStartIntent)
            .kind;
      }

      expect(kindFor(faceDownCorner), DragKind.peel);
      expect(kindFor(faceUpCorner), DragKind.move);
      expect(
        kindFor(
          const HitCard(
            slug: 'a',
            local: Offset(.8, .8),
            faceUp: false,
            inFan: true,
          ),
        ),
        DragKind.move,
      );
    });

    test('el mazo: arriba corta, el lado extiende, el centro mueve', () {
      DragKind kindFor(Offset local, int count) {
        final g = GestureGrammar()
          ..down(
            1,
            Offset.zero,
            ms(0),
            HitDeck(pid: 'p0', local: local, count: count),
          );
        return (g.move(1, const Offset(0, -20), ms(50)).first
                as DragStartIntent)
            .kind;
      }

      expect(kindFor(const Offset(0, -.8), 78), DragKind.cut);
      expect(
        kindFor(const Offset(0, -.8), 3),
        DragKind.move,
      ); // con menos de 4 no se corta
      expect(kindFor(const Offset(.9, 0), 78), DragKind.fan);
      expect(kindFor(const Offset(.9, 0), 0), DragKind.move);
      expect(kindFor(Offset.zero, 78), DragKind.move);
    });

    test('el paño orbita, y el doble toque recentra', () {
      final g = GestureGrammar();
      g.down(1, Offset.zero, ms(0), const HitSurface());
      expect(
        (g.move(1, const Offset(30, 0), ms(40)).first as DragStartIntent).kind,
        DragKind.orbit,
      );
      g.up(1, const Offset(30, 0), ms(80));

      g.down(1, const Offset(100, 100), ms(1000), const HitSurface());
      expect(
        g.up(1, const Offset(100, 100), ms(1050)).single,
        isA<TapIntent>(),
      );
      g.down(1, const Offset(110, 105), ms(1200), const HitSurface());
      expect(
        g.up(1, const Offset(110, 105), ms(1250)).single,
        isA<ResetCameraIntent>(),
      );

      // demasiado lento: dos toques sueltos
      g.down(1, Offset.zero, ms(3000), const HitSurface());
      g.up(1, Offset.zero, ms(3050));
      g.down(1, Offset.zero, ms(3500), const HitSurface());
      expect(g.up(1, Offset.zero, ms(3550)).single, isA<TapIntent>());
    });

    test('el bordado: tocar abre, mantener 1,3 s cierra el circulo', () {
      final g = GestureGrammar();
      g.down(1, Offset.zero, ms(0), const HitEmbroidery());
      expect(g.tick(ms(500)), isEmpty); // no abre el radial a los 430
      expect(g.tick(ms(1300)).single, isA<CloseCircleIntent>());
      expect(g.up(1, Offset.zero, ms(1400)), isEmpty);

      g.down(1, Offset.zero, ms(2000), const HitEmbroidery());
      expect(g.up(1, Offset.zero, ms(2100)).single, isA<TapIntent>());
    });

    test('el segundo dedo convierte el arrastre en pellizco', () {
      final g = GestureGrammar();
      g.down(1, Offset.zero, ms(0), cardCenter);
      g.move(1, const Offset(20, 0), ms(50));
      final out = g.down(2, const Offset(200, 0), ms(60), const HitSurface());
      expect((out.first as DragEndIntent).cancelled, isTrue);
      expect(out.last, isA<PinchStartIntent>());
      expect(
        g.move(2, const Offset(250, 0), ms(80)).single,
        isA<PinchUpdateIntent>(),
      );
      expect(
        g.up(1, const Offset(20, 0), ms(100)).single,
        isA<PinchEndIntent>(),
      );
      expect(g.up(2, const Offset(250, 0), ms(110)), isEmpty);
    });

    test('el sello solo se toca: mantenerlo no abre radial ni arrastra', () {
      final g = GestureGrammar();
      g.down(1, Offset.zero, ms(0), const HitSeal());
      expect(g.deadline, isNull);
      expect(g.tick(ms(2000)), isEmpty);
      expect(g.move(1, const Offset(40, 0), ms(2100)), isEmpty);
      expect(g.up(1, const Offset(40, 0), ms(2200)), isEmpty);
      g.down(2, Offset.zero, ms(3000), const HitSeal());
      expect(g.up(2, Offset.zero, ms(3050)).single, isA<TapIntent>());
    });

    test('tocar donde no hay nada no hace nada', () {
      final g = GestureGrammar();
      g.down(1, Offset.zero, ms(0), const HitNothing());
      expect(g.tick(ms(1000)), isEmpty);
      expect(g.up(1, Offset.zero, ms(1100)), isEmpty);
    });
  });

  group('radial', () {
    final items = RadialMenus.card(
      faceUp: false,
      aside: true,
      canRevealAll: true,
    );

    test('la primera opcion va arriba y siguen en el sentido del reloj', () {
      final l = RadialLayout.at(const Offset(195, 422), phone, items);
      expect(l.positions[0].dx, closeTo(l.center.dx, 1e-9));
      expect(l.positions[0].dy, lessThan(l.center.dy));
      expect(l.positions[1].dx, greaterThan(l.center.dx));
    });

    test('se elige por angulo; el centro y lo apagado no eligen nada', () {
      final l = RadialLayout.at(const Offset(195, 422), phone, items);
      expect(l.hotAt(l.center.translate(0, -30)), isNull);
      expect(l.hotAt(l.center.translate(0, -120)), 0);
      expect(l.hotAt(l.positions[1]), 1);
      expect(
        l.hotAt(l.positions[3]),
        isNull,
      ); // 'Sacar' apagada: la carta ya esta apartada
      expect(l.tappedAt(l.positions[2]), 2);
      expect(l.tappedAt(l.positions[3]), isNull);
    });

    test('no se sale de la pantalla aunque se abra en una esquina', () {
      final l = RadialLayout.at(Offset.zero, phone, items);
      for (final p in [...l.positions, l.titlePosition]) {
        expect(p.dx, greaterThanOrEqualTo(0));
        expect(p.dy, greaterThanOrEqualTo(0));
      }
      final far = RadialLayout.at(
        Offset(phone.width, phone.height),
        phone,
        items,
      );
      for (final p in far.positions) {
        expect(p.dx, lessThanOrEqualTo(phone.width));
        expect(p.dy, lessThanOrEqualTo(phone.height));
      }
    });

    test(
      'pegado al borde, soltar sin deslizar no elige la opcion de debajo',
      () {
        // GN2200: mazo en la esquina; el circulo se mete hacia dentro y
        // «Extender» quedaba bajo el dedo, asi que soltar lo ejecutaba
        const gn2200 = Size(411, 914);
        const press = Offset(325, 640);
        final deck = RadialMenus.deck(count: 75, cardsOut: true, piles: 1);
        final l = RadialLayout.at(press, gn2200, deck);
        expect((l.center - press).distance, greaterThan(RadialLayout.deadZone));
        expect(l.hotAt(press), isNull);
        expect(l.hotAt(press.translate(-8, 6)), isNull);
        // deslizar de verdad hasta una opcion sigue eligiendola
        final spread = deck.indexWhere((i) => i.id == 'spread');
        expect(l.hotAt(l.positions[spread]), spread);
      },
    );

    test('con mas de 6 opciones el circulo es mas grande', () {
      final deck = RadialMenus.deck(count: 78, cardsOut: false, piles: 1);
      expect(RadialLayout.at(const Offset(195, 422), phone, deck).radius, 100);
      expect(RadialLayout.at(const Offset(195, 422), phone, items).radius, 86);
    });

    test('orden fijo: lo imposible se apaga pero no se mueve', () {
      final full = RadialMenus.deck(count: 78, cardsOut: true, piles: 2);
      final empty = RadialMenus.deck(count: 0, cardsOut: false, piles: 1);
      expect(empty.map((i) => i.id), full.map((i) => i.id));
      expect(empty.where((i) => i.enabled).map((i) => i.id), ['spread']);
      expect(RadialMenus.shuffle.map((i) => i.id), [
        'cascada',
        'por_encima',
        'sobre_el_pano',
      ]);
    });
  });

  group('fisica', () {
    test('tirar de la esquina hasta el borde contrario voltea del todo', () {
      final p = Peel(startLocal: const Offset(.9, .9), cardScale: 1);
      expect(p.corner, 1);
      expect(p.hingeX, -TableGeometry.cardW / 2);
      expect(p.update(const Offset(.9 - 4, .9)), closeTo(180, 1e-9));
      expect(p.commits, isTrue);
    });

    test('un tiron corto vuelve; pasado 70 grados termina', () {
      final p = Peel(startLocal: const Offset(-.9, .9), cardScale: 1);
      expect(p.update(const Offset(-.9 + .3, .9)), lessThan(70));
      expect(p.commits, isFalse);
      expect(p.update(const Offset(-.9 + 1.4, .9)), greaterThan(70));
      expect(p.commits, isTrue);
      expect(p.lift, greaterThan(0));
    });

    test('tirar hacia arriba tambien levanta la esquina', () {
      final p = Peel(startLocal: const Offset(.9, .9), cardScale: 1);
      expect(p.update(const Offset(.9, .2)), greaterThan(20));
    });

    test('el peso inclina hacia donde va y se endereza al soltar', () {
      final w = Wobble();
      for (var i = 0; i < 10; i++) {
        w.push(const Offset(8, 0));
        w.step();
      }
      expect(w.ty, greaterThan(5));
      expect(w.ty, lessThanOrEqualTo(Wobble.maxTilt * 1.2));
      w.release();
      var frames = 0;
      while (w.step()) {
        frames++;
        expect(frames, lessThan(300));
      }
      expect(w.tx, 0);
      expect(w.ty, 0);
    });
  });
}
