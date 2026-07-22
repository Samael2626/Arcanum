import 'package:arcanum_app/core/content/transit_reading.dart';
import 'package:arcanum_app/shared/astro_symbols.dart';
import 'package:flutter_test/flutter_test.dart';

/// La lectura de tránsitos es determinista y offline: se compone de piezas
/// fijas, sin IA. Si una pieza falta, la frase sale coja — con paréntesis
/// vacíos o claves en inglés. Estos tests lo impiden.
void main() {
  group('lectura de un tránsito', () {
    test('compone la frase en español llano', () {
      final r = readTransit(transit: 'venus', natal: 'moon', aspect: 'trine');

      expect(
        r.sentence,
        'Hoy Venus (lo que amas y lo que valoras) forma trígono con tu '
        'Luna natal (tu mundo emocional y tus hábitos).',
      );
      expect(r.tone, AspectTone.armonico);
      expect(r.nature, contains('sin esfuerzo'));
      expect(r.guidance, startsWith('Ventana favorable'));
      expect(r.guidance, contains('amor'));
      expect(r.guidance, contains('hogar'));
    });

    test('los aspectos duros piden cautela', () {
      for (final aspect in const ['square', 'opposition']) {
        final r = readTransit(transit: 'saturn', natal: 'sun', aspect: aspect);
        expect(r.tone, AspectTone.tenso, reason: aspect);
        expect(r.guidance, startsWith('Pide cautela'), reason: aspect);
      }
    });

    test('la conjunción intensifica en vez de juzgar', () {
      final r = readTransit(
        transit: 'jupiter',
        natal: 'venus',
        aspect: 'conjunction',
      );
      expect(r.tone, AspectTone.fusion);
      expect(r.guidance, startsWith('Se intensifica'));
    });

    test('nunca deja jerga en inglés ni paréntesis huérfanos', () {
      for (final transit in planetEs.keys) {
        for (final natal in planetEs.keys) {
          for (final aspect in aspectEs.keys) {
            final r = readTransit(
              transit: transit,
              natal: natal,
              aspect: aspect,
            );
            expect(
              r.sentence,
              isNot(contains(transit)),
              reason: 'clave inglesa "$transit" filtrada en la frase',
            );
            expect(
              r.sentence,
              isNot(contains(aspect)),
              reason: 'clave inglesa "$aspect" filtrada en la frase',
            );
            expect(r.sentence, isNot(contains('()')));
            expect(r.sentence, endsWith('.'));
            expect(r.nature.trim(), isNotEmpty);
            expect(r.guidance.trim(), isNotEmpty);
            expect(r.guidance, endsWith('.'));
          }
        }
      }
    });

    test('todo planeta de la carta tiene rol y algo que favorecer', () {
      for (final planet in planetEs.keys) {
        expect(
          planetRole[planet],
          isNotNull,
          reason: 'falta el rol de "$planet": la frase saldría sin paréntesis',
        );
        expect(
          planetFavors[planet],
          isNotNull,
          reason: 'falta qué favorece "$planet": la guía saldría a medias',
        );
      }
    });

    test('un aspecto desconocido degrada sin romper', () {
      final r = readTransit(transit: 'sun', natal: 'moon', aspect: 'quincunx');
      expect(r.tone, AspectTone.fusion);
      expect(r.sentence, contains('quincunx')); // se muestra tal cual
      expect(r.nature.trim(), isNotEmpty);
      expect(r.guidance.trim(), isNotEmpty);
    });
  });

  group('pregunta al oráculo', () {
    test('nombra el tránsito en español, como lo ve el usuario', () {
      final q = transitOracleQuestion(
        transit: 'venus',
        natal: 'moon',
        aspect: 'trine',
      );
      expect(q, contains('Venus en trígono con mi Luna natal'));
    });

    test('nunca filtra claves inglesas a la pregunta', () {
      for (final transit in planetEs.keys) {
        for (final aspect in aspectEs.keys) {
          final q = transitOracleQuestion(
            transit: transit,
            natal: 'sun',
            aspect: aspect,
          );
          expect(q, isNot(contains(transit)), reason: transit);
          expect(q, isNot(contains(aspect)), reason: aspect);
        }
      }
    });

    test('cabe en el límite de 500 caracteres del endpoint', () {
      for (final transit in planetEs.keys) {
        for (final natal in planetEs.keys) {
          for (final aspect in aspectEs.keys) {
            final q = transitOracleQuestion(
              transit: transit,
              natal: natal,
              aspect: aspect,
            );
            expect(
              q.length,
              lessThanOrEqualTo(500),
              reason: '$transit $aspect $natal → ${q.length} caracteres',
            );
            expect(q.trim(), isNotEmpty);
          }
        }
      }
    });
  });

  group('tono de un aspecto', () {
    test('coincide con el de la lectura completa', () {
      for (final aspect in aspectEs.keys) {
        expect(
          aspectToneOf(aspect),
          readTransit(transit: 'sun', natal: 'moon', aspect: aspect).tone,
          reason: aspect,
        );
      }
    });

    test('es insensible a mayúsculas', () {
      expect(aspectToneOf('TRINE'), AspectTone.armonico);
    });
  });
}
