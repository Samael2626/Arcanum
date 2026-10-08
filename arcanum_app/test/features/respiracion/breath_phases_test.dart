// Patrones como datos y su expansion a fases: el giro sin retencion y los
// niveles de llenado continuos, que es lo que hace que el orbe no salte.
import 'package:arcanum_app/features/respiracion/domain/breath_pattern.dart';
import 'package:arcanum_app/features/respiracion/domain/breath_phase.dart';
import 'package:flutter_test/flutter_test.dart';

BreathPattern _p(String id) => breathPatternById(id);

// escapes y no los caracteres: la regla es cero CJK tambien en los tests
const _cjk = r'[\u3040-\u30FF\u3400-\u9FFF\uAC00-\uD7AF\uF900-\uFAFF]';

void main() {
  group('patrones', () {
    test('son los siete del prototipo, en su orden', () {
      expect(breathPatterns.map((p) => p.id), [
        'regardie',
        'gd',
        'rv',
        'pulse',
        'nadi',
        'observe',
        'bardon',
      ]);
    });

    test('cada uno trae nombre, uso y fuente sin caracteres CJK', () {
      for (final p in breathPatterns) {
        expect(p.name, isNotEmpty);
        expect(p.use, isNotEmpty);
        expect(p.source, isNotEmpty);
        for (final s in [p.name, p.use, p.source]) {
          expect(RegExp(_cjk).hasMatch(s), isFalse, reason: p.id);
        }
      }
    });

    test('las fases son las de la fuente', () {
      List<(BreathKind, int)> f(String id) => [
        for (final ph in _p(id).phases) (ph.kind, ph.count),
      ];
      expect(f('regardie'), [(BreathKind.inhale, 4), (BreathKind.exhale, 4)]);
      expect(f('gd'), [
        (BreathKind.empty, 4),
        (BreathKind.inhale, 4),
        (BreathKind.hold, 4),
        (BreathKind.exhale, 4),
      ]);
      expect(f('rv'), [(BreathKind.inhale, 4), (BreathKind.exhale, 8)]);
      expect(f('pulse'), [
        (BreathKind.inhale, 6),
        (BreathKind.hold, 3),
        (BreathKind.exhale, 6),
        (BreathKind.empty, 3),
      ]);
      expect(f('nadi'), [
        (BreathKind.inhale, 4),
        (BreathKind.hold, 16),
        (BreathKind.exhale, 8),
        (BreathKind.inhale, 4),
        (BreathKind.hold, 16),
        (BreathKind.exhale, 8),
      ]);
      expect(_p('nadi').phases.map((x) => x.side), [
        'izquierda',
        null,
        'derecha',
        'derecha',
        null,
        'izquierda',
      ]);
      expect(f('bardon'), [(BreathKind.inhale, 5), (BreathKind.exhale, 5)]);
      expect(f('observe'), isEmpty);
    });

    test('marcas: retencion, divulgacion, avanzada y libre', () {
      expect(breathPatterns.where((p) => p.hasRetention).map((p) => p.id), [
        'gd',
        'pulse',
        'nadi',
      ]);
      expect(_p('pulse').divulgation, isTrue);
      expect(_p('nadi').advanced, isTrue);
      expect(_p('observe').free, isTrue);
      expect(_p('observe').minutes, 2);
      expect(_p('regardie').cycles, 12);
      expect(_p('gd').cycles, 8);
      expect(_p('nadi').cycles, 3);
      expect(_p('bardon').cycles, 7);
    });

    test('la fuente de Bardon avisa de que el 5 y 5 es del motor', () {
      expect(_p('bardon').source, contains('Bardon no fija cuentas'));
      expect(_p('pulse').source, contains('no tradición yóguica'));
    });
  });

  group('buildPhases', () {
    test('con retencion respeta las cuentas y pasa a segundos', () {
      final ph = buildPhases(_p('gd'), retention: true, tempo: 1.5);
      expect(ph.map((x) => x.kind), [
        BreathKind.empty,
        BreathKind.inhale,
        BreathKind.hold,
        BreathKind.exhale,
      ]);
      expect(ph.map((x) => x.seconds), [6, 6, 6, 6]);
      expect(cycleSeconds(ph), 24);
    });

    test('sin retencion cada retener o vacio es un giro de una cuenta', () {
      final ph = buildPhases(_p('gd'), retention: false, tempo: 1);
      expect(ph.map((x) => x.kind), [
        BreathKind.turn,
        BreathKind.inhale,
        BreathKind.turn,
        BreathKind.exhale,
      ]);
      expect(ph.map((x) => x.count), [1, 4, 1, 4]);
      expect(ph[0].from, BreathKind.empty);
      expect(ph[2].from, BreathKind.hold);
      expect(cycleSeconds(ph), 10);
      // el aire nunca se detiene: no queda ninguna fase de retencion
      for (final p in breathPatterns) {
        final out = buildPhases(p, retention: false, tempo: 1);
        expect(out.where((x) => x.kind.isRetention), isEmpty, reason: p.id);
      }
    });

    test('un patron sin retenciones sale igual con o sin el interruptor', () {
      final a = buildPhases(_p('rv'), retention: true, tempo: 1);
      final b = buildPhases(_p('rv'), retention: false, tempo: 1);
      expect(a.map((x) => x.kind), b.map((x) => x.kind));
      expect(cycleSeconds(a), 12);
    });

    test('la fosa de cada fase se conserva', () {
      final ph = buildPhases(_p('nadi'), retention: false, tempo: 1);
      expect(ph.first.side, 'izquierda');
      expect(ph[2].side, 'derecha');
    });

    test('niveles: inhalar llena, exhalar vacia', () {
      final ph = buildPhases(_p('regardie'), retention: false, tempo: 1);
      expect(ph[0].l0, 0);
      expect(ph[0].l1, 1);
      expect(ph[1].l0, 1);
      expect(ph[1].l1, 0);
    });

    test('el giro apenas se mueve hacia la fase siguiente', () {
      final ph = buildPhases(_p('gd'), retention: false, tempo: 1);
      expect(ph[0].l0, 0);
      expect(ph[0].l1, closeTo(0.1, 1e-9));
      expect(ph[2].l0, 1);
      expect(ph[2].l1, closeTo(0.9, 1e-9));
    });

    test('la retencion sostiene el nivel', () {
      final ph = buildPhases(_p('gd'), retention: true, tempo: 1);
      expect([ph[0].l0, ph[0].l1], [0, 0]);
      expect([ph[2].l0, ph[2].l1], [1, 1]);
    });

    test('los niveles son continuos en todos los patrones, ciclo incluido', () {
      for (final p in breathPatterns.where((p) => !p.free)) {
        for (final ret in [true, false]) {
          final ph = buildPhases(p, retention: ret, tempo: 1);
          for (var i = 0; i < ph.length; i++) {
            final next = ph[(i + 1) % ph.length];
            expect(
              ph[i].l1,
              closeTo(next.l0, 1e-9),
              reason: '${p.id} ret=$ret fase $i',
            );
            expect(ph[i].l0, inInclusiveRange(0, 1));
            expect(ph[i].l1, inInclusiveRange(0, 1));
          }
        }
      }
    });

    test('un patron libre no tiene fases', () {
      expect(buildPhases(_p('observe'), retention: false, tempo: 1), isEmpty);
    });
  });

  group('formato', () {
    test('duracion legible', () {
      expect(formatDuration(45), '45 s');
      expect(formatDuration(60), '1 min');
      expect(formatDuration(96), '1 min 36 s');
    });

    test('reloj de cuenta atras redondea hacia arriba', () {
      expect(formatClock(95.2), '1:36');
      expect(formatClock(0), '0:00');
      expect(formatClock(-3), '0:00');
      expect(formatClock(9), '0:09');
    });
  });
}
