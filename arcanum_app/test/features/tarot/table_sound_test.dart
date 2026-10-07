import 'dart:io';
import 'dart:math' as math;

import 'package:arcanum_app/features/tarot/domain/table_models.dart';
import 'package:arcanum_app/features/tarot/domain/table_state.dart';
import 'package:arcanum_app/features/tarot/table/table_sound.dart';
import 'package:arcanum_app/features/tarot/table/table_sound_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _Ear implements SoundPlayer {
  final hits = <SoundHit>[];
  int prepared = 0;

  @override
  Future<void> prepare(Iterable<String> files) async => prepared = files.length;

  @override
  void play(SoundHit hit) => hits.add(hit);

  @override
  Future<void> dispose() async {}

  List<String> get files => [for (final h in hits) h.file];
}

TableCard minor(String suit, int number, {bool reversed = false}) => TableCard(
  face: CardFace(
    slug: '$suit-$number',
    reversed: reversed,
    arcana: 'minor',
    suit: suit,
    number: number,
  ),
  faceUp: true,
  slot: 0,
);

TableCard major(int number, {bool reversed = false}) => TableCard(
  face: CardFace(
    slug: 'major-$number',
    reversed: reversed,
    arcana: 'major',
    number: number,
  ),
  faceUp: true,
  slot: 0,
);

