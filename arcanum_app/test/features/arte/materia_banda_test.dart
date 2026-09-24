// Cuanto sitio se lleva la lamina en la tarjeta del catalogo.
//
// La primera version daba el 64 % a todas y se midio DESPUES: las botanicas
// perdian la mitad de la plancha y los mapas de Bayer entraban enteros. Estos
// numeros existen para que ese error no vuelva en silencio.
import 'dart:convert';
import 'dart:io';

import 'package:arcanum_app/features/arte/materia_plate_loader.dart';
import 'package:arcanum_app/features/arte/materia_plate_reveal.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lo que se ve de una plancha dentro de una franja, con `cover`.
double _visible(int pw, int ph, double ancho, double franja) {
  final escala = ancho / pw;
  final alto = ph * escala;
  if (alto >= franja) return franja / alto;
  final e2 = franja / ph;
  return ancho / (pw * e2);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('la franja se adapta a la forma de la plancha', () {
    test('una botanica vertical se lleva el 78 %', () {
      expect(MateriaPlateBanda.franjaPara(1.79), 0.78);
      expect(MateriaPlateBanda.franjaPara(1.60), 0.78);
    });

    test('una plancha algo vertical, el 72 %', () {
      expect(MateriaPlateBanda.franjaPara(1.30), 0.72);
      expect(MateriaPlateBanda.franjaPara(1.15), 0.72);
    });

    test('una apaisada se queda en el 64 %', () {
      // Los mapas de Bayer rondan 0,77 y ya entraban casi enteros: darles mas
      // sitio solo les quitaria pantalla al texto.
      expect(MateriaPlateBanda.franjaPara(0.77), 0.64);
      expect(MateriaPlateBanda.franjaPara(1.0), 0.64);
    });

    test('sin lamina resuelta, la franja no crece', () {
      expect(MateriaPlateBanda.franjaPara(null), 0.64);
    });
  });

  group('lo que se gana, medido sobre las laminas de verdad', () {
    // Geometria real: 360 dp de ancho, 20+20 de margen, 16 de separacion.
    const ancho = (360 - 40 - 16) / 2;
    const altoCelda = ancho / 0.80;

    late Map<String, dynamic> manifest;
    setUpAll(() {
      manifest =
          json.decode(File('assets/materia/manifest.json').readAsStringSync())
              as Map<String, dynamic>;
    });

    test('ninguna hierba baja del 50 % visible', () {
      final malas = <String, int>{};
      for (final e in manifest.entries) {
        final v = e.value as Map<String, dynamic>;
        if (v['tipo'] != 'herb') continue;
        final px = (v['px'] as List).cast<int>();
        final franja = altoCelda * MateriaPlateBanda.franjaPara(px[1] / px[0]);
        final visible = _visible(px[0], px[1], ancho, franja);
        if (visible < 0.50) malas[e.key] = (visible * 100).round();
      }
      // Con el 64 % fijo habia catorce por debajo del 50 %.
      expect(malas, isEmpty, reason: 'se recortan de mas: $malas');
    });

    test('las apaisadas siguen entrando casi enteras', () {
      // Por FORMA, no por categoria. Virgo es una lamina de Bayer y mide
      // 440x592 -- la constelacion es alta -- asi que se comporta como una
      // botanica y recibe su franja. Una regla escrita por tipo de pieza la
      // habria recortado igual que antes, y este test se escribio dando por
      // hecho que "signo" queria decir "apaisada". No lo quiere decir.
      for (final e in manifest.entries) {
        final v = e.value as Map<String, dynamic>;
        final px = (v['px'] as List).cast<int>();
        final relacion = px[1] / px[0];
        if (relacion >= 1.15) continue;
        final franja = altoCelda * MateriaPlateBanda.franjaPara(relacion);
        expect(
          _visible(px[0], px[1], ancho, franja),
          greaterThan(0.90),
          reason: e.key,
        );
      }
    });

    test('ninguna pieza, sea del tipo que sea, baja del 50 %', () {
      final malas = <String, int>{};
      for (final e in manifest.entries) {
        final px = ((e.value as Map<String, dynamic>)['px'] as List)
            .cast<int>();
        final franja = altoCelda * MateriaPlateBanda.franjaPara(px[1] / px[0]);
        final visible = _visible(px[0], px[1], ancho, franja);
        if (visible < 0.50) malas[e.key] = (visible * 100).round();
      }
      expect(malas, isEmpty, reason: 'se recortan de mas: $malas');
    });
  });

  group('el manifest sabe la forma de cada lamina', () {
    test('toda pieza trae px y una relacion creible', () async {
      await MateriaPlates.instance.ensureLoaded();
      for (final plate in MateriaPlates.instance.all) {
        expect(plate.px, hasLength(2), reason: plate.slug);
        expect(plate.relacion, greaterThan(0.3), reason: plate.slug);
        expect(plate.relacion, lessThan(3.0), reason: plate.slug);
      }
    });
  });
}
