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
          practica.contains('no se empieza') || !practica.contains('empieza '),
          isTrue,
          reason: '"$slug" manda empezar algo en fase menguante',
        );
      }
    });

    test('ninguna practica se repite en dos fases', () {
      // ESTE ES EL TEST QUE FALTABA, y su ausencia dio confianza falsa: la
      // primera version de las ocho fichas pasaba todo lo de arriba y aun asi
      // "Luna Nueva" y "Menguante" mandaban las dos ayunar y descansar, y
      // "Cuarto Menguante" y "Menguante" decian las dos "destierro". Dos
      // fichas que mandan lo mismo son una ficha y una de relleno.
      //
      // Se vigilan CONCEPTOS, no palabras sueltas: lo que no puede repetirse
      // es la practica, y la misma practica se escribe de varias maneras.
      const conceptos = <String, String>{
        'ayuno': r'ayun',
        'descanso': r'descans|retiro|dormir',
        'destierro': r'destierr|desterrar',
        'corte': r'\bcorta\b|\bcorte\b|rompe el h',
        'barrido': r'barre|barrido|ba.o de sal',
        'siembra': r'siembra|sembrar',
        'primer paso': r'primer paso',
        'talismanes': r'talisman',
        'adivinacion': r'adivina',
      };

      conceptos.forEach((nombre, patron) {
        final re = RegExp(patron, caseSensitive: false);
        final fases = moonPhaseLore.entries
            .where(
              (e) => re.hasMatch(
                _plano('${e.value.practica} ${e.value.favorece}'),
              ),
            )
            .map((e) => e.key)
            .toList();
        expect(
          fases.length,
          lessThanOrEqualTo(1),
          reason:
              'la practica "$nombre" sale en ${fases.join(", ")}; '
              'si dos fases mandan lo mismo, una de las dos sobra',
        );
      });
    });

    test('un slug desconocido devuelve null y no una ficha de relleno', () {
      // Quien pinta el termino tiene que poder decidir NO subrayarlo.
      expect(moonPhaseLoreOf('blue_moon'), isNull);
      expect(moonPhaseLoreOf(null), isNull);
      expect(moonPhaseLoreOf('full'), isNotNull);
    });
  });
}

/// Minusculas y sin acentos, para que "baño" y "bano" cuenten igual.
String _plano(String s) {
  const conAcento = 'áéíóúüñÁÉÍÓÚÜÑ';
  const sinAcento = 'aeiouunAEIOUUN';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = conAcento.indexOf(c);
    b.write(i < 0 ? c : sinAcento[i]);
  }
  return b.toString();
}
