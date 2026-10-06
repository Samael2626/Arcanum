import 'dart:ui';

import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/tarot/application/table_controller.dart';
import 'package:arcanum_app/features/tarot/domain/table_models.dart';
import 'package:arcanum_app/features/tarot/domain/table_state.dart';
import 'package:arcanum_app/features/tarot/table/gesture_grammar.dart';
import 'package:arcanum_app/features/tarot/table/table_director.dart';
import 'package:arcanum_app/features/tarot/table/table_geometry.dart';
import 'package:dio/dio.dart';
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
  final flips = <String>[];
  final errors = <Object>[];
  var paywall = 0;
  var interpretation = 0;
  final seals = <Seal>[];

  @override
  void toast(String message) => toasts.add(message);
  @override
  void flipped(TableCard card) => flips.add(card.slug);
  @override
  void error(Object error) => errors.add(error);
  @override
  void creditsRequired() => paywall++;
  @override
  void openInterpretation() => interpretation++;
  @override
  void openSealInfo(Seal seal) => seals.add(seal);
}

const phone = Size(390, 844);

SpreadDef spread(String slug, List<(double, double)> xy) => SpreadDef(
  slug: slug,
  name: slug,
  description: '',
  cardScale: .9,
  labelByName: true,
  slots: [
    for (var i = 0; i < xy.length; i++)
      SpreadSlotDef(
        x: xy[i].$1,
        y: xy[i].$2,
        rotation: 0,
        name: 'Hueco ${i + 1}',
        meaning: 'm.',
      ),
  ],
);

