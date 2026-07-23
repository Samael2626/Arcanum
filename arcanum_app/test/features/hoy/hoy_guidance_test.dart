import 'package:arcanum_app/features/hoy/hoy_guidance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nextStepFor', () {
    test('la acción rota con la hora para dar variedad', () {
      // La rotación es [materia, grimoire, culpeper, tarot, cielos].
      expect(
        nextStepFor(hourPlanet: 'mercury', hourNumber: 0)!.kind,
        NextStepKind.materia,
      );
      expect(
        nextStepFor(hourPlanet: 'mercury', hourNumber: 1)!.kind,
        NextStepKind.grimoire,
      );
      expect(
        nextStepFor(hourPlanet: 'mercury', hourNumber: 2)!.kind,
        NextStepKind.culpeper,
      );
      expect(
        nextStepFor(hourPlanet: 'mercury', hourNumber: 3)!.kind,
        NextStepKind.tarot,
      );
      expect(
        nextStepFor(hourPlanet: 'mercury', hourNumber: 4)!.kind,
        NextStepKind.cielos,
      );
      // Vuelve a empezar: 5 % 5 == 0.
      expect(
        nextStepFor(hourPlanet: 'mercury', hourNumber: 5)!.kind,
        NextStepKind.materia,
      );
    });

    test('el paso de Culpeper apunta al capítulo real de la hierba', () {
      final step = nextStepFor(hourPlanet: 'sun', hourNumber: 2);
      expect(step!.kind, NextStepKind.culpeper);
      expect(step.slug, 'rosemary');
    });

    test('Culpeper cae a plantas cuando el planeta no tiene capítulo limpio', () {
      // La Luna no tiene hierba lunar coincidente en Culpeper.
      final step = nextStepFor(hourPlanet: 'moon', hourNumber: 2);
      expect(step!.kind, NextStepKind.materia);
      expect(step.planet, 'moon');
    });

    test('el paso de tarot lleva el arcano planetario', () {
      final step = nextStepFor(hourPlanet: 'mars', hourNumber: 3);
      expect(step!.kind, NextStepKind.tarot);
      expect(step.slug, 'la-torre');
    });

    test('un planeta no clásico no produce paso (no rige horas)', () {
      expect(nextStepFor(hourPlanet: 'uranus', hourNumber: 0), isNull);
      expect(nextStepFor(hourPlanet: 'pluto', hourNumber: 1), isNull);
    });

    test('el eyebrow nombra la hora en español', () {
      final step = nextStepFor(hourPlanet: 'venus', hourNumber: 0);
      expect(step!.eyebrow, 'AHORA · Hora de Venus');
    });
  });
}
