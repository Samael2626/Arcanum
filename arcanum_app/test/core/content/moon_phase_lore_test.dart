import 'package:arcanum_app/core/content/moon_phase_lore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mismo criterio que `glossary_coverage_test`: un hueco de contenido falla en
/// silencio. Si falta la ficha de una fase, el termino subrayado en dorado no
/// abre nada y nadie se entera hasta que un usuario lo toca.
void main() {
  /// Los ocho slugs de `lunar_calendar._PHASES` del backend, que reparte los
  /// 360 grados de elongacion en tramos de 45. Estan escritos a mano aqui
  /// PORQUE son un contrato con el otro repo: si alla se reparticiona el
  /// ciclo, este test tiene que caer y obligar a mirar.
  const slugsDelBackend = <String>[
    'new',
    'waxing_crescent',
    'first_quarter',
    'waxing_gibbous',
    'full',
    'waning_gibbous',
    'last_quarter',
    'waning_crescent',
  ];

  group('cobertura de las fases lunares', () {
    test('las ocho fases del backend tienen ficha', () {
      for (final slug in slugsDelBackend) {
        expect(
          moonPhaseLore[slug],
          isNotNull,
          reason: 'falta la ficha de la fase "$slug"',
        );
      }
    });

    test('no sobra ninguna ficha que el backend no vaya a pedir', () {
      expect(moonPhaseLore.keys.toSet(), slugsDelBackend.toSet());
    });

    test('ninguna ficha se queda sin practica', () {
      // La practica es lo que convierte la ficha en instrumento. Una
      // descripcion sola es una enciclopedia, y eso ya lo hace el glosario.
      moonPhaseLore.forEach((slug, ficha) {
        expect(ficha.titulo.trim(), isNotEmpty, reason: slug);
        expect(ficha.descripcion.trim(), isNotEmpty, reason: slug);
        expect(ficha.practica.trim(), isNotEmpty, reason: slug);
        expect(ficha.favorece.trim(), isNotEmpty, reason: slug);
      });
    });

    test('la practica de las fases menguantes no manda empezar nada', () {
      // "Creciente atrae y edifica; menguante destierra y disuelve" es la
      // doctrina que ya estaba escrita en el lore de la Luna. Si una ficha
      // menguante acaba diciendo "empieza", se contradice con la app.
      for (final slug in const [
        'waning_gibbous',
        'last_quarter',
        'waning_crescent',
      ]) {
        final practica = moonPhaseLore[slug]!.practica.toLowerCase();
        expect(
          practica.contains('no se empieza') ||
              !practica.contains('empieza '),
          isTrue,
          reason: '"$slug" manda empezar algo en fase menguante',
        );
      }
    });

    test('un slug desconocido devuelve null y no una ficha de relleno', () {
      // Quien pinta el termino tiene que poder decidir NO subrayarlo.
      expect(moonPhaseLoreOf('blue_moon'), isNull);
      expect(moonPhaseLoreOf(null), isNull);
      expect(moonPhaseLoreOf('full'), isNotNull);
    });
  });
}