final one = spread('one_card', [(.5, .5)]);
final three = spread('three_card', [(.2, .46), (.5, .46), (.8, .46)]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeServer server;
  late ProviderContainer c;
  late _Effects fx;
  late TableDirector dir;
  var clock = Duration.zero;
  var pointer = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    server = FakeServer();
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
      spreads: [one, three],
    )..setViewport(phone);
    clock = Duration.zero;
  });
  tearDown(() => c.dispose());

  TableState table() => dir.table;
  Offset screenOf(Offset tablePoint) => dir.camera.toScreen(tablePoint);

  Offset pileAt(String pid) {
    final p = table().piles.firstWhere((p) => p.pid == pid);
    return Offset(p.x, p.y);
  }

  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Toque corto en un punto de la mesa.
  Future<void> tap(Offset at) async {
    final id = ++pointer;
    dir.pointerDown(id, screenOf(at), clock);
    clock += const Duration(milliseconds: 60);
    dir.pointerUp(id, screenOf(at), clock);
    clock += const Duration(milliseconds: 400);
    dir.tick(clock, const Duration(milliseconds: 16));
    await settle();
  }

  /// Arrastre de un punto a otro de la mesa, en pasos.
  Future<void> drag(Offset from, Offset to, {int steps = 8}) async {
    final id = ++pointer;
    dir.pointerDown(id, screenOf(from), clock);
    for (var i = 1; i <= steps; i++) {
      clock += const Duration(milliseconds: 16);
      dir.pointerMove(id, screenOf(Offset.lerp(from, to, i / steps)!), clock);
      await settle();
    }
    dir.pointerUp(id, screenOf(to), clock);
    clock += const Duration(milliseconds: 100);
    await settle();
  }

  /// Mantener hasta abrir el radial y soltar sobre la opcion `id`.
  Future<void> holdAndPick(Offset at, String id) async {
    final p = ++pointer;
    dir.pointerDown(p, screenOf(at), clock);
    clock += const Duration(milliseconds: 450);
    dir.tick(clock, const Duration(milliseconds: 16));
    final layout = dir.radial!;
    final target = layout.positions[layout.items.indexWhere((i) => i.id == id)];
    dir.pointerMove(p, target, clock);
    expect(
      dir.radialHot,
      layout.items.indexWhere((i) => i.id == id),
      reason: 'opcion $id',
    );
    dir.pointerUp(p, target, clock);
    clock += const Duration(milliseconds: 100);
    await settle();
  }

  Future<void> openRws() async {
    await tap(shelfPose(0, 2).offset);
    expect(table().hasTable, isTrue);
  }

  test('objetivos de mazo y sello cubren 48 dp en 360 por 760', () async {
    dir.setViewport(const Size(360, 760));
    final shelf = screenOf(shelfPose(0, 2).offset);
    for (final delta in const [
      Offset(-23, 0),
      Offset(23, 0),
      Offset(0, -23),
      Offset(0, 23),
    ]) {
      expect(dir.hitAtScreen(shelf + delta), isA<HitDeck>());
    }
    await openRws();
    final pile = screenOf(pileAt('p0'));
    for (final delta in const [
      Offset(-23, 0),
      Offset(23, 0),
      Offset(0, -23),
      Offset(0, 23),
    ]) {
      expect(dir.hitAtScreen(pile + delta), isA<HitDeck>());
    }
    c
        .read(tableControllerProvider.notifier)
        .arrange((s) => s.copyWith(seal: () => const Seal(text: 'pregunta')));
    final seal = screenOf(TableDirector.sealAt);
    for (final delta in const [
      Offset(-23, 0),
      Offset(23, 0),
      Offset(0, -23),
      Offset(0, 23),
    ]) {
      expect(dir.hitAtScreen(seal + delta), isA<HitSeal>());
    }
  });

  group('mazos', () {
    test('tocar un mazo del estante lo pone en juego en su sitio', () async {
      await openRws();
      expect(pileAt('p0'), TableGeometry.homeSpot);
      expect(
        dir.pieces().where((p) => p.kind == PieceKind.shelfDeck).single.id,
        'shelf:mayores',
      );
      expect(fx.toasts.last, contains('en juego'));
    });

    test(
      'arrastrar un mazo del estante al paño lo abre donde se suelta',
      () async {
        await drag(shelfPose(0, 2).offset, const Offset(200, 600));
        expect((pileAt('p0') - const Offset(200, 600)).distance, lessThan(1));
      },
    );

    test('tocar el monton extiende el abanico con todas sus cartas', () async {
      await openRws();
      await tap(pileAt('p0'));
      expect(table().fan, isNotNull);
      expect(
        dir.pieces().where((p) => p.kind == PieceKind.fanCard),
        hasLength(6),
      );
      final pile = dir.pieces().firstWhere((p) => p.id == 'pile:p0');
      expect(pile.count, 0); // sus cartas estan en el abanico
    });

    test(
      'mantener el monton y soltar sobre Cortar hace dos montones',
      () async {
        await openRws();
        await holdAndPick(pileAt('p0'), 'cut');
        expect(table().piles, hasLength(2));
        expect(table().server!.total, 6);
      },
    );

    test('arrastrar un monton sobre otro los une', () async {
      await openRws();
      await holdAndPick(pileAt('p0'), 'cut');
      await drag(pileAt('p1'), pileAt('p0'));
      expect(table().piles, hasLength(1));
      expect(table().server!.piles.values.single.count, 6);
    });

    test(
      'tirar del borde de arriba del monton corta; soltarlo encima lo deshace',
      () async {
        await openRws();
        final p = pileAt('p0');
        final top = p.translate(
          0,
          -TableGeometry.cardH * TableGeometry.deckScale / 2 * .8,
        );
        await drag(top, top.translate(0, -4 - 20), steps: 4);
        expect(
          table().piles,
          hasLength(1),
          reason: 'soltado casi encima: el corte se deshace',
        );
        await drag(top, top.translate(-200, -120));
        expect(table().piles, hasLength(2));
      },
    );

    test(
      'Barajar desde el radial llama al servidor con el estilo elegido',
      () async {
        await openRws();
        await holdAndPick(pileAt('p0'), 'shuffle');
        expect(dir.radialTitle, 'Barajar');
        final layout = dir.radial!;
        final id = ++pointer;
        dir.pointerDown(
          id,
          layout.positions[1],
          clock,
        ); // tocar la opcion con el radial abierto
        await settle();
        expect(server.shuffles, ['p0:por_encima']);
      },
    );
  });

  group('cartas', () {
    test('Sacar con tirada llena los huecos en orden', () async {
      await openRws();
      await holdAndPick(pileAt('p0'), 'spread');
      final layout = dir.radial!;
      dir.pointerDown(++pointer, layout.positions[1], clock); // tres cartas
      await settle();
      expect(table().spread, 'three_card');
      await holdAndPick(pileAt('p0'), 'deal');
      expect(
        [for (var i = 0; i < 3; i++) table().cardInSlot(i)?.slug],
        ['c0', 'c1', 'c2'],
      );
      final c = table().cardInSlot(1)!;
      expect(Offset(c.x, c.y), slotPose(three, 1).offset);
    });

    test(
      'tocar una carta del abanico la pone en el primer hueco libre',
      () async {
        await openRws();
        dir.spreads = [one];
        c
            .read(tableControllerProvider.notifier)
            .arrange((s) => s.copyWith(spread: () => 'one_card'));
        await tap(pileAt('p0'));
        final fanCard = dir.pieces().firstWhere(
          (p) => p.kind == PieceKind.fanCard,
        );
        await tap(fanCard.pose.offset);
        expect(table().cardInSlot(0), isNotNull);
      },
    );

    test(
      'sin tirada, la primera carta sacada avisa una vez de donde se elige',
      () async {
        // GN2200: las cartas quedaban «fuera de la tirada» sin pista de que
        // «Tirada» vive en el menu del mazo
        await openRws();
        await tap(pileAt('p0'));
        PieceView fanCard() =>
            dir.pieces().firstWhere((p) => p.kind == PieceKind.fanCard);
        await tap(fanCard().pose.offset);
        expect(fx.toasts.where((t) => t.contains('«Tirada»')), hasLength(1));
        await tap(fanCard().pose.offset);
        expect(fx.toasts.where((t) => t.contains('«Tirada»')), hasLength(1));
      },
    );

    group('lupa del abanico', () {
      List<PieceView> fan() =>
          dir.pieces().where((p) => p.kind == PieceKind.fanCard).toList();
      PieceView focused() => fan().singleWhere((p) => p.focused);

      Future<void> openFan() async {
        await openRws();
        await tap(pileAt('p0'));
        expect(table().fan, isNotNull);
      }

      test('pulsar el abanico levanta la carta bajo el dedo', () async {
        await openFan();
        final under = fan()[3];
        dir.pointerDown(++pointer, screenOf(under.pose.offset), clock);
        final f = focused();
        expect(f.pose.scale, greaterThan(under.pose.scale * 1.4));
        expect(f.pose.y, lessThan(under.pose.y));
        dir.pointerCancel(pointer);
        expect(fan().where((p) => p.focused), isEmpty);
      });

      test('deslizar y soltar saca la carta de la lupa', () async {
        await openFan();
        final from = fan()[0].pose.offset, to = fan()[4].pose.offset;
        final id = ++pointer;
        dir.pointerDown(id, screenOf(from), clock);
        for (var i = 1; i <= 12; i++) {
          clock += const Duration(milliseconds: 16);
          dir.pointerMove(id, screenOf(Offset.lerp(from, to, i / 12)!), clock);
          await settle();
        }
        final chosen = focused().id;
        dir.pointerUp(id, screenOf(to), clock);
        clock += const Duration(milliseconds: 100);
        await settle();
        expect(table().cards, hasLength(1));
        expect(fan().map((p) => p.id), isNot(contains(chosen)));
        expect(fan().where((p) => p.focused), isEmpty);
      });

      test(
        'el dedo quieto no abre el menu: la lupa sigue y soltar saca',
        () async {
          // GN2200, 06-oct: a los 430 ms salia el menu y la lupa se apagaba
          await openFan();
          final id = ++pointer;
          dir.pointerDown(id, screenOf(fan()[3].pose.offset), clock);
          final chosen = focused().id;
          clock += const Duration(milliseconds: 900);
          dir.tick(clock, const Duration(milliseconds: 16));
          expect(dir.radial, isNull);
          expect(focused().id, chosen);
          dir.pointerUp(id, screenOf(fan()[3].pose.offset), clock);
          await settle();
          expect(table().cards, hasLength(1));
        },
      );

      test('el abanico no llega a los bordes del gesto atras', () async {
        // GN2200, 06-oct: la primera carta quedaba a menos de 24 dp del borde
        // y deslizar desde ella sacaba de la mesa
        await openFan();
        const margin = TableDirector.screenEdgeMargin;
        for (final p in fan()) {
          final r = poseRect(p.pose);
          for (final corner in [
            r.topLeft,
            r.topRight,
            r.bottomLeft,
            r.bottomRight,
          ]) {
            final s = dir.camera.toScreen(corner);
            expect(s.dx, greaterThanOrEqualTo(margin - .5), reason: p.id);
            expect(
              s.dx,
              lessThanOrEqualTo(phone.width - margin + .5),
              reason: p.id,
            );
          }
        }
        // y sigue siendo un abanico largo
        final f = table().fan!;
        expect((f.end - f.start).distance, greaterThan(250));
      });

      test('subir el dedo lleva la carta a un hueco concreto', () async {
        await openFan();
        c
            .read(tableControllerProvider.notifier)
            .arrange((s) => s.copyWith(spread: () => 'three_card'));
        final from = fan()[2].pose.offset, to = slotPose(three, 2).offset;
        await drag(from, to, steps: 16);
        await settle();
        expect(table().cardInSlot(2), isNotNull);
        expect(table().cards, hasLength(1));
      });
    });

    test('elegir tirada aparta las sueltas que pisan un hueco nuevo', () async {
      // GN2200: la carta sacada antes de elegir tirada tapaba el hueco 3
      await openRws();
      final ops = c.read(tableControllerProvider.notifier);
      final loose = await ops.take('p0', 0);
      final under = slotPose(three, 1);
      ops.arrange(
        (s) => s.updateCard(
          loose.slug,
          (k) => k.copyWith(x: under.x, y: under.y, scale: .7),
        ),
      );
      await holdAndPick(pileAt('p0'), 'spread');
      final layout = dir.radial!;
      final i = layout.items.indexWhere((it) => it.id == 'three_card');
      dir.pointerDown(++pointer, layout.positions[i], clock);
      await settle();
      expect(table().spread, 'three_card');
      final k = table().card(loose.slug)!;
      final r = poseRect(TablePose(k.x, k.y, rot: k.rot, scale: k.scale));
      for (var s = 0; s < three.cardCount; s++) {
        expect(
          r.overlaps(poseRect(slotPose(three, s))),
          isFalse,
          reason: 'hueco ${s + 1}',
        );
      }
    });

    test('al llenar el ultimo hueco el abanico se recoge solo', () async {
      // GN2200: con el abanico abierto, «Interpretar» se pintaba encima
      await openRws();
      c
          .read(tableControllerProvider.notifier)
          .arrange((s) => s.copyWith(spread: () => 'three_card'));
      await tap(pileAt('p0'));
      PieceView fanCard() =>
          dir.pieces().firstWhere((p) => p.kind == PieceKind.fanCard);
      await tap(fanCard().pose.offset);
      await tap(fanCard().pose.offset);
      expect(table().fan, isNotNull, reason: 'aun falta un hueco');
      await tap(fanCard().pose.offset);
      expect(table().cardInSlot(2), isNotNull);
      expect(table().fan, isNull);
    });

    test('desvelar todas da la vuelta solo a las de la tirada', () async {
      // GN2200: desvelaba tambien la carta suelta, que no cuenta
      await openRws();
      final ops = c.read(tableControllerProvider.notifier);
      ops.arrange((s) => s.copyWith(spread: () => 'three_card'));
      await holdAndPick(pileAt('p0'), 'deal');
      final loose = await ops.take('p0', 3);
      await settle();
      await holdAndPick(slotPose(three, 0).offset, 'reveal-all');
      for (var i = 0; i < 3; i++) {
        expect(table().cardInSlot(i)!.faceUp, isTrue, reason: 'hueco $i');
      }
      expect(table().card(loose.slug)!.faceUp, isFalse);
    });

    test(
      'con el abanico abierto, mantener el mazo da el menu del abanico',
      () async {
        // mantener sobre el abanico ya no abre nada: alli manda la lupa
        await openRws();
        await tap(pileAt('p0'));
        final id = ++pointer;
        dir.pointerDown(id, screenOf(pileAt('p0')), clock);
        clock += const Duration(milliseconds: 450);
        dir.tick(clock, const Duration(milliseconds: 16));
        expect(dir.radial!.items.map((i) => i.id), contains('gather'));
        dir.pointerCancel(id);
        dir.closeRadial();
        await holdAndPick(pileAt('p0'), 'spread');
        expect(dir.radial!.items.map((i) => i.id), contains('three_card'));
      },
    );

    test(
      'arrastrar una carta a un hueco la coloca; cerca de otra, la aclara',
      () async {
        await openRws();
        c
            .read(tableControllerProvider.notifier)
            .arrange((s) => s.copyWith(spread: () => 'three_card'));
        await holdAndPick(pileAt('p0'), 'deal');
        final free = await c
            .read(tableControllerProvider.notifier)
            .take('p0', 3);
        await drag(Offset(free.x, free.y), slotPose(three, 1).offset);
        expect(table().cardInSlot(1)!.slug, free.slug);
        // la que estaba en el hueco 1 queda donde estaba la que llego
        final displaced = table().card('c1')!;
        expect(displaced.slot, isNull);

        final host = slotPose(three, 0).offset;
        // debajo: fuera del iman de todos los huecos (94) pero junto a la carta (hasta 179)
        await drag(Offset(displaced.x, displaced.y), host.translate(0, 130));
        expect(table().card('c1')!.host, table().cardInSlot(0)!.slug);
        expect(fx.toasts.last, startsWith('Aclaratoria de 1'));
      },
    );

    test(
      'carta suelta: un toque la devuelve al monton, dos la desvelan',
      () async {
        await openRws();
        final a = await c.read(tableControllerProvider.notifier).take('p0', 0);
        final b = await c.read(tableControllerProvider.notifier).take('p0', 1);
        c
            .read(tableControllerProvider.notifier)
            .arrange(
              (s) => s.updateCard(b.slug, (k) => k.copyWith(x: 150, y: 400)),
            );
        await tap(Offset(a.x, a.y)); // uno y espera: vuelve al mazo
        expect(table().card(a.slug), isNull);

        final id = ++pointer;
        dir.pointerDown(id, screenOf(const Offset(150, 400)), clock);
        dir.pointerUp(
          id,
          screenOf(const Offset(150, 400)),
          clock += const Duration(milliseconds: 50),
        );
        dir.pointerDown(
          id,
          screenOf(const Offset(150, 400)),
          clock += const Duration(milliseconds: 100),
        );
        dir.pointerUp(
          id,
          screenOf(const Offset(150, 400)),
          clock += const Duration(milliseconds: 50),
        );
        await settle();
        expect(table().card(b.slug)!.faceUp, isTrue);
        expect(fx.flips, [b.slug]);
      },
    );

    test('tirar de la esquina de una carta boca abajo la voltea', () async {
      await openRws();
      c
          .read(tableControllerProvider.notifier)
          .arrange((s) => s.copyWith(spread: () => 'one_card'));
      await holdAndPick(pileAt('p0'), 'deal');
      final card = table().cardInSlot(0)!;
      final hw = TableGeometry.cardW * card.scale / 2,
          hh = TableGeometry.cardH * card.scale / 2;
      final corner = Offset(card.x + hw * .85, card.y + hh * .85);
      await drag(corner, corner.translate(-hw * 1.6, 0));
      expect(table().cardInSlot(0)!.faceUp, isTrue);
      expect(fx.flips, [card.slug]);
    });

    test('Girar invierte el sentido con que se lee', () async {
      await openRws();
      final card = await c.read(tableControllerProvider.notifier).take('p0', 0);
      await holdAndPick(Offset(card.x, card.y), 'turn');
      expect(table().card(card.slug)!.turned, isTrue);
      expect(
        table().placements(),
        isEmpty,
      ); // suelta: no cuenta para la lectura
    });
  });

  group('paño y camara', () {
    test(
      'arrastrar el paño gira la mesa y el doble toque la recentra',
      () async {
        await drag(const Offset(300, 520), const Offset(420, 520));
        expect(dir.camera.tYaw, lessThan(0));
        final id = ++pointer;
        final at = screenOf(const Offset(300, 520));
        dir.pointerDown(id, at, clock);
        dir.pointerUp(id, at, clock += const Duration(milliseconds: 40));
        dir.pointerDown(id, at, clock += const Duration(milliseconds: 120));
        dir.pointerUp(id, at, clock += const Duration(milliseconds: 40));
        expect(dir.camera.tYaw, 0);
      },
    );

    test(
      'el bordado solo se toca con la tirada completa y desvelada',
      () async {
        await openRws();
        expect(
          dir.hitAt(TableDirector.embroideryAt),
          isNot(isA<HitEmbroidery>()),
        );
        c
            .read(tableControllerProvider.notifier)
            .arrange((s) => s.copyWith(spread: () => 'one_card'));
        await holdAndPick(pileAt('p0'), 'deal');
        c
            .read(tableControllerProvider.notifier)
            .arrange(
              (s) => s.updateCard(
                s.cardInSlot(0)!.slug,
                (k) => k.copyWith(faceUp: true),
              ),
            );
        final embroidery = dir.embroideryScreenRect;
        expect(embroidery.height, lessThan(48));
        expect(
          dir.hitAtScreen(embroidery.center.translate(0, 23)),
          isA<HitEmbroidery>(),
        );
        await tap(TableDirector.embroideryAt);
        expect(fx.interpretation, 1);
      },
    );
  });

  group('sello', () {
    test('tocarlo sellado no enseña la pregunta; roto, si', () async {
      await openRws();
      final ops = c.read(tableControllerProvider.notifier);
      ops.arrange((s) => s.copyWith(seal: () => const Seal(text: 'secreto')));
      await tap(TableDirector.sealAt);
      expect(fx.seals.single.open, isFalse);
      ops.arrange(
        (s) => s.copyWith(seal: () => const Seal(text: 'secreto', open: true)),
      );
      await tap(TableDirector.sealAt);
      expect(fx.seals.last.open, isTrue);
    });

    test('sin sello, ese sitio es paño', () async {
      await openRws();
      expect(dir.hitAt(TableDirector.sealAt), isA<HitSurface>());
    });
  });

  group('anclas de los paneles (D7)', () {
    test('el panel de una carta se ancla a lo que ocupa en pantalla', () async {
      await openRws();
      final card = await c.read(tableControllerProvider.notifier).take('p0', 0);
      final rect = dir.screenRectOfCard(table().card(card.slug)!);
      expect(rect.contains(screenOf(Offset(card.x, card.y))), isTrue);
      // ni un punto: tiene el tamaño de la carta, mas o menos segun la camara
      expect(rect.width, greaterThan(TableGeometry.cardW * card.scale * .4));
      expect(rect.height, greaterThan(rect.width));
    });

    test('una carta girada 90 grados ocupa mas ancho que alto', () async {
      await openRws();
      final ops = c.read(tableControllerProvider.notifier);
      final card = await ops.take('p0', 0);
      ops.arrange((s) => s.updateCard(card.slug, (k) => k.copyWith(rot: 90)));
      final rect = dir.screenRectOfCard(table().card(card.slug)!);
      expect(rect.width, greaterThan(rect.height));
    });

    test('lo elegido en un radial se ancla donde se abrio', () async {
      await openRws();
      expect(dir.menuAt, isNull);
      await holdAndPick(pileAt('p0'), 'cut');
      expect(dir.menuAt, screenOf(pileAt('p0')));
    });

    test('el sello se ancla a su sitio en el paño', () {
      expect(
        dir.sealScreenRect.contains(screenOf(TableDirector.sealAt)),
        isTrue,
      );
    });
  });

  group('decisiones del 30-sep', () {
    Future<void> tapCenter() async {
      final layout = dir.radial!;
      dir.pointerDown(++pointer, layout.center, clock);
      await settle();
    }

    test('deshacer un corte lo deshace tambien en el servidor', () async {
      await openRws();
      await holdAndPick(pileAt('p0'), 'cut');
      expect(table().piles, hasLength(2));
      // el centro del radial deshace
      final id = ++pointer;
      dir.pointerDown(id, screenOf(pileAt('p0')), clock);
      clock += const Duration(milliseconds: 450);
      dir.tick(clock, const Duration(milliseconds: 16));
      dir.pointerUp(id, dir.radial!.center, clock);
      await tapCenter();
      expect(server.undos, 1);
      expect(table().piles, hasLength(1));
      expect(fx.toasts.last, 'Deshecho');
    });

    test('unir soltando un monton sobre otro se deshace entero', () async {
      await openRws();
      await holdAndPick(pileAt('p0'), 'cut');
      await drag(pileAt('p1'), pileAt('p0'));
      expect(table().piles, hasLength(1));
      expect(c.read(tableControllerProvider.notifier).canUndo, isTrue);
      expect(await c.read(tableControllerProvider.notifier).undo(), isTrue);
      expect(table().piles, hasLength(2));
    });

    test('cerrar el circulo sin interpretar desde el paño', () async {
      await openRws();
      c
          .read(tableControllerProvider.notifier)
          .arrange((s) => s.copyWith(spread: () => 'one_card'));
      await holdAndPick(pileAt('p0'), 'deal');
      final slug = table().cardInSlot(0)!.slug;
      c
          .read(tableControllerProvider.notifier)
          .arrange((s) => s.updateCard(slug, (k) => k.copyWith(faceUp: true)));
      await holdAndPick(
        const Offset(110, 560),
        'all',
      ); // paño libre, lejos de carta y montón
      expect(dir.radialTitle, 'Recoger todo');
      final layout = dir.radial!;
      dir.pointerDown(
        ++pointer,
        layout.positions[0],
        clock,
      ); // Cerrar el círculo
      await settle();
      expect(server.status, 'closed');
      expect(server.closedArgs!['placements'], [
        {'slug': slug, 'slot': 0},
      ]);
      expect(dir.circleMark.epoch, 1);
      expect(dir.takeExit('card:$slug'), isNotNull);
      expect(
        dir.takeExitDuration('card:$slug'),
        const Duration(milliseconds: 900),
      );
      expect(fx.toasts.last, startsWith('Círculo cerrado'));
    });
  });

  group('errores', () {
    test('un fallo del servidor se dice y la mesa sigue usable', () async {
      await openRws();
      server.failNext = DioException(
        requestOptions: RequestOptions(path: '/x'),
        message: 'sin red',
      );
      await holdAndPick(pileAt('p0'), 'cut');
      expect(fx.errors, hasLength(1));
      expect(dir.busy, isFalse);
      await holdAndPick(pileAt('p0'), 'cut');
      expect(table().piles, hasLength(2));
    });

    test('un 402 abre la tienda en vez de mostrar un error', () async {
      await openRws();
      server.failNext = DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 402,
        ),
      );
      await holdAndPick(pileAt('p0'), 'cut');
      expect(fx.paywall, 1);
      expect(fx.errors, isEmpty);
    });
  });
}
