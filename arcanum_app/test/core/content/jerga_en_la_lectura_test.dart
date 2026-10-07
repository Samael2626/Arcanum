// Los terminos con ficha se encuentran dentro de una lectura real.
//
// Los textos de abajo son SALIDAS REALES del modelo del 27-sep-2026, no
// inventadas para el test: es donde aparecieron "el aire de Chokmah" y "la
// obra meticulosa del hod terrestre", que era el problema a resolver.
import 'package:arcanum_app/core/content/jerga_en_la_lectura.dart';
import 'package:flutter_test/flutter_test.dart';

const _lecturaReal =
    'El Señor de la Prudencia en el pasado muestra la obra meticulosa del hod '
    'terrestre, la maestría que has tallado en el trabajo actual. El Señor de '
    'la Paz Restaurada anuncia que, bajo la guía de la Luna en Libra y el aire '
    'de Chokmah, la próxima fase será una tregua interna.';

void main() {
  group('jerga en la lectura', () {
    test('encuentra las sefiras que el modelo escribio', () {
      final t = jergaEnLaLectura(_lecturaReal);
      expect(t.map((x) => x.titulo), containsAll(<String>['Hod', 'Chokmah']));
    });

    test('los indices caen sobre el texto original, con sus acentos', () {
      for (final t in jergaEnLaLectura(_lecturaReal)) {
        expect(
          _lecturaReal.substring(t.inicio, t.fin),
          t.textoVisible,
          reason: 'el indice no cuadra: se subrayaria el trozo equivocado',
        );
      }
    });

    test('van en orden de aparicion y sin solaparse', () {
      final t = jergaEnLaLectura(_lecturaReal);
      for (var i = 1; i < t.length; i++) {
        expect(t[i].inicio, greaterThanOrEqualTo(t[i - 1].fin));
      }
    });

    test('solo palabras enteras: "hod" dentro de "metodo" NO se marca', () {
      // Sin esto, la lectura salia con medio verbo subrayado.
      expect(jergaEnLaLectura('trabajó con método y rigor'), isEmpty);
      expect(jergaEnLaLectura('el hod del oficio'), hasLength(1));
    });

    test(
      'encuentra tambien los terminos del glosario que salen en lecturas',
      () {
        final t = jergaEnLaLectura(
          'la Luna en Libra, primer decanato, y su dignidad',
        );
        expect(
          t.map((x) => x.titulo),
          containsAll(<String>['Decanato', 'Dignidad esencial']),
        );
      },
    );

    test('un texto sin jerga no marca nada', () {
      // El objetivo de fondo: cuando la voz mejore, esto deberia quedarse
      // vacio solo. Si un dia no marca nada, no esta roto.
      expect(
        jergaEnLaLectura(
          'Estás soltando la urgencia de probarte con la seguridad que ya no '
          'te enseña. Enciende una vela blanca al anochecer.',
        ),
        isEmpty,
      );
    });

    test(
      'los terminos mas frecuentes tambien abren, aunque su clave no se llame igual',
      () {
        // El contenido ya estaba escrito y enterrado en otra entrada: "invertida"
        // dentro de `tarot`, las cuatro dignidades dentro de `dignidad`. Lo que
        // faltaba era el alias.
        String? abre(String texto) {
          final t = jergaEnLaLectura(texto);
          return t.isEmpty ? null : t.first.titulo;
        }

        expect(abre('la carta sale invertida'), 'Tirada de tarot');
        expect(abre('tu Venus natal'), isNotNull);
        expect(abre('Venus en exilio'), 'Dignidad esencial');
        expect(abre('Saturno en caída'), 'Dignidad esencial');
        expect(abre('Marte en domicilio'), 'Dignidad esencial');
      },
    );

    test('un termino repetido se subraya SOLO la primera vez', () {
      // "natal" sale 52 veces en las lecturas medidas. Subrayarlas todas deja
      // el texto lleno de oro y deja de senalar nada.
      final t = jergaEnLaLectura(
        'tu Luna natal, tu Venus natal y tu Marte natal se tocan hoy',
      );
      expect(t, hasLength(1));
      expect(t.single.inicio, lessThan(12));
    });

    test('las figuras de la corte abren por sus dos nombres', () {
      // El catalogo mezcla sistemas: slug Rider-Waite ("rey-de-copas") y
      // titulo Golden Dawn ("Prince of the Chariot"). Quien lea "Princesa" en
      // la ficha de la carta tiene que poder tocarla igual que quien lee
      // "Sota".
      String? abre(String t) {
        final r = jergaEnLaLectura(t);
        return r.isEmpty ? null : r.first.titulo;
      }

      expect(abre('el Caballero de Copas entra de golpe'), 'Caballero');
      expect(abre('la Princesa de las Aguas'), 'Sota');
      expect(abre('el Príncipe del Carro de Fuego'), 'Rey');
      expect(abre('la Reina de los Tronos'), 'Reina');
    });

    test('lo que no tiene ficha no se subraya', () {
      // Regla de la casa: un subrayado dorado que no abre nada es peor que no
      // subrayar. "Netzach" si tiene ficha; "Qliphoth" no, y no debe marcarse.
      final t = jergaEnLaLectura('entre Netzach y las Qliphoth');
      expect(t, hasLength(1));
      expect(t.single.titulo, 'Netzach');
    });
  });
}