void main() {
  late _Ear ear;
  late Duration now;
  late TableSound sound;

  setUp(() {
    ear = _Ear();
    now = Duration.zero;
    sound = TableSound(player: ear, vary: false, clock: () => now);
  });

  group('cada carta tiene su sonido', () {
    test('la misma carta suena siempre igual', () {
      sound.reveal([minor('copas', 7)]);
      final first = ear.files.toList();
      now += const Duration(seconds: 5);
      sound.reveal([minor('copas', 7)]);
      expect(ear.files.skip(first.length), first);
    });

    test('el palo da el timbre; en ingles o en espanol', () {
      sound.reveal([minor('wands', 1)]);
      sound.reveal([minor('bastos', 1)]);
      sound.reveal([minor('cups', 1)]);
      sound.reveal([minor('swords', 1)]);
      sound.reveal([minor('disks', 1)]);
      sound.reveal([minor('pentacles', 1)]);
      expect(ear.files, [
        'bastos_2', 'bastos_4', 'bastos_2', 'bastos_4', //
        'copas_2', 'copas_4', 'espadas_2', 'espadas_4',
        'oros_2', 'oros_4', 'oros_2', 'oros_4',
      ]);
    });

    test('al derecho sube; invertida baja y suena velada', () {
      sound.reveal([minor('oros', 3)]);
      sound.reveal([minor('oros', 3, reversed: true)]);
      expect(ear.files, ['oros_4', 'oros_6', 'oros_6_v', 'oros_4_v']);
      expect(ear.hits[1].delay, greaterThan(Duration.zero));
    });

    test('girar una carta en la mesa tambien la invierte', () {
      final c = minor('copas', 2);
      sound.reveal([c.copyWith(turned: true)]);
      expect(ear.files.first, endsWith('_v'));
    });

    test('un Mayor suena a cuenco', () {
      sound.reveal([major(13)]);
      sound.reveal([major(0, reversed: true)]);
      expect(ear.files, ['mayor', 'mayor_v']);
    });

    test('desvelar varias las hace sonar una tras otra', () {
      sound.reveal([minor('copas', 1), minor('espadas', 2), major(4)]);
      Duration at(String f) => ear.hits.firstWhere((h) => h.file == f).delay;
      expect(
        [at('copas_2'), at('espadas_3'), at('mayor')],
        [Duration.zero, TableSound.cascade, TableSound.cascade * 2],
      );
    });
  });

  group('lo nuevo no pisa lo que suena', () {
    test('tras un Mayor, lo siguiente entra mas bajo un rato', () {
      sound.snap(0);
      final alone = ear.hits.first.volume;
      now += const Duration(seconds: 5);
      sound.reveal([major(1)]);
      now += const Duration(milliseconds: 800);
      ear.hits.clear();
      sound.snap(0);
      expect(ear.hits.first.volume, closeTo(alone * .55, 1e-9));
      now += const Duration(seconds: 3);
      ear.hits.clear();
      sound.snap(0);
      expect(ear.hits.first.volume, closeTo(alone, 1e-9));
    });

    test('repetir el mismo sonido muy seguido lo va bajando', () {
      sound.slide();
      final v0 = ear.hits.last.volume;
      now += const Duration(milliseconds: 100);
      sound.slide();
      final v1 = ear.hits.last.volume;
      now += const Duration(milliseconds: 100);
      sound.slide();
      expect(v1, closeTo(v0 * .7, 1e-9));
      expect(ear.hits.last.volume, closeTo(v0 * .49, 1e-9));
      now += const Duration(seconds: 1);
      sound.slide();
      expect(ear.hits.last.volume, closeTo(v0, 1e-9));
    });
  });

  group('el acorde es el de la lectura', () {
    test('la tonica y la nota final de cada carta, sin repetir y en orden', () {
      sound.closeCircle([
        minor('copas', 7), // 7 -> grado 4, sube a 6
        minor('oros', 3, reversed: true), // grado 4, baja a 4
        major(2), // al derecho: 5
        minor('espadas', 3), // 3 -> grado 4, sube a 6 (repetida)
      ]);
      expect(ear.files, ['acorde_0', 'acorde_4', 'acorde_5', 'acorde_6']);
      expect(
        [for (final h in ear.hits) h.delay.inMilliseconds],
        [0, 100, 200, 300],
      );
    });

    test('dos lecturas iguales, el mismo acorde', () {
      final cards = [minor('bastos', 9), major(18, reversed: true)];
      sound.closeCircle(cards);
      final first = ear.files.toList();
      ear.hits.clear();
      sound.closeCircle(cards.reversed);
      expect(ear.files, first);
    });

    test('sin cartas desveladas, el acorde de siempre', () {
      sound.closeCircle([]);
      expect(ear.files, [
        'acorde_0',
        'acorde_3',
        'acorde_5',
        'acorde_6',
        'acorde_8',
      ]);
    });
  });

  group('el resto', () {
    test('encajar suena a madera con la nota de su hueco', () {
      sound.snap(3);
      sound.snap(40);
      expect(ear.files, ['encajar', 'campana_3', 'encajar', 'campana_10']);
    });

    test('cada momento tiene su fichero', () {
      sound
        ..shuffle()
        ..cut()
        ..slide()
        ..seal()
        ..breakSeal();
      expect(ear.files, ['barajar', 'cortar', 'sacar', 'sellar', 'romper']);
    });

    test('la variacion queda en tono ±5 % y volumen ±3 dB', () {
      final vary = TableSound(
        player: ear,
        random: math.Random(1),
        clock: () => now,
      );
      final lo = math.pow(10, -3 / 20), hi = math.pow(10, 3 / 20);
      for (var i = 0; i < 200; i++) {
        now += const Duration(seconds: 1);
        vary.seal();
      }
      for (final h in ear.hits) {
        expect(h.speed, inInclusiveRange(.95, 1.05));
        expect(
          h.volume,
          inInclusiveRange(lo * TableSound.level, hi * TableSound.level),
        );
      }
      expect({for (final h in ear.hits) h.speed}.length, greaterThan(100));
    });

    test('todo lo que puede sonar esta en los assets, y nada sobra', () {
      final dir = Directory('assets/sounds/mesa');
      final onDisk = {
        for (final f in dir.listSync().whereType<File>())
          if (f.path.endsWith('.ogg'))
            f.uri.pathSegments.last.replaceAll('.ogg', ''),
      };
      expect(TableSound.files.toSet(), onDisk);
    });

    test('sin motor nativo, la mesa sigue: se reporta y no suena', () async {
      // asi se crea en la pantalla: si el motor no carga (aqui no hay
      // libreria nativa), antes reventaba la mesa entera al construirla
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);
      final player = SoLoudPlayer();
      await player.prepare(['sellar']);
      player.play(const SoundHit('sellar'));
      player.play(const SoundHit('sellar', delay: Duration(milliseconds: 5)));
      await player.dispose();
      expect(reported, hasLength(1));
      expect(reported.single.context.toString(), contains('sonido de la mesa'));
    });

    test('preparar carga todos los ficheros', () async {
      await sound.prepare();
      expect(ear.prepared, TableSound.files.length);
    });
  });
}
