import 'package:arcanum_app/core/monetization/ads_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Las unidades de anuncio estaban cableadas a las de PRUEBA de Google.
///
/// El App ID sí tenía guarda —el build de release se para en seco si falta—
/// pero la unidad no tenía ninguna. Un release firmado y subido a Play habría
/// pedido anuncios a la unidad de demostración: cero ingresos, y tráfico de
/// prueba llegando desde una app publicada, que es lo que hace que AdMob mire
/// una cuenta con lupa.
///
/// Un fallo silencioso justo al lado de uno ruidoso, que es la peor pareja.
void main() {
  group('unidades de AdMob', () {
    test('sin definir la unidad real, se reconoce que es de prueba', () {
      // Los tests corren sin `--dart-define`, así que este es exactamente el
      // caso de quien compila sin pasar su unidad.
      expect(AdUnitIds.esDePrueba, isTrue);
    });

    test('la unidad de prueba es la oficial de Google, no una inventada', () {
      // Si alguien "arregla" esto poniendo un ID cualquiera, los anuncios no
      // cargan en desarrollo y nadie sabe por qué.
      expect(AdUnitIds.rewarded, startsWith('ca-app-pub-3940256099942544/'));
    });

    test('siempre hay una unidad: nunca la cadena vacía', () {
      // Una cadena vacía llegaría al SDK y reventaría dentro de él, con un
      // error que no dice nada de lo que pasó.
      expect(AdUnitIds.rewarded, isNotEmpty);
    });
  });
}
